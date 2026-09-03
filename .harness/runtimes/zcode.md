# ZCode Runtime Adapter

Shared policy: `../contract.md`

ZCode Desktop defaults to its built-in agents. `.zcode/config.json` injects
the tracked shared contract at session start through
`.zcode/hooks/session_contract.py`.

- The session hook reads the contract; it does not embed a policy copy.
- Edit and commit guards are warning-only pointers to shared references.
- Herdr and external worker systems are not selected by default.
- Root/lead owns scope, evidence, and acceptance.

This adapter does not define product, Git, database, or acceptance policy.
