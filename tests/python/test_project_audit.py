from __future__ import annotations

import importlib.util
import pathlib
import tempfile
import unittest
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "project_audit", ROOT / "scripts" / "project_audit.py"
)
assert SPEC is not None and SPEC.loader is not None
module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = module
SPEC.loader.exec_module(module)


class CategoryTests(unittest.TestCase):
    def path(self, value: str) -> pathlib.Path:
        return ROOT / value

    def test_root_source(self) -> None:
        self.assertEqual(module.category(self.path("server.mbt")), "moonbit-source")

    def test_white_box_test(self) -> None:
        self.assertEqual(
            module.category(self.path("server_wbtest.mbt")), "moonbit-test"
        )

    def test_command_is_example(self) -> None:
        self.assertEqual(
            module.category(self.path("cmd/server/main.mbt")), "moonbit-example"
        )

    def test_markdown_is_documentation(self) -> None:
        self.assertEqual(
            module.category(self.path("docs/TESTING.md")), "documentation"
        )

    def test_workflow_precedes_generic_yaml(self) -> None:
        self.assertEqual(
            module.category(self.path(".github/workflows/ci.yml")), "ci"
        )

    def test_issue_template_is_community(self) -> None:
        self.assertEqual(
            module.category(self.path(".github/ISSUE_TEMPLATE/bug.yml")),
            "community",
        )

    def test_test_python_is_python_test(self) -> None:
        self.assertEqual(
            module.category(self.path("tests/python/test_tool.py")), "python-test"
        )

    def test_interface_is_generated(self) -> None:
        self.assertEqual(
            module.category(self.path("pkg.generated.mbti")), "generated-interface"
        )


class InspectionTests(unittest.TestCase):
    def temporary(self, relative: str, content: bytes) -> pathlib.Path:
        path = ROOT / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        self.addCleanup(path.unlink, missing_ok=True)
        return path

    def test_text_metrics(self) -> None:
        path = self.temporary(
            "work/audit-test/sample.py",
            b"# heading\n\nvalue = 1\n",
        )
        metric = module.inspect_file(path)
        self.assertEqual(metric.lines, 3)
        self.assertEqual(metric.nonblank, 2)
        self.assertEqual(metric.comment, 1)
        self.assertEqual(metric.category, "python-tool")

    def test_binary_metrics_have_zero_lines(self) -> None:
        path = self.temporary("work/audit-test/blob.bin", b"\xff\xfe\x00")
        metric = module.inspect_file(path)
        self.assertEqual(metric.bytes, 3)
        self.assertEqual(metric.lines, 0)
        self.assertEqual(metric.nonblank, 0)

    def test_comment_counter_by_language(self) -> None:
        self.assertEqual(module.comment_lines(["/// doc", "let x = 1"], ".mbt"), 1)
        self.assertEqual(module.comment_lines(["# doc", "x = 1"], ".py"), 1)


class CheckTests(unittest.TestCase):
    def test_check_passes_at_minimum(self) -> None:
        check = module.Check("tests", 10, 10)
        self.assertTrue(check.passed)

    def test_check_fails_below_minimum(self) -> None:
        check = module.Check("tests", 9, 10)
        self.assertFalse(check.passed)

    def test_unknown_metric_is_configuration_error(self) -> None:
        baseline = {"thresholds": {"missing": 1}}
        with self.assertRaises(module.AuditError):
            module.checks({"known": 1}, baseline)

    def test_markdown_contains_status_and_categories(self) -> None:
        summary = {
            "categories": {
                "moonbit-source": {
                    "files": 1,
                    "lines": 10,
                    "nonblank": 8,
                    "comment": 2,
                }
            }
        }
        rendered = module.markdown(summary, [module.Check("commits", 95, 95)])
        self.assertIn("Engineering Evidence Report", rendered)
        self.assertIn("PASS", rendered)
        self.assertIn("moonbit-source", rendered)


class RepositoryTests(unittest.TestCase):
    def test_tracked_paths_are_inside_repository(self) -> None:
        paths = module.tracked_paths()
        self.assertGreater(len(paths), 60)
        for path in paths:
            path.relative_to(ROOT)

    def test_repository_baseline_loads(self) -> None:
        baseline = module.load_baseline(module.DEFAULT_BASELINE)
        self.assertEqual(baseline["schemaVersion"], 1)
        self.assertIn("moonbitTests", baseline["thresholds"])

    def test_repository_summary_has_expected_dimensions(self) -> None:
        metrics = [module.inspect_file(path) for path in module.tracked_paths()]
        summary = module.aggregate(metrics)
        self.assertGreaterEqual(summary["moonbitTests"], 100)
        self.assertGreaterEqual(summary["conformanceCases"], 15)
        self.assertGreater(summary["documentationNonblankLines"], 1000)


if __name__ == "__main__":
    unittest.main()
