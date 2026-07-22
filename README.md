# blockful/.github

Reusable GitHub Actions and workflows for the Blockful org.

## ClickUp ↔ GitHub sync

Syncs ClickUp tasks with GitHub activity. What it does:

| GitHub event                                | ClickUp status           |
| -------------------------------------------- | ------------------------ |
| Branch with `DEV-XXX` pushed                | `[2] in progress 🤠`\*   |
| Draft PR opened                             | `[2] in progress 🤠`\*   |
| PR opened (non-draft) or `ready_for_review` | `[3] code review 🤓`     |
| Review with changes requested               | `[4] cr code changes 💢` |
| New push while the task is in `[4]`         | `[3] code review 🤓`     |
| PR merged into `dev`                        | `[9] approved by qa 🏳️‍🌈` |
| Commits land on `main` (release)            | `[10] done ❤️‍🔥`\*        |

\* Guarded: never downgrades a task already at an equal or higher status order.

On top of that: it fills the task's "PR" custom field (URL type) with the PR link
when the PR opens, and emits a non-blocking warning when a PR references no task.
Bot PRs (dependabot, github-actions, renovate, "Version Packages") are ignored.

The task ID is extracted from the branch name, falling back to the PR title and body.

### Adoption (any repo in the org)

1. Make sure the repo has access to the `CLICKUP_API_TOKEN` org secret.
2. Create `.github/workflows/clickup.yaml`:

    ```yaml
    name: ClickUp sync

    on:
      create:
      pull_request:
        types: [opened, ready_for_review, synchronize, closed]
      pull_request_review:
        types: [submitted]
      push:
        branches: [main]

    permissions:
      contents: read
      pull-requests: read

    jobs:
      pr-sync:
        if: github.event_name != 'push'
        uses: blockful/.github/.github/workflows/clickup-pr-sync.yaml@main
        secrets:
          clickup_token: ${{ secrets.CLICKUP_API_TOKEN }}
      release-sync:
        if: github.event_name == 'push'
        uses: blockful/.github/.github/workflows/clickup-release-sync.yaml@main
        secrets:
          clickup_token: ${{ secrets.CLICKUP_API_TOKEN }}
    ```

3. Done. Teams outside the Tech space (different prefix/statuses) can pass `with:`
   overriding `task_prefix`, `team_id`, and the `status_*` inputs — on **both**
   jobs: the PR sync inputs live in `.github/workflows/clickup-pr-sync.yaml` and
   the release sync ones (`status_done` etc.) in
   `.github/workflows/clickup-release-sync.yaml`. Spaces with a different PR link
   field can override `pr_link_field_id` (the ID of a URL-type custom field);
   pass `""` to disable the PR link entirely.
4. Repos that merge PRs straight into `main` (no `dev` branch): pass
   `dev_branch: main` in the `pr-sync` job's `with:`, otherwise the
   "PR merged → qa" transition never fires.

### Caller requirements

- The `permissions:` block above is required: `release-sync` needs
  `contents: read` (checkout) and `pull-requests: read` (`gh pr view`). Without
  them the `workflow_call` fails validation before any step runs.
- This repo must stay **public**: public caller repos (like `anticapture`) cannot
  call reusable workflows hosted in a private repo.

### Known limitations

- The integration **never blocks** merges/CI: ClickUp API failures become warnings
  and the jobs run with `continue-on-error`.
- Statuses without a `[N]` prefix in their name disable the anti-downgrade guard
  (order parsing depends on the numeric prefix).
- The `create` event only fires once the caller workflow exists on the default branch.
- "Changes requested" reviews from someone other than the PR author require review
  permission on the repo (standard GitHub behavior).
