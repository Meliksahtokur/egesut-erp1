#!/usr/bin/env python3
"""EgeSut repository-local harness query and validation CLI.

The implementation deliberately uses only the Python standard library. It
reads Git for factual repository/worktree state and tracked Markdown records
for governance intent. It never repairs records or changes Git state.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


GOAL_STATUSES = {
    "draft", "active", "review", "done", "partial", "blocked", "cancelled", "superseded"
}
ACTIVE_GOAL_STATUSES = {"active", "review", "blocked"}
DOCS_VERDICTS = {None, "PASS", "PARTIAL", "FAIL"}
DECISION_STATUSES = {"proposed", "accepted", "superseded", "rejected"}
SHA_RE = re.compile(r"^[0-9a-f]{7,40}$")
GOAL_ID_RE = re.compile(r"^G-[0-9]{8}-[A-Z0-9][A-Z0-9-]*$")
DECISION_ID_RE = re.compile(r"^D-[0-9]{8}-[A-Z0-9][A-Z0-9-]*$")
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
CANONICAL_TREES = ("goals", "reports", "decisions")
ALLOWED_CACHE_NAMES = {"BOARD.md", "HANDOFF.md", "GOAL-INDEX.md"}


class HarnessError(RuntimeError):
    """A deterministic harness contract failure."""


def finding(code: str, level: str, path: Path | str, message: str) -> dict[str, str]:
    return {"code": code, "level": level, "path": str(path), "message": message}


def run_git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args], cwd=root, check=check, text=True, capture_output=True
    )


def find_repo_root(start: Path | None = None) -> Path:
    cwd = (start or Path.cwd()).resolve()
    result = run_git(cwd, "rev-parse", "--show-toplevel", check=False)
    if result.returncode != 0:
        raise HarnessError(f"not inside a Git repository: {cwd}")
    return Path(result.stdout.strip()).resolve()


def parse_scalar(value: str) -> Any:
    value = value.strip()
    if value in {"null", "~"}:
        return None
    if value == "[]":
        return []
    if value == "{}":
        return {}
    if value.lower() in {"true", "false"}:
        return value.lower() == "true"
    if re.fullmatch(r"-?[0-9]+", value):
        return int(value)
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        if value[0] == '"':
            return json.loads(value)
        return value[1:-1].replace("''", "'")
    return value


def parse_yaml_subset(text: str) -> dict[str, Any]:
    """Parse the mapping/list/scalar subset used by harness frontmatter."""
    tokens: list[tuple[int, str, int]] = []
    for number, raw in enumerate(text.splitlines(), start=1):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        if "\t" in raw[:indent]:
            raise HarnessError(f"tabs are not allowed in frontmatter at line {number}")
        tokens.append((indent, raw.strip(), number))

    def parse_block(index: int, indent: int) -> tuple[Any, int]:
        if index >= len(tokens):
            return {}, index
        is_list = tokens[index][1].startswith("- ")
        container: Any = [] if is_list else {}
        while index < len(tokens):
            current_indent, content, line = tokens[index]
            if current_indent < indent:
                break
            if current_indent > indent:
                raise HarnessError(f"unexpected indentation at frontmatter line {line}")
            if is_list:
                if not content.startswith("- "):
                    raise HarnessError(f"mixed list and mapping at frontmatter line {line}")
                item = content[2:].strip()
                if not item:
                    raise HarnessError(f"empty nested list item at frontmatter line {line}")
                container.append(parse_scalar(item))
                index += 1
                while index < len(tokens) and tokens[index][0] > indent:
                    _, continuation, _ = tokens[index]
                    if not isinstance(container[-1], str) or continuation.startswith("- "):
                        raise HarnessError(
                            f"unsupported nested list value at frontmatter line {tokens[index][2]}"
                        )
                    container[-1] = f"{container[-1]} {continuation}"
                    index += 1
                continue
            if content.startswith("- ") or ":" not in content:
                raise HarnessError(f"invalid mapping entry at frontmatter line {line}")
            key, raw_value = content.split(":", 1)
            key = key.strip()
            if not key or key in container:
                raise HarnessError(f"empty or duplicate key at frontmatter line {line}: {key}")
            raw_value = raw_value.strip()
            index += 1
            if raw_value:
                container[key] = parse_scalar(raw_value)
            elif index < len(tokens) and tokens[index][0] > indent:
                child_indent = tokens[index][0]
                container[key], index = parse_block(index, child_indent)
            else:
                container[key] = {}
        return container, index

    if not tokens:
        return {}
    if tokens[0][0] != 0 or tokens[0][1].startswith("- "):
        raise HarnessError("frontmatter root must be a mapping")
    result, end = parse_block(0, 0)
    if end != len(tokens) or not isinstance(result, dict):
        raise HarnessError("frontmatter parse did not consume a root mapping")
    return result


def read_markdown_record(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise HarnessError(f"missing YAML frontmatter: {path}")
    try:
        end = next(index for index, line in enumerate(lines[1:], start=1) if line.strip() == "---")
    except StopIteration as exc:
        raise HarnessError(f"unterminated YAML frontmatter: {path}") from exc
    return {"path": path, "meta": parse_yaml_subset("\n".join(lines[1:end])), "body": "\n".join(lines[end + 1 :])}


def markdown_records(root: Path, tree: str, prefix: str) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    records: list[dict[str, Any]] = []
    findings: list[dict[str, str]] = []
    directory = root / ".harness" / tree
    if not directory.exists():
        return records, findings
    for path in sorted(directory.rglob(f"{prefix}-*.md")):
        try:
            records.append(read_markdown_record(path))
        except (OSError, HarnessError) as exc:
            findings.append(finding("INVALID_FRONTMATTER", "ERROR", path, str(exc)))
    return records, findings


def load_goal_records(root: Path) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    return markdown_records(root, "goals", "G")


def load_decision_records(root: Path) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    return markdown_records(root, "decisions", "D")


def validate_unique_ids(records: Iterable[dict[str, Any]], kind: str) -> list[dict[str, str]]:
    seen: dict[str, str] = {}
    findings: list[dict[str, str]] = []
    for record in records:
        record_id = str(record.get("meta", {}).get("id", ""))
        path = str(record.get("path", ""))
        if record_id in seen:
            findings.append(
                finding(
                    f"DUPLICATE_{kind.upper()}_ID", "ERROR", path,
                    f"{record_id} is already declared by {seen[record_id]}",
                )
            )
        else:
            seen[record_id] = path
    return findings


def _require_list(meta: dict[str, Any], key: str, path: Path) -> list[dict[str, str]]:
    if not isinstance(meta.get(key), list):
        return [finding(f"INVALID_{key.upper()}", "ERROR", path, f"{key} must be a list")]
    return []


def valid_repository_path(value: Any) -> bool:
    if not isinstance(value, str) or not value or "\x00" in value:
        return False
    path = PurePosixPath(value)
    return not path.is_absolute() and ".." not in path.parts and path != PurePosixPath(".")


def validate_goal_meta(meta: dict[str, Any], path: Path) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []
    required = {
        "id", "status", "owner", "flow", "created", "base_sha", "launch_sha", "branch",
        "worktree", "write_manifest", "docs_authority", "acceptance", "stop_conditions",
        "report", "checkpoint",
    }
    for key in sorted(required - set(meta)):
        findings.append(finding("MISSING_GOAL_FIELD", "ERROR", path, f"missing field: {key}"))
    goal_id = meta.get("id")
    if not isinstance(goal_id, str) or not GOAL_ID_RE.fullmatch(goal_id):
        findings.append(finding("INVALID_GOAL_ID", "ERROR", path, f"invalid goal id: {goal_id}"))
    if meta.get("status") not in GOAL_STATUSES:
        findings.append(finding("INVALID_GOAL_STATUS", "ERROR", path, f"invalid status: {meta.get('status')}"))
    if not isinstance(meta.get("created"), str) or not DATE_RE.fullmatch(meta["created"]):
        findings.append(finding("INVALID_CREATED_DATE", "ERROR", path, "created must be YYYY-MM-DD"))
    for key in ("base_sha", "launch_sha"):
        value = meta.get(key)
        if value is not None and (not isinstance(value, str) or not SHA_RE.fullmatch(value)):
            findings.append(finding(f"INVALID_{key.upper()}", "ERROR", path, f"invalid {key}: {value}"))
    manifest = meta.get("write_manifest")
    if not isinstance(manifest, list):
        findings.append(finding("INVALID_WRITE_MANIFEST", "ERROR", path, "write_manifest must be a list"))
    elif not manifest:
        findings.append(finding("EMPTY_WRITE_MANIFEST", "ERROR", path, "Full goals require an exact write manifest"))
    elif len(manifest) != len(set(manifest)):
        findings.append(finding("DUPLICATE_MANIFEST_PATH", "ERROR", path, "write_manifest contains duplicates"))
    if isinstance(manifest, list):
        invalid_paths = [str(item) for item in manifest if not valid_repository_path(item)]
        if invalid_paths:
            findings.append(
                finding(
                    "INVALID_MANIFEST_PATH",
                    "ERROR",
                    path,
                    "manifest paths must be normalized repository-relative paths: "
                    + ", ".join(invalid_paths),
                )
            )
    for key in ("acceptance", "stop_conditions"):
        findings.extend(_require_list(meta, key, path))
    authority = meta.get("docs_authority")
    if not isinstance(authority, dict):
        findings.append(finding("INVALID_DOCS_AUTHORITY", "ERROR", path, "docs_authority must be a mapping"))
    else:
        if authority.get("db") not in {"none", "read", "write"}:
            findings.append(finding("INVALID_DB_AUTHORITY", "ERROR", path, "db authority must be none, read, or write"))
        for surface in ("tracked_paths", "local_paths"):
            value = authority.get(surface)
            if not isinstance(value, dict) or not isinstance(value.get("write"), list) or not isinstance(value.get("append"), list):
                findings.append(finding("INVALID_DOCS_AUTHORITY", "ERROR", path, f"invalid {surface} authority"))
        tracked = authority.get("tracked_paths")
        if isinstance(tracked, dict) and isinstance(manifest, list):
            declared = [
                item
                for mode in ("write", "append")
                for item in tracked.get(mode, [])
                if isinstance(item, str)
            ]
            outside = sorted(set(declared) - set(manifest))
            if outside:
                findings.append(
                    finding(
                        "DOCS_AUTHORITY_OUTSIDE_MANIFEST",
                        "ERROR",
                        path,
                        "tracked docs authority escapes write_manifest: " + ", ".join(outside),
                    )
                )
    checkpoint = meta.get("checkpoint")
    if not isinstance(checkpoint, dict):
        findings.append(finding("INVALID_CHECKPOINT", "ERROR", path, "checkpoint must be a mapping"))
    else:
        if not isinstance(checkpoint.get("sequence"), int) or checkpoint.get("sequence", -1) < 0:
            findings.append(finding("INVALID_CHECKPOINT_SEQUENCE", "ERROR", path, "checkpoint sequence must be non-negative"))
        head = checkpoint.get("head")
        if head is not None and (not isinstance(head, str) or not SHA_RE.fullmatch(head)):
            findings.append(finding("INVALID_CHECKPOINT_HEAD", "ERROR", path, f"invalid checkpoint head: {head}"))
        if checkpoint.get("docs_verdict") not in DOCS_VERDICTS:
            findings.append(finding("INVALID_DOCS_VERDICT", "ERROR", path, f"invalid docs verdict: {checkpoint.get('docs_verdict')}"))
    return findings


def parse_report_header(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    patterns = {
        "goal": r"^Goal:\s+`([^`]+)`\s*$",
        "date": r"^Date:\s+([0-9]{4}-[0-9]{2}-[0-9]{2})\s*$",
        "flow": r"^Flow:\s+`([^`]+)`\s*$",
        "root_verdict": r"^Root verdict:\s+`([^`]+)`\s*$",
    }
    result: dict[str, str] = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, text, flags=re.MULTILINE)
        if not match:
            raise HarnessError(f"missing report header field {key}: {path}")
        result[key] = match.group(1)
    return result


def validate_report_link(root: Path, goal: dict[str, Any], goal_path: Path) -> dict[str, str] | None:
    report = goal.get("report")
    report_parts = PurePosixPath(report).parts if isinstance(report, str) else ()
    if (
        not valid_repository_path(report)
        or len(report_parts) < 3
        or report_parts[:2] != (".harness", "reports")
    ):
        return finding("INVALID_REPORT_LINK", "ERROR", goal_path, "report must be a repository-relative path")
    report_path = root / report
    if not report_path.is_file():
        return finding("MISSING_REPORT", "ERROR", goal_path, f"linked report is missing: {report}")
    try:
        header = parse_report_header(report_path)
    except (OSError, HarnessError) as exc:
        return finding("INVALID_REPORT_HEADER", "ERROR", report_path, str(exc))
    if header["goal"] != goal.get("id"):
        return finding("REPORT_GOAL_MISMATCH", "ERROR", report_path, f"report names {header['goal']} instead of {goal.get('id')}")
    if header["root_verdict"] not in {"IN_PROGRESS", "PASS", "PARTIAL", "FAIL", "INCONCLUSIVE"}:
        return finding("INVALID_REPORT_VERDICT", "ERROR", report_path, f"invalid report verdict: {header['root_verdict']}")
    return None


def validate_decision_record(record: dict[str, Any]) -> list[dict[str, str]]:
    meta, path, body = record["meta"], Path(record["path"]), record["body"]
    findings: list[dict[str, str]] = []
    if not isinstance(meta.get("id"), str) or not DECISION_ID_RE.fullmatch(meta["id"]):
        findings.append(finding("INVALID_DECISION_ID", "ERROR", path, f"invalid decision id: {meta.get('id')}"))
    if not isinstance(meta.get("date"), str) or not DATE_RE.fullmatch(meta["date"]):
        findings.append(finding("INVALID_DECISION_DATE", "ERROR", path, "date must be YYYY-MM-DD"))
    if meta.get("status") not in DECISION_STATUSES:
        findings.append(finding("INVALID_DECISION_STATUS", "ERROR", path, f"invalid decision status: {meta.get('status')}"))
    if meta.get("status") == "superseded" and not DECISION_ID_RE.fullmatch(str(meta.get("superseded_by") or "")):
        findings.append(
            finding(
                "MISSING_SUPERSEDING_DECISION",
                "ERROR",
                path,
                "superseded decisions require a valid superseded_by decision id",
            )
        )
    head = meta.get("head")
    if head is not None and (not isinstance(head, str) or not SHA_RE.fullmatch(head)):
        findings.append(finding("INVALID_DECISION_HEAD", "ERROR", path, f"invalid decision head: {head}"))
    for heading, code in (
        ("## Context", "MISSING_CONTEXT_SECTION"),
        ("## Decision", "MISSING_DECISION_SECTION"),
        ("## Consequences", "MISSING_CONSEQUENCES_SECTION"),
    ):
        if not re.search(rf"^{re.escape(heading)}\s*$", body, flags=re.MULTILINE):
            findings.append(finding(code, "ERROR", path, f"missing section: {heading}"))
    return findings


def validate_transition(old: str, new: str, actor_role: str) -> None:
    transitions = {
        "draft": {"active", "cancelled"},
        "active": {"review", "partial", "blocked", "cancelled"},
        "review": {"done", "partial", "blocked", "cancelled", "superseded"},
        "blocked": {"active", "review", "partial", "cancelled"},
        "done": {"superseded"},
        "partial": {"active", "superseded"},
        "cancelled": set(),
        "superseded": set(),
    }
    if old not in transitions or new not in transitions[old]:
        raise HarnessError(f"illegal goal transition: {old} -> {new}")
    if new == "done" and actor_role != "root":
        raise HarnessError("only root acceptance may transition a goal to done")


def authorize_goal_edit(actor_role: str, actor_goal_id: str, target_goal_id: str) -> None:
    if actor_role == "root":
        return
    if actor_role == "lead" and actor_goal_id == target_goal_id:
        return
    raise HarnessError(
        f"{actor_role} for {actor_goal_id} cannot edit goal {target_goal_id}"
    )


def validate_repository(root: Path) -> dict[str, Any]:
    root = root.resolve()
    goals, findings = load_goal_records(root)
    decisions, decision_load_findings = load_decision_records(root)
    findings.extend(decision_load_findings)
    findings.extend(validate_unique_ids(goals, "goal"))
    findings.extend(validate_unique_ids(decisions, "decision"))
    goal_ids = {record.get("meta", {}).get("id") for record in goals}
    for record in goals:
        meta, path = record["meta"], Path(record["path"])
        findings.extend(validate_goal_meta(meta, path))
        linked = validate_report_link(root, meta, path)
        if linked:
            findings.append(linked)
        parent = meta.get("parent")
        if parent is not None and parent not in goal_ids:
            findings.append(finding("MISSING_PARENT_GOAL", "ERROR", path, f"unknown parent goal: {parent}"))
    for record in decisions:
        findings.extend(validate_decision_record(record))
    findings.extend(validate_worktree_contract(root, goals))
    findings.sort(key=lambda item: (item["level"], item["code"], item["path"]))
    return {
        "ok": not any(item["level"] == "ERROR" for item in findings),
        "goal_count": len(goals),
        "decision_count": len(decisions),
        "findings": findings,
    }


def minimal_goal_for_test() -> dict[str, Any]:
    return {
        "id": "G-20990101-TEST",
        "status": "active",
        "owner": "root",
        "parent": None,
        "flow": "inline",
        "created": "2099-01-01",
        "base_sha": "0123456789abcdef0123456789abcdef01234567",
        "launch_sha": "0123456789abcdef0123456789abcdef01234567",
        "branch": "idle/test",
        "worktree": "/tmp/test-worktree",
        "write_manifest": ["example.txt"],
        "docs_authority": {
            "tracked_paths": {"write": ["example.txt"], "append": []},
            "local_paths": {"write": [], "append": []},
            "db": "none",
            "propose_only": [],
        },
        "pattern_refs": [],
        "acceptance": ["test"],
        "stop_conditions": ["stop"],
        "report": ".harness/reports/2099/G-20990101-TEST.md",
        "checkpoint": {"sequence": 0, "kind": None, "head": None, "docs_verdict": None},
    }


def git_worktrees(root: Path) -> list[dict[str, Any]]:
    output = run_git(root, "worktree", "list", "--porcelain").stdout
    worktrees: list[dict[str, Any]] = []
    for block in output.strip().split("\n\n") if output.strip() else []:
        item: dict[str, Any] = {"exists": True, "branch": None, "detached": False}
        for line in block.splitlines():
            key, _, value = line.partition(" ")
            if key == "worktree":
                item["path"] = value
            elif key == "HEAD":
                item["head"] = value
            elif key == "branch":
                item["branch"] = value.removeprefix("refs/heads/")
            elif key == "detached":
                item["detached"] = True
        worktrees.append(item)
    return worktrees


def worktree_inventory(root: Path, goals: list[dict[str, Any]]) -> dict[str, Any]:
    facts = git_worktrees(root)
    by_path = {item["path"]: item for item in facts}
    for item in facts:
        item["goal_ids"] = sorted(
            str(record["meta"].get("id"))
            for record in goals
            if record["meta"].get("worktree") == item["path"]
        )
    recorded_missing: list[dict[str, str]] = []
    for record in goals:
        meta = record["meta"]
        path = meta.get("worktree")
        if meta.get("status") in ACTIVE_GOAL_STATUSES and isinstance(path, str) and path not in by_path:
            recorded_missing.append({"goal_id": str(meta.get("id")), "path": path})
    return {"worktrees": facts, "recorded_missing": sorted(recorded_missing, key=lambda item: item["goal_id"])}


def validate_worktree_contract(root: Path, goals: list[dict[str, Any]]) -> list[dict[str, str]]:
    inventory = worktree_inventory(root, goals)
    findings: list[dict[str, str]] = []
    for item in inventory["recorded_missing"]:
        findings.append(
            finding(
                "RECORDED_WORKTREE_MISSING",
                "ERROR",
                item["path"],
                f"active goal {item['goal_id']} records a worktree Git does not report",
            )
        )
    facts = {item["path"]: item for item in inventory["worktrees"]}
    for record in goals:
        meta = record["meta"]
        if meta.get("status") not in ACTIVE_GOAL_STATUSES:
            continue
        fact = facts.get(meta.get("worktree"))
        if fact and meta.get("branch") and fact.get("branch") != meta.get("branch"):
            findings.append(
                finding(
                    "WORKTREE_BRANCH_MISMATCH",
                    "ERROR",
                    record["path"],
                    f"goal records {meta.get('branch')} but Git reports {fact.get('branch')}",
                )
            )
    return findings


def stale_goals(root: Path, goals: list[dict[str, Any]]) -> list[dict[str, Any]]:
    facts = {item["path"]: item for item in git_worktrees(root)}
    stale: list[dict[str, Any]] = []
    for record in goals:
        meta = record["meta"]
        if meta.get("status") not in ACTIVE_GOAL_STATUSES:
            continue
        reasons: list[str] = []
        path = meta.get("worktree")
        fact = facts.get(path) if isinstance(path, str) else None
        if isinstance(path, str) and fact is None:
            reasons.append("recorded_worktree_missing")
        if fact is not None:
            branch = meta.get("branch")
            if branch and fact.get("branch") != branch:
                reasons.append("worktree_branch_mismatch")
            checkpoint = meta.get("checkpoint") or {}
            checkpoint_head = checkpoint.get("head")
            if checkpoint_head and fact.get("head") != checkpoint_head:
                reasons.append("checkpoint_behind_worktree")
        if reasons:
            stale.append({"goal_id": meta.get("id"), "reasons": reasons})
    return sorted(stale, key=lambda item: str(item["goal_id"]))


def git_history(root: Path, limit: int = 200) -> list[dict[str, Any]]:
    hashes = run_git(root, "rev-list", "--date-order", f"--max-count={limit}", "HEAD").stdout.splitlines()
    entries: list[dict[str, Any]] = []
    for commit in hashes:
        fields = run_git(root, "show", "-s", "--format=%H%x1f%aI%x1f%an%x1f%s%x1f%b", commit).stdout.rstrip("\n").split("\x1f", 4)
        if len(fields) != 5:
            continue
        sha, date, author, subject, body = fields
        parent_row = run_git(root, "rev-list", "--parents", "-n", "1", commit).stdout.split()
        if len(parent_row) > 1:
            path_output = run_git(root, "diff", "--name-only", parent_row[1], commit).stdout
        else:
            path_output = run_git(
                root, "diff-tree", "--root", "--no-commit-id", "--name-only", "-r", commit
            ).stdout
        paths = sorted(filter(None, path_output.splitlines()))
        trailers: dict[str, str] = {}
        for line in body.splitlines():
            match = re.fullmatch(r"(Harness-Goal|Harness-Flow|Harness-Mode):\s*(\S+)", line.strip())
            if match:
                trailers[match.group(1)] = match.group(2)
        entries.append(
            {
                "sha": sha,
                "date": date,
                "author": author,
                "subject": subject,
                "paths": paths,
                "goal": trailers.get("Harness-Goal"),
                "flow": trailers.get("Harness-Flow"),
                "mode": trailers.get("Harness-Mode"),
            }
        )
    return entries


def search_records(root: Path, query: str) -> list[dict[str, Any]]:
    needle = query.casefold()
    matches: list[dict[str, Any]] = []
    for tree in CANONICAL_TREES:
        directory = root / ".harness" / tree
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.md")):
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                if needle in line.casefold():
                    matches.append({"path": str(path.relative_to(root)), "line": number, "text": line.strip()})
    return matches


def render_board(goals: list[dict[str, Any]]) -> str:
    lines = ["# Generated Goal Board", "", "| Goal | Status | Owner | Flow |", "|---|---|---|---|"]
    for record in sorted(goals, key=lambda item: str(item["meta"].get("id"))):
        meta = record["meta"]
        lines.append(f"| {meta.get('id')} | {meta.get('status')} | {meta.get('owner')} | {meta.get('flow')} |")
    return "\n".join(lines) + "\n"


def render_handoff(goals: list[dict[str, Any]]) -> str:
    lines = ["# Generated Active Handoff", ""]
    active = [record for record in goals if record["meta"].get("status") in ACTIVE_GOAL_STATUSES]
    if not active:
        return "\n".join(lines + ["No active goals.", ""])
    for record in sorted(active, key=lambda item: str(item["meta"].get("id"))):
        meta = record["meta"]
        checkpoint = meta.get("checkpoint") or {}
        lines.extend(
            [
                f"## {meta.get('id')}",
                "",
                f"- status: {meta.get('status')}",
                f"- worktree: {meta.get('worktree')}",
                f"- checkpoint: {checkpoint.get('sequence')} / {checkpoint.get('kind')}",
                f"- report: {meta.get('report')}",
                "",
            ]
        )
    return "\n".join(lines)


def render_goal_index(goals: list[dict[str, Any]]) -> str:
    payload = [
        {
            "id": record["meta"].get("id"),
            "status": record["meta"].get("status"),
            "parent": record["meta"].get("parent"),
            "branch": record["meta"].get("branch"),
            "report": record["meta"].get("report"),
        }
        for record in sorted(goals, key=lambda item: str(item["meta"].get("id")))
    ]
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def write_cache(root: Path, name: str, content: str) -> Path:
    if name not in ALLOWED_CACHE_NAMES:
        raise HarnessError(f"unsupported generated cache name: {name}")
    path = root / ".harness" / "cache" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def lineage(goals: list[dict[str, Any]], goal_id: str) -> dict[str, Any]:
    by_id = {record["meta"].get("id"): record["meta"] for record in goals}
    if goal_id not in by_id:
        raise HarnessError(f"unknown goal: {goal_id}")
    ancestors: list[str] = []
    seen = {goal_id}
    parent = by_id[goal_id].get("parent")
    while parent:
        if parent in seen:
            raise HarnessError(f"goal lineage cycle at {parent}")
        seen.add(parent)
        ancestors.append(parent)
        if parent not in by_id:
            break
        parent = by_id[parent].get("parent")
    children = sorted(str(item_id) for item_id, meta in by_id.items() if meta.get("parent") == goal_id)
    return {"goal_id": goal_id, "ancestors": ancestors, "children": children}


def print_payload(payload: Any, as_json: bool) -> None:
    if as_json:
        print(json.dumps(payload, ensure_ascii=False, indent=2, default=str))
    elif isinstance(payload, str):
        print(payload, end="" if payload.endswith("\n") else "\n")
    elif isinstance(payload, list):
        for item in payload:
            if not isinstance(item, dict):
                print(item)
            elif "id" in item:
                print("\t".join(str(item.get(key, "")) for key in ("id", "status", "owner", "flow")))
            elif "sha" in item:
                print(f"{item['sha'][:12]}\t{item['date']}\t{item['author']}\t{item['subject']}")
            elif "path" in item and "line" in item:
                print(f"{item['path']}:{item['line']}\t{item['text']}")
            else:
                print(json.dumps(item, ensure_ascii=False, default=str))
    else:
        print(json.dumps(payload, ensure_ascii=False, indent=2, default=str))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="EgeSut unified harness")
    parser.add_argument("--root", type=Path, help="repository root; defaults to Git discovery")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "goals", "worktrees", "stale"):
        command = sub.add_parser(name)
        command.add_argument("--json", action="store_true")
    show = sub.add_parser("show")
    show.add_argument("goal_id")
    show.add_argument("--json", action="store_true")
    search = sub.add_parser("search")
    search.add_argument("query")
    search.add_argument("--json", action="store_true")
    history = sub.add_parser("history")
    history.add_argument("--limit", type=int, default=200)
    history.add_argument("--owner")
    history.add_argument("--flow")
    history.add_argument("--goal")
    history.add_argument("--json", action="store_true")
    tree = sub.add_parser("lineage")
    tree.add_argument("goal_id")
    tree.add_argument("--json", action="store_true")
    render = sub.add_parser("render")
    render.add_argument("view", choices=("board", "handoff", "goal-index"))
    render.add_argument("--cache", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = find_repo_root(args.root)
    goals, load_findings = load_goal_records(root)
    command = args.command
    if command == "validate":
        payload = validate_repository(root)
        print_payload(payload, args.json)
        return 0 if payload["ok"] else 1
    if load_findings:
        print_payload({"ok": False, "findings": load_findings}, True)
        return 1
    if command == "goals":
        payload = [record["meta"] for record in goals]
        print_payload(payload, args.json)
    elif command == "show":
        record = next((item for item in goals if item["meta"].get("id") == args.goal_id), None)
        if record is None:
            raise HarnessError(f"unknown goal: {args.goal_id}")
        print_payload(record["meta"], args.json)
    elif command == "search":
        print_payload(search_records(root, args.query), args.json)
    elif command == "history":
        entries = git_history(root, max(1, args.limit))
        if args.owner:
            entries = [item for item in entries if item["author"] == args.owner]
        if args.flow:
            entries = [item for item in entries if item["flow"] == args.flow]
        if args.goal:
            entries = [item for item in entries if item["goal"] == args.goal]
        print_payload(entries, args.json)
    elif command == "worktrees":
        print_payload(worktree_inventory(root, goals), args.json)
    elif command == "stale":
        print_payload(stale_goals(root, goals), args.json)
    elif command == "lineage":
        print_payload(lineage(goals, args.goal_id), args.json)
    elif command == "render":
        renderers = {"board": render_board, "handoff": render_handoff, "goal-index": render_goal_index}
        names = {"board": "BOARD.md", "handoff": "HANDOFF.md", "goal-index": "GOAL-INDEX.md"}
        content = renderers[args.view](goals)
        if args.cache:
            print(write_cache(root, names[args.view], content))
        else:
            print(content, end="")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except HarnessError as exc:
        print(f"harness: {exc}", file=sys.stderr)
        raise SystemExit(2)
