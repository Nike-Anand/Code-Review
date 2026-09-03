# PRAssist Backend

This is a minimal local Node.js backend for PRAssist.ai. It provides example endpoints to analyze PRs using Ollama (Mistral) and simple webhook receivers.

Setup

```bash
cd backend
npm install
node server.js
```

Environment

- `OLLAMA_API` - optional override for the Ollama generation endpoint (default: `http://localhost:11434/api/generate`)
- `PORT` - server port (default: `3000`)
- `GITHUB_TOKEN` - GitHub personal access token (scope: `repo`) for fetching PRs and approving/merging
- `GITLAB_TOKEN` - GitLab personal access token (scope: `api`) for fetching MRs and approving/merging
- `GITHUB_WEBHOOK_SECRET` - optional secret to verify GitHub webhook signatures
- `GITLAB_WEBHOOK_SECRET` - optional secret to verify GitLab webhooks

You can copy `.env.example` to `.env` and fill in values. The server loads environment variables via `dotenv` if present.

API

- `GET /health` - health check
- `POST /api/analyze-pr` - { pr_link, repo_url }
- `POST /api/approve-pr` - { pr_id }
- `POST /webhooks/teams` - Teams webhook
- `POST /webhooks/gitlab` - GitLab webhook

Notes

This backend currently uses mocked helpers for some fallbacks but also includes GitHub and GitLab integration. If `GITHUB_TOKEN` or `GITLAB_TOKEN` are provided, the server will fetch real PR/MR details and can approve/merge programmatically.

Registration & notifications

- Mobile clients can register a callback to receive simple JSON notifications:

	POST `/notify/register` { "url": "https://example.com/callback" }

	POST `/notify/unregister` { "url": "https://example.com/callback" }

Workflow

1. Start the server: `node server.js`
2. Call `POST /api/analyze-pr` with `{ pr_link, repo_url? }` to run analysis.
3. Approve and merge via `POST /api/approve-pr` with `{ pr_link }`.

CI

A lightweight GitHub Actions workflow checks `server.js` syntax via `npm test`.
