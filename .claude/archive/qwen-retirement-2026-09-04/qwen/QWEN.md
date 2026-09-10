# Qwen Code Workflow Rules

## MCP Server Usage
**Before using any MCP server, verify it's properly configured by running `qwen mcp list` and test with a simple query first.**

This prevents hallucinations and ensures tools are actually available before relying on them.

## UI Changes Verification
**After making UI changes, always verify the fix works before considering the task complete.**

Don't just apply the fix and commit - run the app, test the functionality, and confirm the issue is resolved.

## Shell Command Best Practices
**When shell commands fail, try breaking complex commands into separate simpler commands.**

Example: Instead of `cat file1 file2 file3`, run separate commands to see each file's contents individually.

---

*These rules are derived from actual usage patterns and friction points encountered during development sessions.*
