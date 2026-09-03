#!/usr/bin/env python3
"""EgeSut repository-local harness query and validation CLI.

The implementation deliberately uses only the Python standard library. It
reads Git for factual repository/worktree state and tracked Markdown records
for governance intent. It never repairs records or changes Git state.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
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
ALLOWED_CACHE_NAMES = {"BOARD.md", "HANDOFF.md", "GOAL-INDEX.md", "MEMORY-INDEX.md"}
CHECKPOINT_KINDS = {"pre-commit", "pre-review", "handoff", "post-merge", "final"}
GOAL_CHECKPOINT_KINDS = {
    None, *CHECKPOINT_KINDS, "final(publishing=false)", "final(publishing=true)"
}
DOC_SURFACE_OUTCOMES = {
    "UPDATED", "NO_CHANGE_REQUIRED", "PROPOSED", "OUT_OF_SCOPE"
}
DOCS_RECEIPT_NAME = "DOCS-RECEIPT.json"
PATTERN_ID_RE = re.compile(r"^[A-Z][A-Z0-9]*(-[A-Z0-9]+)*-[0-9]{2}$")


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


def current_changed_paths(root: Path, scope: str = "all") -> list[str]:
    if scope not in {"all", "staged"}:
        raise HarnessError(f"unsupported diff scope: {scope}")
    if scope == "staged":
        raw = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "-z"],
            cwd=root,
            check=True,
            capture_output=True,
        ).stdout
        return sorted({item.decode("utf-8", "surrogateescape") for item in raw.split(b"\0") if item})

    raw = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=root,
        check=True,
        capture_output=True,
    ).stdout
    tokens = [item for item in raw.split(b"\0") if item]
    paths: set[str] = set()
    index = 0
    while index < len(tokens):
        record = tokens[index]
        if len(record) < 4:
            index += 1
            continue
        status = record[:2].decode("ascii", "replace")
        paths.add(record[3:].decode("utf-8", "surrogateescape"))
        if status[0] in {"R", "C"} or status[1] in {"R", "C"}:
            index += 1
            if index < len(tokens):
                paths.add(tokens[index].decode("utf-8", "surrogateescape"))
        index += 1
    return sorted(paths)


def repository_state(
    root: Path,
    paths: Iterable[str],
    *,
    scope: str = "all",
    local_paths: Iterable[str] = (),
) -> dict[str, Any]:
    root = root.resolve()
    head = run_git(root, "rev-parse", "HEAD").stdout.strip()
    digest = hashlib.sha256()
    normalized_paths = sorted(set(str(item) for item in paths))
    normalized_local = sorted(set(str(item) for item in local_paths))
    digest.update(f"head\0{head}\0scope\0{scope}\0".encode())

    for value in normalized_paths:
        digest.update(f"repo\0{value}\0".encode("utf-8", "surrogateescape"))
        if not valid_repository_path(value):
            digest.update(b"INVALID\0")
            continue
        if scope == "staged":
            staged = subprocess.run(
                ["git", "show", f":{value}"], cwd=root, check=False, capture_output=True
            )
            mode = run_git(root, "ls-files", "-s", "--", value, check=False).stdout
            digest.update(mode.encode("utf-8", "surrogateescape"))
            digest.update(staged.stdout if staged.returncode == 0 else b"DELETED\0")
            continue
        path = root / value
        if path.exists() or path.is_symlink():
            digest.update(f"MODE\0{path.lstat().st_mode:o}\0".encode())
        if path.is_symlink():
            digest.update(b"SYMLINK\0" + str(path.readlink()).encode("utf-8", "surrogateescape"))
        elif path.is_file():
            digest.update(b"FILE\0" + path.read_bytes())
        elif path.is_dir():
            digest.update(b"DIRECTORY\0")
        else:
            digest.update(b"MISSING\0")

    for value in normalized_local:
        digest.update(f"local\0{value}\0".encode("utf-8", "surrogateescape"))
        path = Path(value) if Path(value).is_absolute() else root / value
        if path.exists() or path.is_symlink():
            digest.update(f"MODE\0{path.lstat().st_mode:o}\0".encode())
        if path.is_symlink():
            digest.update(b"SYMLINK\0" + str(path.readlink()).encode("utf-8", "surrogateescape"))
        elif path.is_file():
            digest.update(b"FILE\0" + path.read_bytes())
        elif path.is_dir():
            digest.update(b"DIRECTORY\0")
        else:
            digest.update(b"MISSING\0")
    return {
        "head": head,
        "diff_hash": digest.hexdigest(),
        "paths": normalized_paths,
        "local_paths": normalized_local,
        "scope": scope,
    }


def required_docs_surfaces(
    checkpoint: str,
    changed_paths: Iterable[str],
    *,
    goal: dict[str, Any] | None = None,
    publishing: bool = False,
) -> set[str]:
    if checkpoint not in CHECKPOINT_KINDS:
        raise HarnessError(f"unsupported docs checkpoint: {checkpoint}")
    base = {
        "pre-commit": {"tests"},
        "pre-review": {"manifest", "acceptance", "docs_authority"},
        "handoff": {"blockers_risks", "next_action"},
        "post-merge": {"memory"},
        "final": {"memory"},
    }[checkpoint]
    required = set(base)
    if goal is not None and checkpoint in {"pre-commit", "pre-review", "handoff", "post-merge", "final"}:
        required.add("goal_report")
    if checkpoint == "final" and publishing:
        required.add("remote_range")

    for raw_path in changed_paths:
        path = str(raw_path).replace("\\", "/")
        if path == "index.html" or path in {
            "js/ui.js", "js/forms.js", "js/app.js", "js/state.js", "js/config.js",
        }:
            required.update({"ui_map", "ui_patterns", "tests"})
        if path.startswith("supabase/functions/"):
            required.update({"domain_rules", "deploy_boundary", "tests"})
        if path == "js/api.js" or path.startswith("supabase/migrations/"):
            required.update(
                {"live_schema", "rpc_reference", "domain_rules", "deploy_boundary", "tests"}
            )
        if "domain-rules" in path or path.startswith(".harness/decisions/"):
            required.update({"domain_rules", "decisions"})
        if path.startswith(".harness/") or path.startswith("tests/harness/"):
            required.update({"harness_contract", "harness_tests"})
        if path.startswith(".harness/goals/") or path.startswith(".harness/reports/"):
            required.update({"goal_report", "generated_views"})
        if path.startswith("tests/") and "fixture" in path.casefold():
            required.update({"testing_patterns", "producer_provenance"})
    return required


def _path_allowed(path: str, declarations: Iterable[str]) -> bool:
    normalized = path.replace("\\", "/")
    for declaration in declarations:
        pattern = str(declaration).replace("\\", "/")
        if normalized == pattern or fnmatch.fnmatchcase(normalized, pattern):
            return True
        if pattern.endswith("/**") and normalized.startswith(pattern[:-3].rstrip("/") + "/"):
            return True
    return False


def is_documentation_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if normalized in {"AGENTS.md", "CLAUDE.md"} or normalized.startswith("docs/"):
        return True
    if normalized.endswith((".md", ".mdx")):
        return True
    if normalized.startswith((".claude/", ".agents/", ".zcode/", ".qwen/", ".openclaude/")):
        return normalized.endswith((".md", ".json", ".yaml", ".yml"))
    if normalized.startswith(".harness/") and not normalized.startswith(".harness/bin/"):
        return normalized.endswith((".md", ".json", ".yaml", ".yml"))
    return False


def _aggregate_findings(items: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str, str], dict[str, Any]] = {}
    for item in items:
        key = (str(item["code"]), str(item["level"]), str(item["message"]))
        if key not in grouped:
            grouped[key] = {**item, "count": int(item.get("count", 1)), "paths": [str(item["path"])]}
        else:
            grouped[key]["count"] += int(item.get("count", 1))
            grouped[key]["paths"].append(str(item["path"]))
    result: list[dict[str, Any]] = []
    for value in grouped.values():
        value["paths"] = sorted(set(value["paths"]))
        value["path"] = ", ".join(value["paths"])
        result.append(value)
    return sorted(result, key=lambda item: (item["level"], item["code"], item["path"]))


def documentation_authority_findings(
    goal: dict[str, Any] | None,
    actor_role: str,
    changed_paths: Iterable[str],
    local_paths: Iterable[str],
    db_observation: str,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    changed = sorted(set(str(item) for item in changed_paths))
    local = sorted(set(str(item) for item in local_paths))
    if actor_role not in {"root", "lead"}:
        findings.append(finding("INVALID_DOCS_ACTOR", "ERROR", actor_role, "docs-update actor must be root or lead"))
    if actor_role == "lead" and goal is None:
        for path in [item for item in changed if is_documentation_path(item)] + local:
            findings.append(
                finding(
                    "LEAD_DOCS_GOAL_REQUIRED", "ERROR", path,
                    "lead documentation writes require a goal with declared docs authority",
                )
            )
    if goal is not None:
        manifest = goal.get("write_manifest") if isinstance(goal.get("write_manifest"), list) else []
        authority = goal.get("docs_authority") if isinstance(goal.get("docs_authority"), dict) else {}
        local_authority = authority.get("local_paths") if isinstance(authority.get("local_paths"), dict) else {}
        local_allowed = [*local_authority.get("write", []), *local_authority.get("append", [])]
        outside_manifest = [path for path in changed if path not in manifest]
        for path in outside_manifest:
            findings.append(finding("MANIFEST_VIOLATION", "ERROR", path, "changed path is outside the goal write manifest"))
        if actor_role == "lead":
            tracked = authority.get("tracked_paths") if isinstance(authority.get("tracked_paths"), dict) else {}
            tracked_allowed = [*tracked.get("write", []), *tracked.get("append", [])]
            for path in changed:
                if is_documentation_path(path) and not _path_allowed(path, tracked_allowed):
                    findings.append(
                        finding(
                            "UNAUTHORIZED_TRACKED_DOC", "ERROR", path,
                            "lead changed tracked documentation outside declared docs authority",
                        )
                    )
            for path in local:
                if not _path_allowed(path, local_allowed):
                    findings.append(
                        finding(
                            "UNAUTHORIZED_LOCAL_DOC", "ERROR", path,
                            "lead changed local or ignored documentation outside declared local authority",
                        )
                    )
        for path in local:
            if not _path_allowed(path, local_allowed):
                findings.append(
                    finding(
                        "LOCAL_SCOPE_VIOLATION", "ERROR", path,
                        "local or ignored write is outside the Full goal local authority",
                    )
                )
        if db_observation != "NONE" and authority.get("db", "none") == "none":
            findings.append(
                finding(
                    "DB_AUTHORITY_VIOLATION", "ERROR", "db",
                    "DB observation was declared while the goal grants db: none",
                )
            )
    elif db_observation != "NONE":
        findings.append(
            finding(
                "DB_AUTHORITY_VIOLATION", "ERROR", "db",
                "DB observations require a Full goal with explicit DB authority",
            )
        )
    if db_observation == "VERIFIED":
        findings.append(
            finding(
                "UNOBSERVABLE_DB_VERIFICATION", "ERROR", "db",
                "local docs-update cannot independently label a DB effect VERIFIED; use ATTESTED",
            )
        )
    elif db_observation not in {"NONE", "ATTESTED"}:
        findings.append(finding("INVALID_DB_OBSERVATION", "ERROR", "db", f"invalid DB observation: {db_observation}"))
    return _aggregate_findings(findings)


def _normalize_surface(value: Any) -> tuple[str | None, bool]:
    if isinstance(value, str):
        return value, True
    if isinstance(value, dict):
        return value.get("outcome"), value.get("fresh", True) is not False
    return None, True


def evaluate_docs_update(
    root: Path,
    checkpoint: str,
    evaluations: dict[str, Any],
    *,
    goal: dict[str, Any] | None = None,
    actor_role: str | None = None,
    changed_paths: Iterable[str] | None = None,
    local_paths: Iterable[str] = (),
    db_observation: str = "NONE",
    publishing: bool = False,
    scope: str = "all",
) -> dict[str, Any]:
    root = root.resolve()
    changed = current_changed_paths(root, scope) if changed_paths is None else sorted(set(changed_paths))
    local = sorted(set(str(item) for item in local_paths))
    required = required_docs_surfaces(checkpoint, changed, goal=goal, publishing=publishing)
    findings: list[dict[str, Any]] = documentation_authority_findings(
        goal, actor_role, changed, local, db_observation.upper()
    )
    goal_records, _ = load_goal_records(root)
    findings.extend(rendered_cache_findings(root, goal_records))
    if goal is None:
        for record in goal_records:
            meta = record.get("meta", {})
            if (
                meta.get("status") in ACTIVE_GOAL_STATUSES
                and str(meta.get("worktree")) == str(root)
            ):
                findings.append(
                    finding(
                        "ACTIVE_GOAL_UNBOUND", "WARNING", str(meta.get("id")),
                        "evaluation ran without --goal while an active goal records this worktree",
                    )
                )
    normalized: dict[str, dict[str, Any]] = {}
    partial = False
    for surface, raw in sorted(evaluations.items()):
        outcome, fresh = _normalize_surface(raw)
        normalized[surface] = {"outcome": outcome, "fresh": fresh}
        if outcome not in DOC_SURFACE_OUTCOMES:
            findings.append(finding("INVALID_SURFACE_OUTCOME", "ERROR", surface, f"invalid outcome: {outcome}"))
        if not fresh:
            findings.append(
                finding(
                    "STALE_DOCUMENTATION_SURFACE", "ERROR", surface,
                    "surface was evaluated from stale evidence",
                )
            )
        if outcome in {"PROPOSED", "OUT_OF_SCOPE"}:
            partial = True
    for surface in sorted(required - set(normalized)):
        findings.append(
            finding(
                "MISSING_SURFACE_EVALUATION", "ERROR", surface,
                "required documentation surface was not evaluated",
            )
        )
    if checkpoint == "final" and goal is not None:
        report = goal.get("report")
        if not isinstance(report, str) or not valid_repository_path(report) or not (root / report).is_file():
            findings.append(
                finding("MISSING_FINAL_REPORT", "ERROR", str(report), "final checkpoint requires its linked report")
            )
    findings = _aggregate_findings(findings)
    verdict = "FAIL" if any(item["level"] == "ERROR" for item in findings) else "PARTIAL" if partial else "PASS"
    state = repository_state(root, changed, scope=scope, local_paths=local)
    receipt = {
        "version": 1,
        "checkpoint": checkpoint,
        "publishing": publishing,
        "goal_id": goal.get("id") if goal else None,
        "actor_role": actor_role,
        "db_observation": db_observation.upper(),
        "head": state["head"],
        "scope": scope,
        "diff_hash": state["diff_hash"],
        "paths": state["paths"],
        "local_paths": state["local_paths"],
        "required_surfaces": sorted(required),
        "evaluations": normalized,
        "verdict": verdict,
    }
    return {
        "verdict": verdict,
        "checkpoint": checkpoint,
        "required_surfaces": sorted(required),
        "findings": findings,
        "receipt": receipt,
    }


def write_docs_receipt(root: Path, receipt: dict[str, Any]) -> Path:
    path = root.resolve() / ".harness" / "cache" / DOCS_RECEIPT_NAME
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def _goal_by_id(root: Path, goal_id: str | None) -> dict[str, Any] | None:
    if goal_id is None:
        return None
    goals, _ = load_goal_records(root)
    record = next((item for item in goals if item["meta"].get("id") == goal_id), None)
    return record["meta"] if record else None


def check_docs_receipt(
    root: Path,
    path: Path | None = None,
    *,
    expected_verdict: str | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    receipt_path = path or root / ".harness" / "cache" / DOCS_RECEIPT_NAME
    if not receipt_path.is_file():
        item = finding("MISSING_DOCS_RECEIPT", "ERROR", receipt_path, "docs-update receipt is missing")
        return {"ok": False, "findings": _aggregate_findings([item])}
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        item = finding("INVALID_DOCS_RECEIPT", "ERROR", receipt_path, str(exc))
        return {"ok": False, "findings": _aggregate_findings([item])}
    findings: list[dict[str, Any]] = []
    if receipt.get("version") != 1:
        findings.append(finding("INVALID_RECEIPT_VERSION", "ERROR", receipt_path, "unsupported receipt version"))
    scope = receipt.get("scope", "all")
    actual_paths = current_changed_paths(root, scope)
    recorded_paths = sorted(set(receipt.get("paths", [])))
    if actual_paths != recorded_paths:
        findings.append(
            finding(
                "STALE_RECEIPT_PATHS", "ERROR", receipt_path,
                "receipt paths do not match the current Git change set",
            )
        )
    state = repository_state(
        root, actual_paths, scope=scope, local_paths=receipt.get("local_paths", [])
    )
    if receipt.get("head") != state["head"]:
        findings.append(finding("STALE_RECEIPT_HEAD", "ERROR", receipt_path, "receipt HEAD is stale"))
    if receipt.get("diff_hash") != state["diff_hash"]:
        findings.append(finding("STALE_RECEIPT_DIFF", "ERROR", receipt_path, "receipt diff hash is stale"))
    goal = _goal_by_id(root, receipt.get("goal_id"))
    if receipt.get("goal_id") and goal is None:
        findings.append(finding("UNKNOWN_RECEIPT_GOAL", "ERROR", receipt_path, "receipt goal does not exist"))
    actor_role = receipt.get("actor_role")
    if actor_role not in {"root", "lead"}:
        findings.append(
            finding(
                "INVALID_RECEIPT_ROLE", "ERROR", receipt_path,
                "receipt must record an explicit root or lead actor-role attestation",
            )
        )
    recomputed = None
    if actor_role in {"root", "lead"}:
        try:
            recomputed = evaluate_docs_update(
                root,
                receipt.get("checkpoint"),
                receipt.get("evaluations", {}),
                goal=goal,
                actor_role=actor_role,
                changed_paths=actual_paths,
                local_paths=receipt.get("local_paths", []),
                db_observation=receipt.get("db_observation", "NONE"),
                publishing=bool(receipt.get("publishing", False)),
                scope=scope,
            )
        except (HarnessError, TypeError, ValueError) as exc:
            findings.append(finding("INVALID_DOCS_RECEIPT", "ERROR", receipt_path, str(exc)))
    if recomputed and receipt.get("verdict") != recomputed["verdict"]:
        findings.append(
            finding(
                "RECEIPT_VERDICT_MISMATCH", "ERROR", receipt_path,
                "receipt verdict does not match a current deterministic evaluation",
            )
        )
    if expected_verdict is not None and receipt.get("verdict") != expected_verdict:
        findings.append(
            finding(
                "RECEIPT_EXPECTED_VERDICT_MISMATCH", "ERROR", receipt_path,
                f"expected {expected_verdict}, receipt records {receipt.get('verdict')}",
            )
        )
    findings = _aggregate_findings(findings)
    return {"ok": not findings, "receipt": receipt, "findings": findings}


def load_pattern_ids(root: Path) -> tuple[set[str], list[dict[str, str]]]:
    index_path = root / ".harness" / "patterns" / "index.yaml"
    if not index_path.is_file():
        return set(), []
    try:
        parsed = parse_yaml_subset(index_path.read_text(encoding="utf-8"))
    except (OSError, HarnessError) as exc:
        return set(), [finding("INVALID_PATTERN_INDEX", "ERROR", index_path, str(exc))]
    if not isinstance(parsed, dict) or not parsed:
        return set(), [
            finding("INVALID_PATTERN_INDEX", "ERROR", index_path, "pattern index must be a non-empty mapping")
        ]
    return set(parsed), []


def product_manifest_paths(manifest: list[Any]) -> list[str]:
    return [
        str(item)
        for item in manifest
        if isinstance(item, str)
        and (item == "index.html" or item.startswith(("js/", "supabase/")))
    ]


def validate_goal_meta(
    meta: dict[str, Any], path: Path, pattern_ids: set[str] | None = None
) -> list[dict[str, str]]:
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
        wildcard_paths = [
            str(item)
            for item in manifest
            if isinstance(item, str) and any(marker in item for marker in ("*", "?", "[", "]"))
        ]
        if wildcard_paths:
            findings.append(
                finding(
                    "WILDCARD_MANIFEST_PATH",
                    "ERROR",
                    path,
                    "write_manifest requires exact paths, not patterns: "
                    + ", ".join(wildcard_paths),
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
        if checkpoint.get("kind") not in GOAL_CHECKPOINT_KINDS:
            findings.append(
                finding(
                    "INVALID_CHECKPOINT_KIND", "ERROR", path,
                    f"invalid checkpoint kind: {checkpoint.get('kind')}",
                )
            )
        head = checkpoint.get("head")
        if head is not None and (not isinstance(head, str) or not SHA_RE.fullmatch(head)):
            findings.append(finding("INVALID_CHECKPOINT_HEAD", "ERROR", path, f"invalid checkpoint head: {head}"))
        if checkpoint.get("docs_verdict") not in DOCS_VERDICTS:
            findings.append(finding("INVALID_DOCS_VERDICT", "ERROR", path, f"invalid docs verdict: {checkpoint.get('docs_verdict')}"))
    pattern_refs = meta.get("pattern_refs", [])
    if pattern_refs is None:
        pattern_refs = []
    if not isinstance(pattern_refs, list):
        findings.append(finding("INVALID_PATTERN_REFS", "ERROR", path, "pattern_refs must be a list"))
    else:
        malformed = [
            str(item) for item in pattern_refs
            if not isinstance(item, str) or not PATTERN_ID_RE.fullmatch(item)
        ]
        if malformed:
            findings.append(
                finding(
                    "INVALID_PATTERN_REF", "ERROR", path,
                    "pattern ids must look like MODAL-ROUTER-01: " + ", ".join(malformed),
                )
            )
        if pattern_ids is not None:
            unknown = [str(item) for item in pattern_refs if isinstance(item, str) and item not in pattern_ids]
            if unknown:
                findings.append(
                    finding(
                        "UNKNOWN_PATTERN_REF", "ERROR", path,
                        "pattern id is not in .harness/patterns/index.yaml: " + ", ".join(unknown),
                    )
                )
        exceptions = meta.get("pattern_exceptions", [])
        if isinstance(manifest, list) and product_manifest_paths(manifest):
            if not pattern_refs and not (isinstance(exceptions, list) and exceptions):
                findings.append(
                    finding(
                        "MISSING_PATTERN_REF", "ERROR", path,
                        "goals writing product code require pattern_refs or recorded pattern_exceptions",
                    )
                )
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
    pattern_ids, pattern_findings = load_pattern_ids(root)
    findings.extend(pattern_findings)
    findings.extend(validate_unique_ids(goals, "goal"))
    findings.extend(validate_unique_ids(decisions, "decision"))
    goal_ids = {record.get("meta", {}).get("id") for record in goals}
    for record in goals:
        meta, path = record["meta"], Path(record["path"])
        findings.extend(validate_goal_meta(meta, path, pattern_ids=pattern_ids))
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
        "pattern_count": len(pattern_ids),
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


def git_commit_exists(root: Path, sha: str) -> bool:
    return run_git(root, "cat-file", "-e", f"{sha}^{{commit}}", check=False).returncode == 0


def git_is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    return (
        run_git(root, "merge-base", "--is-ancestor", ancestor, descendant, check=False).returncode
        == 0
    )


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
        if fact:
            base_sha = meta.get("base_sha")
            launch_sha = meta.get("launch_sha")
            base_exists = isinstance(base_sha, str) and git_commit_exists(root, base_sha)
            launch_exists = isinstance(launch_sha, str) and git_commit_exists(root, launch_sha)
            if isinstance(base_sha, str) and not base_exists:
                findings.append(
                    finding(
                        "BASE_SHA_NOT_FOUND",
                        "ERROR",
                        record["path"],
                        f"goal base_sha is not a commit in Git: {base_sha}",
                    )
                )
            if isinstance(launch_sha, str) and not launch_exists:
                findings.append(
                    finding(
                        "LAUNCH_SHA_NOT_FOUND",
                        "ERROR",
                        record["path"],
                        f"goal launch_sha is not a commit in Git: {launch_sha}",
                    )
                )
            if base_exists and launch_exists and not git_is_ancestor(root, base_sha, launch_sha):
                findings.append(
                    finding(
                        "BASE_SHA_NOT_IN_LAUNCH_HISTORY",
                        "ERROR",
                        record["path"],
                        f"base_sha {base_sha} is not an ancestor of launch_sha {launch_sha}",
                    )
                )
            worktree_head = fact.get("head")
            if (
                launch_exists
                and isinstance(worktree_head, str)
                and not git_is_ancestor(root, launch_sha, worktree_head)
            ):
                findings.append(
                    finding(
                        "LAUNCH_SHA_NOT_IN_WORKTREE_HISTORY",
                        "ERROR",
                        record["path"],
                        f"launch_sha {launch_sha} is not an ancestor of worktree HEAD {worktree_head}",
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


def render_memory_index(root: Path) -> str:
    directory = root / ".harness" / "memory"
    rows: list[tuple[str, str]] = []
    if directory.exists():
        for path in sorted(directory.rglob("*.md")):
            if path.name.casefold() == "readme.md":
                continue
            lines = path.read_text(encoding="utf-8").splitlines()
            title = next(
                (line[2:].strip() for line in lines if line.startswith("# ")),
                path.stem,
            )
            rows.append((str(path.relative_to(root)), title.replace("|", "\\|")))
    lines = ["# Generated Memory Index", "", "| Path | Subject |", "|---|---|"]
    lines.extend(f"| {path} | {title} |" for path, title in rows)
    return "\n".join(lines) + "\n"


def rendered_cache_findings(
    root: Path, goals: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    expected = {
        "BOARD.md": render_board(goals),
        "HANDOFF.md": render_handoff(goals),
        "GOAL-INDEX.md": render_goal_index(goals),
        "MEMORY-INDEX.md": render_memory_index(root),
    }
    findings: list[dict[str, Any]] = []
    for name, content in expected.items():
        path = root / ".harness" / "cache" / name
        if path.is_file() and path.read_text(encoding="utf-8") != content:
            findings.append(
                finding(
                    "STALE_RENDERED_VIEW", "WARNING", path,
                    "cached generated view differs from canonical inputs",
                )
            )
    return _aggregate_findings(findings)


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


def parse_surface_arguments(values: Iterable[str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for value in values:
        name, separator, outcome = value.partition("=")
        if not separator or not name or not outcome:
            raise HarnessError(f"surface evaluation must be NAME=OUTCOME: {value}")
        if name in result:
            raise HarnessError(f"duplicate surface evaluation: {name}")
        result[name] = outcome
    return result


TRAILER_RE = re.compile(r"^(Docs-Update|Tests):\s*(PASS|PARTIAL|FAIL)\s*$", re.MULTILINE)


def commit_gate(
    root: Path,
    *,
    goal: dict[str, Any] | None = None,
    message_file: Path | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    findings: list[dict[str, Any]] = []
    hooks_path = run_git(root, "config", "core.hooksPath", check=False).stdout.strip()
    if hooks_path:
        findings.append(
            finding("HOOKS_PATH_SET", "ERROR", ".git/config", f"core.hooksPath is set: {hooks_path}")
        )
    common_dir = run_git(root, "rev-parse", "--git-common-dir").stdout.strip()
    common_path = Path(common_dir) if common_dir else root / ".git"
    if not common_path.is_absolute():
        common_path = root / common_path
    hook_file = common_path / "hooks" / "pre-commit"
    hook_state = "present" if hook_file.is_file() else "missing"
    if hook_state == "missing":
        findings.append(
            finding(
                "NO_PRE_COMMIT_HOOK", "WARNING", str(hook_file),
                "no pre-commit hook present; the contract keeps the existing hook reachable",
            )
        )
    receipt_path = root / ".harness" / "cache" / DOCS_RECEIPT_NAME
    checked = check_docs_receipt(root, receipt_path, expected_verdict="PASS")
    findings.extend(checked["findings"])
    receipt = checked.get("receipt") or {}
    if checked.get("ok") and receipt.get("scope") != "staged":
        findings.append(
            finding(
                "WRONG_RECEIPT_SCOPE", "ERROR", str(receipt_path),
                f"commit gate requires a staged-scope receipt, found scope {receipt.get('scope')}",
            )
        )
    staged = current_changed_paths(root, "staged")
    if goal is not None:
        manifest = goal.get("write_manifest") if isinstance(goal.get("write_manifest"), list) else []
        for path in staged:
            if path not in manifest:
                findings.append(
                    finding("MANIFEST_VIOLATION", "ERROR", path, "staged path is outside the goal write manifest")
                )
        receipt_goal = receipt.get("goal_id") if isinstance(receipt, dict) else None
        if not receipt or receipt_goal != goal.get("id"):
            findings.append(
                finding(
                    "RECEIPT_GOAL_MISMATCH", "ERROR", str(receipt_path),
                    f"the staged receipt must record the gate goal {goal.get('id')}",
                )
            )
    message = ""
    if message_file is not None:
        try:
            message = Path(message_file).read_text(encoding="utf-8")
        except OSError as exc:
            findings.append(finding("INVALID_MESSAGE_FILE", "ERROR", str(message_file), str(exc)))
    for match in TRAILER_RE.finditer(message):
        kind, verdict = match.group(1), match.group(2)
        if kind == "Tests":
            findings.append(
                finding(
                    "UNSUPPORTED_TESTS_TRAILER", "ERROR", str(message_file),
                    "Tests trailers require a test-receipt kind that does not exist; remove the trailer",
                )
            )
        elif not checked.get("ok") or receipt.get("verdict") != verdict:
            findings.append(
                finding(
                    "FABRICATED_DOCS_TRAILER", "ERROR", str(message_file),
                    f"Docs-Update: {verdict} is not backed by a current matching staged receipt",
                )
            )
    findings = _aggregate_findings(findings)
    return {
        "ok": not any(item["level"] == "ERROR" for item in findings),
        "findings": findings,
        "receipt_path": str(receipt_path),
        "pre_commit_hook": hook_state,
        "staged_paths": staged,
    }


def push_gate(
    root: Path,
    *,
    goal: dict[str, Any] | None = None,
    receipt: Path | None = None,
    remote: str = "origin/main",
    branch: str = "main",
) -> dict[str, Any]:
    root = root.resolve()
    findings: list[dict[str, Any]] = []
    if goal is None and receipt is None:
        findings.append(
            finding(
                "NO_ACCEPTANCE_EVIDENCE", "ERROR", str(root),
                "push gate requires a finalized goal or a current final receipt",
            )
        )
    if goal is not None:
        checkpoint = goal.get("checkpoint") if isinstance(goal.get("checkpoint"), dict) else {}
        if checkpoint.get("kind") != "final(publishing=true)" or checkpoint.get("docs_verdict") != "PASS":
            findings.append(
                finding(
                    "NOT_FINALIZED", "ERROR", str(goal.get("id", "goal")),
                    "goal checkpoint must be final(publishing=true) with docs_verdict PASS",
                )
            )
    if receipt is not None:
        checked = check_docs_receipt(root, Path(receipt), expected_verdict="PASS")
        findings.extend(checked["findings"])
        gate_receipt = checked.get("receipt") or {}
        if gate_receipt and (
            gate_receipt.get("checkpoint") != "final" or not gate_receipt.get("publishing")
        ):
            findings.append(
                finding(
                    "NOT_FINAL_RECEIPT", "ERROR", str(receipt),
                    "push-gate receipt must be a final(publishing=true) evaluation",
                )
            )
    local = run_git(root, "rev-parse", branch).stdout.strip()
    remote_result = None
    if not remote.startswith("refs/"):
        remote_result = run_git(root, "rev-parse", "--verify", f"refs/remotes/{remote}", check=False)
    if remote_result is None or remote_result.returncode != 0:
        remote_result = run_git(root, "rev-parse", "--verify", remote, check=False)
    remote_sha = remote_result.stdout.strip() if remote_result.returncode == 0 else None
    if remote_sha is None:
        findings.append(
            finding("UNKNOWN_REMOTE_REF", "ERROR", remote, f"remote ref not found: {remote}")
        )
    else:
        if not git_is_ancestor(root, remote_sha, local):
            findings.append(
                finding(
                    "NOT_FAST_FORWARD", "ERROR", remote,
                    f"{remote} is not an ancestor of {branch}; refusing a non-fast-forward publish",
                )
            )
        else:
            changed = [
                line for line in run_git(root, "diff", "--name-only", remote_sha, local).stdout.splitlines()
                if line
            ]
            status_lines = run_git(root, "status", "--porcelain=v1").stdout.splitlines()
            tracked_dirty = {
                line[3:].split(" -> ")[-1]
                for line in status_lines
                if line and not line.startswith("??") and any(c in "MDCTR" for c in line[:2])
            }
            overlap = sorted(set(changed) & tracked_dirty)
            if overlap:
                findings.append(
                    finding(
                        "DIRTY_RANGE_PATHS", "ERROR", ", ".join(overlap),
                        "locally modified paths inside the publish range must be clean",
                    )
                )
    findings = _aggregate_findings(findings)
    return {
        "ok": not any(item["level"] == "ERROR" for item in findings),
        "findings": findings,
        "remote_range": f"{remote_sha}..{local}" if remote_sha else None,
        "local_head": local,
        "deploy_boundary": "push is not deploy; deploy, live DB, and destructive actions remain separate gates",
    }


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
    docs = sub.add_parser("docs-update")
    docs.add_argument("checkpoint", choices=sorted(CHECKPOINT_KINDS))
    docs.add_argument("--goal")
    docs.add_argument("--role", choices=("root", "lead"), required=True)
    docs.add_argument("--surface", action="append", default=[])
    docs.add_argument("--local-path", action="append", default=[])
    docs.add_argument("--db-observation", choices=("NONE", "ATTESTED", "VERIFIED"), default="NONE")
    docs.add_argument("--publishing", action="store_true")
    docs.add_argument("--scope", choices=("all", "staged"), default="all")
    docs.add_argument("--write-receipt", action="store_true")
    docs.add_argument("--json", action="store_true")
    receipt = sub.add_parser("receipt-check")
    receipt.add_argument("--path", type=Path)
    receipt.add_argument("--expect", choices=("PASS", "PARTIAL", "FAIL"))
    receipt.add_argument("--json", action="store_true")
    commit = sub.add_parser("commit-gate")
    commit.add_argument("--goal")
    commit.add_argument("--message-file", type=Path)
    commit.add_argument("--json", action="store_true")
    push = sub.add_parser("push-gate")
    push.add_argument("--goal")
    push.add_argument("--receipt", type=Path)
    push.add_argument("--remote", default="origin/main")
    push.add_argument("--branch", default="main")
    push.add_argument("--json", action="store_true")
    render = sub.add_parser("render")
    render.add_argument("view", choices=("board", "handoff", "goal-index", "memory-index"))
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
    elif command == "docs-update":
        goal = None
        if args.goal:
            record = next((item for item in goals if item["meta"].get("id") == args.goal), None)
            if record is None:
                raise HarnessError(f"unknown goal: {args.goal}")
            goal = record["meta"]
        payload = evaluate_docs_update(
            root,
            args.checkpoint,
            parse_surface_arguments(args.surface),
            goal=goal,
            actor_role=args.role,
            local_paths=args.local_path,
            db_observation=args.db_observation,
            publishing=args.publishing,
            scope=args.scope,
        )
        if args.write_receipt:
            payload["receipt_path"] = str(write_docs_receipt(root, payload["receipt"]))
        print_payload(payload, args.json)
        return 0 if payload["verdict"] == "PASS" else 1
    elif command == "receipt-check":
        payload = check_docs_receipt(root, args.path, expected_verdict=args.expect)
        print_payload(payload, args.json)
        return 0 if payload["ok"] else 1
    elif command in {"commit-gate", "push-gate"}:
        goal = None
        if args.goal:
            record = next((item for item in goals if item["meta"].get("id") == args.goal), None)
            if record is None:
                raise HarnessError(f"unknown goal: {args.goal}")
            goal = record["meta"]
        if command == "commit-gate":
            payload = commit_gate(root, goal=goal, message_file=args.message_file)
        else:
            payload = push_gate(
                root, goal=goal, receipt=args.receipt, remote=args.remote, branch=args.branch
            )
        print_payload(payload, args.json)
        return 0 if payload["ok"] else 1
    elif command == "render":
        renderers = {
            "board": lambda: render_board(goals),
            "handoff": lambda: render_handoff(goals),
            "goal-index": lambda: render_goal_index(goals),
            "memory-index": lambda: render_memory_index(root),
        }
        names = {
            "board": "BOARD.md",
            "handoff": "HANDOFF.md",
            "goal-index": "GOAL-INDEX.md",
            "memory-index": "MEMORY-INDEX.md",
        }
        content = renderers[args.view]()
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
