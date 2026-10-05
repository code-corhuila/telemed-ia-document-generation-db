User story
code-corhuila/telemed-ia-docs#26 (HU-016 — Download medical care summary as PDF)

What changes and why
<!-- A few lines. -->

How it was tested

- [ ] db-ci.yml green
- [ ] liquibase validate reports "No validation errors found"
- [ ] liquibase update on an empty schema applies every changeset
- [ ] Second liquibase update applies 0 changesets
- [ ] liquibase rollback-count --count 999 leaves the schema empty
- [ ] liquibase update rebuilds after the rollback

Promotion trail

<!-- Only for PRs targeting qa or main. -->
<!-- List of cherry-picked commits, each with its (cherry picked from commit <sha>) line. -->

Checklist

- [ ] No secrets versioned
- [ ] No schema changes outside this -db repository
- [ ] PR <= 400 lines (tests and generated files excluded)
- [ ] Conventional Commit in the title
