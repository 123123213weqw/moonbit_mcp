#!/usr/bin/env python3
"""Measure and enforce repository engineering evidence.

Unlike generic line counters this script works from ``git ls-files`` so build
artifacts, editor caches, and ignored secrets can never inflate the report.  It
separates production MoonBit, MoonBit tests, executable examples, verification
Python, documentation, fixtures, and automation.  Thresholds are declared in a
reviewable JSON file rather than embedded in CI.
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import pathlib
import re
import subprocess
import sys
from collections import Counter, defaultdict
from collections.abc import Iterable, Mapping, Sequence
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = ROOT / "engineering_baseline.json"


class AuditError(RuntimeError):
    """Repository state cannot be measured reliably."""


@dataclasses.dataclass(frozen=True)
class FileMetric:
    path: str
    category: str
    extension: str
    bytes: int
    lines: int
    nonblank: int
    comment: int

    def as_json(self) -> dict[str, Any]:
        return dataclasses.asdict(self)


@dataclasses.dataclass(frozen=True)
class Check:
    name: str
    actual: int
    minimum: int

    @property
    def passed(self) -> bool:
        return self.actual >= self.minimum

    def as_json(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "actual": self.actual,
            "minimum": self.minimum,
            "passed": self.passed,
        }


def git(*args: str) -> str:
    completed = subprocess.run(
        ["git", *args], cwd=ROOT, text=True, capture_output=True, check=False
    )
    if completed.returncode != 0:
        raise AuditError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout


def tracked_paths() -> list[pathlib.Path]:
    raw = git("ls-files", "-z")
    paths = [ROOT / value for value in raw.split("\0") if value]
    missing = [path for path in paths if not path.is_file()]
    if missing:
        joined = ", ".join(str(path.relative_to(ROOT)) for path in missing[:5])
        raise AuditError(f"tracked files missing from worktree: {joined}")
    return paths


def category(path: pathlib.Path) -> str:
    relative = path.relative_to(ROOT)
    value = relative.as_posix()
    suffix = path.suffix.lower()
    if suffix == ".mbt":
        if "_wbtest" in path.name or value.startswith("tests/"):
            return "moonbit-test"
        if value.startswith("cmd/") or value.startswith("examples/"):
            return "moonbit-example"
        return "moonbit-source"
    if suffix == ".py":
        return "python-test" if value.startswith("tests/") else "python-tool"
    if suffix in {".md", ".mdx"}:
        return "documentation"
    if value.startswith(".github/workflows/"):
        return "ci"
    if value.startswith(".github/"):
        return "community"
    if value.startswith("tests/") or suffix in {".json", ".ndjson", ".hex"}:
        return "fixture"
    if suffix in {".sh", ".bash"}:
        return "automation"
    if suffix == ".mbti":
        return "generated-interface"
    return "project"


def comment_lines(lines: Sequence[str], suffix: str) -> int:
    prefixes = ("///", "//") if suffix in {".mbt", ".js", ".ts"} else ("#",)
    if suffix in {".md", ".mdx"}:
        return sum(line.lstrip().startswith("<!--") for line in lines)
    return sum(line.lstrip().startswith(prefixes) for line in lines)


def inspect_file(path: pathlib.Path) -> FileMetric:
    data = path.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return FileMetric(
            path.relative_to(ROOT).as_posix(), category(path), path.suffix, len(data), 0, 0, 0
        )
    lines = text.splitlines()
    suffix = path.suffix.lower()
    return FileMetric(
        path.relative_to(ROOT).as_posix(),
        category(path),
        suffix or path.name,
        len(data),
        len(lines),
        sum(bool(line.strip()) for line in lines),
        comment_lines(lines, suffix),
    )


def count_moonbit_tests(files: Iterable[FileMetric]) -> int:
    pattern = re.compile(r'^\s*test\s+"', re.MULTILINE)
    total = 0
    for metric in files:
        if metric.category != "moonbit-test":
            continue
        total += len(pattern.findall((ROOT / metric.path).read_text(encoding="utf-8")))
    return total


def count_conformance_cases() -> int:
    path = ROOT / "tests" / "conformance" / "server_cases.json"
    if not path.exists():
        return 0
    document = json.loads(path.read_text(encoding="utf-8"))
    cases = document.get("cases", [])
    return len(cases) if isinstance(cases, list) else 0


def aggregate(files: Sequence[FileMetric]) -> dict[str, Any]:
    by_category: dict[str, Counter[str]] = defaultdict(Counter)
    by_extension: dict[str, Counter[str]] = defaultdict(Counter)
    for metric in files:
        values = {
            "files": 1,
            "bytes": metric.bytes,
            "lines": metric.lines,
            "nonblank": metric.nonblank,
            "comment": metric.comment,
        }
        by_category[metric.category].update(values)
        by_extension[metric.extension].update(values)
    commits = int(git("rev-list", "--count", "HEAD").strip())
    contributors = len([line for line in git("shortlog", "-sne", "HEAD").splitlines() if line])
    documentation = by_category.get("documentation", Counter())
    moonbit_categories = ["moonbit-source", "moonbit-test", "moonbit-example"]
    moonbit_nonblank = sum(by_category.get(name, Counter())["nonblank"] for name in moonbit_categories)
    python_nonblank = sum(
        by_category.get(name, Counter())["nonblank"] for name in ["python-tool", "python-test"]
    )
    return {
        "commits": commits,
        "contributors": contributors,
        "trackedFiles": len(files),
        "moonbitNonblankLines": moonbit_nonblank,
        "pythonNonblankLines": python_nonblank,
        "documentationFiles": documentation["files"],
        "documentationNonblankLines": documentation["nonblank"],
        "moonbitTests": count_moonbit_tests(files),
        "conformanceCases": count_conformance_cases(),
        "categories": {name: dict(values) for name, values in sorted(by_category.items())},
        "extensions": {name: dict(values) for name, values in sorted(by_extension.items())},
    }


def load_baseline(path: pathlib.Path) -> Mapping[str, Any]:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditError(f"cannot load baseline {path}: {exc}") from exc
    if document.get("schemaVersion") != 1:
        raise AuditError("baseline.schemaVersion must equal 1")
    thresholds = document.get("thresholds")
    if not isinstance(thresholds, dict):
        raise AuditError("baseline.thresholds must be an object")
    for name, value in thresholds.items():
        if not isinstance(name, str) or not isinstance(value, int) or value < 0:
            raise AuditError("baseline thresholds must be non-negative integers")
    return document


def checks(summary: Mapping[str, Any], baseline: Mapping[str, Any]) -> list[Check]:
    result: list[Check] = []
    for name, minimum in baseline["thresholds"].items():
        actual = summary.get(name)
        if not isinstance(actual, int):
            raise AuditError(f"baseline references unknown integer metric: {name}")
        result.append(Check(name, actual, minimum))
    return result


def markdown(summary: Mapping[str, Any], results: Sequence[Check]) -> str:
    lines = [
        "# Engineering Evidence Report",
        "",
        "Generated from tracked files and the current Git history.",
        "",
        "## Baseline checks",
        "",
        "| Metric | Actual | Minimum | Status |",
        "|---|---:|---:|:---:|",
    ]
    for check in results:
        status = "PASS" if check.passed else "FAIL"
        lines.append(f"| `{check.name}` | {check.actual} | {check.minimum} | {status} |")
    lines.extend(
        [
            "",
            "## Tracked-file categories",
            "",
            "| Category | Files | Lines | Nonblank | Comments |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    for name, values in summary["categories"].items():
        lines.append(
            f"| `{name}` | {values['files']} | {values['lines']} | "
            f"{values['nonblank']} | {values['comment']} |"
        )
    lines.append("")
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=pathlib.Path, default=DEFAULT_BASELINE)
    parser.add_argument("--check", action="store_true", help="fail if any floor is unmet")
    parser.add_argument("--format", choices=["text", "json", "markdown"], default="text")
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--files", action="store_true", help="include per-file data in JSON")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        file_metrics = [inspect_file(path) for path in tracked_paths()]
        summary = aggregate(file_metrics)
        baseline = load_baseline(args.baseline)
        results = checks(summary, baseline)
    except (AuditError, json.JSONDecodeError) as exc:
        print(f"audit error: {exc}", file=sys.stderr)
        return 2
    if args.format == "json":
        payload: dict[str, Any] = {
            "schemaVersion": 1,
            "summary": summary,
            "checks": [result.as_json() for result in results],
        }
        if args.files:
            payload["files"] = [metric.as_json() for metric in file_metrics]
        rendered = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    elif args.format == "markdown":
        rendered = markdown(summary, results)
    else:
        rows = []
        for result in results:
            mark = "PASS" if result.passed else "FAIL"
            rows.append(f"[{mark}] {result.name}: {result.actual} >= {result.minimum}")
        rendered = "\n".join(rows) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 1 if args.check and not all(result.passed for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
