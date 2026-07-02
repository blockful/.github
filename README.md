# blockful/.github

Reusable GitHub Actions and workflows for the Blockful org.

## ClickUp ↔ GitHub sync

Sincroniza tasks do ClickUp com a atividade do GitHub. O que faz:

| Evento GitHub                               | Status ClickUp           |
| -------------------------------------------- | ------------------------ |
| Branch com `DEV-XXX` pushada                | `[2] in progress 🤠`\*   |
| PR draft aberto                             | `[2] in progress 🤠`\*   |
| PR aberto (não-draft) ou `ready_for_review` | `[3] code review 🤓`     |
| Review com changes requested                | `[4] cr code changes 💢` |
| Novo push no PR estando em `[4]`            | `[3] code review 🤓`     |
| PR mergeado em `dev`                        | `[5] qa 😼`              |
| Commits chegam em `main` (release)          | `[10] done ❤️‍🔥`\*        |

\* Com guarda: nunca rebaixa uma task que já esteja em status de ordem maior ou igual.

Além disso: comenta o link do PR na task quando ele abre, e emite um warning
(não bloqueante) quando o PR não referencia nenhuma task. PRs de bots
(dependabot, github-actions, renovate, "Version Packages") são ignorados.

O ID da task é procurado no nome da branch, com fallback no título e corpo do PR.

### Adoção (qualquer repo da org)

1. Garanta que o repo tem acesso ao secret de org `CLICKUP_API_TOKEN`.
2. Crie `.github/workflows/clickup.yaml`:

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

3. Pronto. Para times fora do space Tech (prefixo/status diferentes), passe
   `with:` sobrescrevendo `task_prefix`, `team_id` e os `status_*`
   (veja os inputs em `.github/workflows/clickup-pr-sync.yaml`).

### Requisitos do caller

- O bloco `permissions:` acima é obrigatório: `release-sync` precisa de
  `contents: read` (checkout) e `pull-requests: read` (`gh pr view`). Sem essas
  permissões o `workflow_call` falha na validação, antes de qualquer step rodar.

### Limitações conhecidas

- A integração **nunca bloqueia** merge/CI: falhas da API do ClickUp viram warnings
  e os jobs rodam com `continue-on-error`.
- Statuses sem prefixo `[N]` no nome desabilitam a guarda anti-rebaixamento
  (o parse da ordem depende do prefixo numérico).
- O evento `create` só dispara depois que o caller workflow existe na branch default.
- "Changes requested" em review de quem não é dono do PR requer permissão de review
  no repo (comportamento normal do GitHub).
