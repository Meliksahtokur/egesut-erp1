# Decision Records

Decision records hold governance or architecture choices that outlive one
goal. Each `D-*.md` file uses YAML frontmatter validated against
`../schemas/decision.schema.json` and contains these body sections:

```text
## Context
## Decision
## Consequences
```

Root accepts, rejects, or supersedes decisions. Leads propose decisions in
their reports unless their goal grants exact write authority here. Decisions
are canonical tracked inputs; generated indexes remain in `.harness/cache/`.
