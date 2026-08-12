#!/usr/bin/env python3
"""Black-box conformance runner for newline-delimited MCP servers.

The runner deliberately uses only the Python standard library.  It validates the
fixture corpus before execution, starts a server command, writes one compact JSON
message per line, and verifies response structure by recursive subset matching.
Notification cases are checked with a short quiet-period rather than consuming a
later response.

Examples:
    python3 scripts/mcp_conformance.py validate
    python3 scripts/mcp_conformance.py list
    python3 scripts/mcp_conformance.py run -- moon run cmd/mcp-echo --target native
    python3 scripts/mcp_conformance.py run --report conformance.json -- ./mcp-server
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import pathlib
import queue
import subprocess
import sys
import threading
import time
from collections.abc import Iterable, Mapping, Sequence
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_SUITE = ROOT / "tests" / "conformance" / "server_cases.json"
JSON = Any


class SuiteError(ValueError):
    """The conformance suite itself is malformed."""


class MatchError(AssertionError):
    """A server response did not satisfy the expected JSON subset."""


@dataclasses.dataclass(frozen=True)
class Case:
    """One request/notification and its expected observable outcome."""

    case_id: str
    request: Mapping[str, JSON]
    expected: Mapping[str, JSON] | None
    no_response: bool
    ignored_arrays: frozenset[str]


@dataclasses.dataclass
class CaseResult:
    """Serializable result for one executed case."""

    case_id: str
    passed: bool
    duration_ms: float
    request: Mapping[str, JSON]
    response: JSON | None = None
    error: str | None = None

    def as_json(self) -> dict[str, JSON]:
        return dataclasses.asdict(self)


def _require_object(value: JSON, where: str) -> Mapping[str, JSON]:
    if not isinstance(value, dict):
        raise SuiteError(f"{where} must be a JSON object")
    return value


def _validate_message(message: Mapping[str, JSON], where: str) -> None:
    if message.get("jsonrpc") != "2.0":
        raise SuiteError(f"{where}.jsonrpc must equal '2.0'")
    if "method" in message:
        if not isinstance(message["method"], str) or not message["method"]:
            raise SuiteError(f"{where}.method must be a non-empty string")
        if "id" in message and not isinstance(message["id"], (str, int)):
            raise SuiteError(f"{where}.id must be a string or integer")
        params = message.get("params")
        if params is not None and not isinstance(params, (dict, list)):
            raise SuiteError(f"{where}.params must be an object or array")
    else:
        if "id" not in message:
            raise SuiteError(f"{where} response must contain id")
        has_result = "result" in message
        has_error = "error" in message
        if has_result == has_error:
            raise SuiteError(f"{where} response must contain exactly one result/error")


def load_suite(path: pathlib.Path) -> tuple[Mapping[str, JSON], list[Case]]:
    """Load, structurally validate, and normalize a conformance suite."""

    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise SuiteError(f"cannot read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SuiteError(f"invalid JSON in {path}: {exc}") from exc
    root = _require_object(document, "suite")
    if root.get("schemaVersion") != 1:
        raise SuiteError("suite.schemaVersion must equal 1")
    raw_cases = root.get("cases")
    if not isinstance(raw_cases, list) or not raw_cases:
        raise SuiteError("suite.cases must be a non-empty array")
    seen: set[str] = set()
    cases: list[Case] = []
    for index, value in enumerate(raw_cases):
        where = f"suite.cases[{index}]"
        raw = _require_object(value, where)
        case_id = raw.get("id")
        if not isinstance(case_id, str) or not case_id:
            raise SuiteError(f"{where}.id must be a non-empty string")
        if case_id in seen:
            raise SuiteError(f"duplicate case id: {case_id}")
        seen.add(case_id)
        request = _require_object(raw.get("input"), f"{where}.input")
        _validate_message(request, f"{where}.input")
        no_response = raw.get("noResponse", False)
        if not isinstance(no_response, bool):
            raise SuiteError(f"{where}.noResponse must be boolean")
        expected_value = raw.get("expect")
        expected = None if expected_value is None else _require_object(
            expected_value, f"{where}.expect"
        )
        if no_response == (expected is not None):
            raise SuiteError(f"{where} needs exactly one of expect/noResponse")
        if expected is not None:
            _validate_message(expected, f"{where}.expect")
        ignored = raw.get("ignoreArrayContentsAt", [])
        if not isinstance(ignored, list) or not all(isinstance(x, str) for x in ignored):
            raise SuiteError(f"{where}.ignoreArrayContentsAt must be string array")
        cases.append(
            Case(case_id, request, expected, no_response, frozenset(ignored))
        )
    return root, cases


def _path(parent: str, key: object) -> str:
    return f"{parent}.{key}" if parent else str(key)


def assert_subset(
    expected: JSON,
    actual: JSON,
    *,
    ignored_arrays: frozenset[str] = frozenset(),
    path: str = "",
) -> None:
    """Assert that every expected JSON member occurs in the actual value.

    Objects are recursive subsets. Arrays normally require at least the expected
    prefix; paths listed in ``ignored_arrays`` only require the actual value to
    be an array. Scalars use type-sensitive equality so ``True`` does not match
    ``1`` as it would with Python's normal equality.
    """

    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            raise MatchError(f"{path or '$'}: expected object, got {type(actual).__name__}")
        for key, value in expected.items():
            child = _path(path, key)
            if key not in actual:
                raise MatchError(f"{child}: missing member")
            assert_subset(value, actual[key], ignored_arrays=ignored_arrays, path=child)
        return
    if isinstance(expected, list):
        if not isinstance(actual, list):
            raise MatchError(f"{path or '$'}: expected array, got {type(actual).__name__}")
        if path in ignored_arrays:
            return
        if len(actual) < len(expected):
            raise MatchError(f"{path or '$'}: expected at least {len(expected)} items")
        for index, value in enumerate(expected):
            assert_subset(
                value,
                actual[index],
                ignored_arrays=ignored_arrays,
                path=_path(path, index),
            )
        return
    if type(expected) is not type(actual) or expected != actual:
        raise MatchError(f"{path or '$'}: expected {expected!r}, got {actual!r}")


class LineProcess:
    """A subprocess with background readers for newline protocol and stderr."""

    def __init__(self, command: Sequence[str]) -> None:
        self.command = list(command)
        self.process: subprocess.Popen[str] | None = None
        self.stdout: queue.Queue[str] = queue.Queue()
        self.stderr: list[str] = []
        self._threads: list[threading.Thread] = []

    def __enter__(self) -> "LineProcess":
        self.process = subprocess.Popen(
            self.command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            bufsize=1,
            cwd=ROOT,
        )
        assert self.process.stdout is not None
        assert self.process.stderr is not None
        self._threads = [
            threading.Thread(target=self._read_stdout, daemon=True),
            threading.Thread(target=self._read_stderr, daemon=True),
        ]
        for thread in self._threads:
            thread.start()
        return self

    def _read_stdout(self) -> None:
        assert self.process is not None and self.process.stdout is not None
        for line in self.process.stdout:
            self.stdout.put(line.rstrip("\r\n"))

    def _read_stderr(self) -> None:
        assert self.process is not None and self.process.stderr is not None
        for line in self.process.stderr:
            self.stderr.append(line.rstrip("\r\n"))

    def send(self, message: Mapping[str, JSON]) -> None:
        assert self.process is not None and self.process.stdin is not None
        if self.process.poll() is not None:
            raise RuntimeError(f"server exited with code {self.process.returncode}")
        self.process.stdin.write(json.dumps(message, ensure_ascii=False, separators=(",", ":")))
        self.process.stdin.write("\n")
        self.process.stdin.flush()

    def receive(self, timeout: float) -> JSON:
        try:
            line = self.stdout.get(timeout=timeout)
        except queue.Empty as exc:
            stderr = "\n".join(self.stderr[-10:])
            raise TimeoutError(f"no response within {timeout:.2f}s; stderr:\n{stderr}") from exc
        try:
            return json.loads(line)
        except json.JSONDecodeError as exc:
            raise MatchError(f"server emitted non-JSON stdout line: {line!r}") from exc

    def quiet(self, timeout: float) -> bool:
        try:
            line = self.stdout.get(timeout=timeout)
        except queue.Empty:
            return True
        self.stdout.put(line)
        return False

    def __exit__(self, exc_type: object, exc: object, traceback: object) -> None:
        assert self.process is not None
        if self.process.stdin:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=1.0)
        except subprocess.TimeoutExpired:
            self.process.terminate()
            try:
                self.process.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()


def run_cases(
    cases: Iterable[Case], command: Sequence[str], timeout: float, quiet: float
) -> list[CaseResult]:
    """Run each case in an isolated server process.

    Isolation makes failures reproducible and also supports runtimes that flush
    stdout only when stdin reaches EOF (notably some native MoonBit builds).
    Stateful lifecycle coverage lives in ``tests/fixtures/session.ndjson`` and
    the MoonBit loopback tests; this corpus intentionally tests one exchange at
    a time.
    """

    del quiet  # retained as a stable CLI option for future persistent mode
    results: list[CaseResult] = []
    for case in cases:
        started = time.perf_counter()
        response: JSON | None = None
        error: str | None = None
        wire = json.dumps(case.request, ensure_ascii=False, separators=(",", ":")) + "\n"
        try:
            completed = subprocess.run(
                command,
                input=wire,
                capture_output=True,
                text=True,
                encoding="utf-8",
                cwd=ROOT,
                timeout=timeout,
                check=False,
            )
            if completed.returncode != 0:
                raise RuntimeError(
                    f"server exited {completed.returncode}: {completed.stderr[-1000:]}"
                )
            lines = [line for line in completed.stdout.splitlines() if line.strip()]
            if case.no_response:
                if lines:
                    raise MatchError(f"notification produced stdout: {lines!r}")
            else:
                if len(lines) != 1:
                    raise MatchError(f"expected one response line, got {len(lines)}")
                try:
                    response = json.loads(lines[0])
                except json.JSONDecodeError as exc:
                    raise MatchError(f"server emitted invalid JSON: {lines[0]!r}") from exc
                assert case.expected is not None
                assert_subset(
                    case.expected,
                    response,
                    ignored_arrays=case.ignored_arrays,
                )
        except (MatchError, RuntimeError, subprocess.TimeoutExpired) as exc:
            error = str(exc)
        results.append(
            CaseResult(
                case.case_id,
                error is None,
                (time.perf_counter() - started) * 1000,
                case.request,
                response,
                error,
            )
        )
    return results


def write_report(
    path: pathlib.Path,
    suite: Mapping[str, JSON],
    command: Sequence[str],
    results: Sequence[CaseResult],
) -> None:
    passed = sum(result.passed for result in results)
    report = {
        "schemaVersion": 1,
        "suiteProtocolVersion": suite.get("protocolVersion"),
        "command": list(command),
        "summary": {"total": len(results), "passed": passed, "failed": len(results) - passed},
        "results": [result.as_json() for result in results],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", type=pathlib.Path, default=DEFAULT_SUITE)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("validate", help="validate fixture schema without starting a server")
    sub.add_parser("list", help="list normalized case identifiers")
    run = sub.add_parser("run", help="execute cases against a server command")
    run.add_argument("--timeout", type=float, default=3.0)
    run.add_argument("--quiet-period", type=float, default=0.15)
    run.add_argument("--report", type=pathlib.Path)
    run.add_argument("command", nargs=argparse.REMAINDER)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        suite, cases = load_suite(args.suite)
    except SuiteError as exc:
        print(f"suite error: {exc}", file=sys.stderr)
        return 2
    if args.action == "validate":
        print(f"validated {len(cases)} cases from {args.suite}")
        return 0
    if args.action == "list":
        for case in cases:
            outcome = "notification" if case.no_response else "response"
            print(f"{case.case_id}\t{case.request['method']}\t{outcome}")
        return 0
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("run requires a server command after --", file=sys.stderr)
        return 2
    results = run_cases(cases, command, args.timeout, args.quiet_period)
    for result in results:
        mark = "PASS" if result.passed else "FAIL"
        suffix = "" if result.error is None else f" — {result.error}"
        print(f"[{mark}] {result.case_id} ({result.duration_ms:.1f} ms){suffix}")
    if args.report:
        write_report(args.report, suite, command, results)
        print(f"report: {args.report}")
    passed = sum(result.passed for result in results)
    print(f"summary: {passed}/{len(results)} passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
