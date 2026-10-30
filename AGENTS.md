# actions

## Private notes

Read `PRIVATE.md` in the repository root before doing anything involving accounts, credentials, signing keys, external registrations or infrastructure. It is gitignored and holds details that must not appear in this repository. The pre-commit hook refuses any commit that tracks a `PRIVATE.md`. Never copy its contents into tracked files, commit messages, issues or pull requests. If it is missing, create it from the outline in the `new-repo-setup` skill and ask the owner for the details.

## Hooks

Run `scripts/install-hooks.sh` once after cloning. It points git at `.githooks`.

## Working here

- This repository is public. Keep hostnames, internal addresses, registry names and host-named runner labels out of every file.
- Every job runs on the self-hosted pool. `runs-on` is an input on every reusable workflow and its default uses OS plus size labels, never a GitHub-hosted runner.
- Pin third-party actions to a full commit SHA with a `# vX.Y.Z` comment.
- Grant each job only the permissions it uses.
- `scripts/actionlint.sh` must pass. CI calls each workflow against `tests/fixtures`.
- Releases come from semantic-release on `main`. Use conventional commit messages; a breaking change to any workflow input needs a major release.
