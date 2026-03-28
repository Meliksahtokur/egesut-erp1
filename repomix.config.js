export default {
  include: [
    "CLAUDE.md",
    ".claude/agents/*.md",
    ".claude/domain-rules.md",
    ".claude/rpc-reference.md",
    ".claude/ui-map.md",
    ".claude/session-learnings.md",
    ".claude/knowledge/*.md",
    ".claude/plans/*.md"
  ],
  ignore: {
    useGitignore: true,
    useDefaultPatterns: true
  }
}
