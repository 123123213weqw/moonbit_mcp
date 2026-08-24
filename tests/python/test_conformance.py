from __future__ import annotations

import importlib.util
import json
import pathlib
import tempfile
import unittest
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "mcp_conformance", ROOT / "scripts" / "mcp_conformance.py"
)
assert SPEC is not None and SPEC.loader is not None
module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = module
SPEC.loader.exec_module(module)


class SubsetTests(unittest.TestCase):
    def test_equal_scalars(self) -> None:
        module.assert_subset("x", "x")
        module.assert_subset(7, 7)
        module.assert_subset(True, True)
        module.assert_subset(None, None)

    def test_scalar_types_are_not_coerced(self) -> None:
        with self.assertRaises(module.MatchError):
            module.assert_subset(True, 1)
        with self.assertRaises(module.MatchError):
            module.assert_subset(1, 1.0)

    def test_object_is_recursive_subset(self) -> None:
        module.assert_subset(
            {"result": {"protocolVersion": "2025-06-18"}},
            {
                "jsonrpc": "2.0",
                "id": 1,
                "result": {
                    "protocolVersion": "2025-06-18",
                    "serverInfo": {"name": "server"},
                },
            },
        )

    def test_missing_object_member_reports_path(self) -> None:
        with self.assertRaisesRegex(module.MatchError, r"result\.tools"):
            module.assert_subset(
                {"result": {"tools": []}},
                {"result": {}},
            )

    def test_array_compares_expected_prefix(self) -> None:
        module.assert_subset([{"name": "one"}], [{"name": "one"}, {"name": "two"}])

    def test_short_array_fails(self) -> None:
        with self.assertRaises(module.MatchError):
            module.assert_subset([1, 2], [1])

    def test_ignored_array_checks_only_type(self) -> None:
        module.assert_subset(
            {"result": {"tools": [{"name": "expected"}]}},
            {"result": {"tools": []}},
            ignored_arrays=frozenset({"result.tools"}),
        )

    def test_ignored_array_still_requires_array(self) -> None:
        with self.assertRaises(module.MatchError):
            module.assert_subset(
                {"result": {"tools": []}},
                {"result": {"tools": {}}},
                ignored_arrays=frozenset({"result.tools"}),
            )


class SuiteTests(unittest.TestCase):
    def write_suite(self, document: object) -> pathlib.Path:
        temporary = tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", encoding="utf-8", delete=False
        )
        with temporary:
            json.dump(document, temporary)
        self.addCleanup(pathlib.Path(temporary.name).unlink, missing_ok=True)
        return pathlib.Path(temporary.name)

    def minimal_case(self) -> dict[str, object]:
        return {
            "id": "ping",
            "input": {"jsonrpc": "2.0", "id": 1, "method": "ping"},
            "expect": {"jsonrpc": "2.0", "id": 1, "result": {}},
        }

    def test_repository_suite_is_valid(self) -> None:
        metadata, cases = module.load_suite(module.DEFAULT_SUITE)
        self.assertEqual(metadata["schemaVersion"], 1)
        self.assertGreaterEqual(len(cases), 15)
        self.assertEqual(len({case.case_id for case in cases}), len(cases))

    def test_minimal_suite_loads(self) -> None:
        path = self.write_suite({"schemaVersion": 1, "cases": [self.minimal_case()]})
        _, cases = module.load_suite(path)
        self.assertEqual(cases[0].case_id, "ping")
        self.assertFalse(cases[0].no_response)

    def test_notification_suite_loads(self) -> None:
        case = {
            "id": "initialized",
            "input": {"jsonrpc": "2.0", "method": "notifications/initialized"},
            "noResponse": True,
        }
        path = self.write_suite({"schemaVersion": 1, "cases": [case]})
        _, cases = module.load_suite(path)
        self.assertTrue(cases[0].no_response)
        self.assertIsNone(cases[0].expected)

    def test_rejects_wrong_schema_version(self) -> None:
        path = self.write_suite({"schemaVersion": 2, "cases": [self.minimal_case()]})
        with self.assertRaises(module.SuiteError):
            module.load_suite(path)

    def test_rejects_duplicate_case_ids(self) -> None:
        case = self.minimal_case()
        path = self.write_suite({"schemaVersion": 1, "cases": [case, case]})
        with self.assertRaisesRegex(module.SuiteError, "duplicate"):
            module.load_suite(path)

    def test_rejects_case_without_outcome(self) -> None:
        case = self.minimal_case()
        del case["expect"]
        path = self.write_suite({"schemaVersion": 1, "cases": [case]})
        with self.assertRaises(module.SuiteError):
            module.load_suite(path)

    def test_rejects_case_with_two_outcomes(self) -> None:
        case = self.minimal_case()
        case["noResponse"] = True
        path = self.write_suite({"schemaVersion": 1, "cases": [case]})
        with self.assertRaises(module.SuiteError):
            module.load_suite(path)

    def test_rejects_null_request_id(self) -> None:
        case = self.minimal_case()
        case["input"]["id"] = None  # type: ignore[index]
        path = self.write_suite({"schemaVersion": 1, "cases": [case]})
        with self.assertRaises(module.SuiteError):
            module.load_suite(path)

    def test_rejects_scalar_params(self) -> None:
        case = self.minimal_case()
        case["input"]["params"] = True  # type: ignore[index]
        path = self.write_suite({"schemaVersion": 1, "cases": [case]})
        with self.assertRaises(module.SuiteError):
            module.load_suite(path)

    def test_rejects_response_with_both_outcomes(self) -> None:
        case = self.minimal_case()
        case["expect"]["error"] = {"code": -1}  # type: ignore[index]
        path = self.write_suite({"schemaVersion": 1, "cases": [case]})
        with self.assertRaises(module.SuiteError):
            module.load_suite(path)


class ReportTests(unittest.TestCase):
    def test_report_summary_and_results(self) -> None:
        result = module.CaseResult(
            "ping",
            True,
            1.25,
            {"jsonrpc": "2.0", "id": 1, "method": "ping"},
            {"jsonrpc": "2.0", "id": 1, "result": {}},
            None,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "nested" / "report.json"
            module.write_report(
                path,
                {"protocolVersion": "2025-06-18"},
                ["server"],
                [result],
            )
            document = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(document["summary"], {"total": 1, "passed": 1, "failed": 0})
        self.assertEqual(document["results"][0]["case_id"], "ping")


if __name__ == "__main__":
    unittest.main()
