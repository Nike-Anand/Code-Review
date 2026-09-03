# PRAssist (local)

This workspace contains a minimal local backend and Flutter client scaffold for PRAssist.ai.

Folders:
- `backend/` - Node.js Express backend with Ollama integration (mocked/fallback)
- `flutter_app/` - Minimal Flutter client scaffold

Quick start (backend):

```bash
cd backend
npm install
# ensure Ollama is running locally (if you have it)
# export OLLAMA_API if running on non-default host
node server.js
```

API endpoints:
- `POST /api/analyze-pr` { pr_link, repo_url }
- `POST /api/approve-pr` { pr_id }
- `POST /webhooks/teams` - teams webhook receiver
- `POST /webhooks/gitlab` - gitlab webhook receiver

Flutter client:

```bash
cd flutter_app
# install flutter SDK and run
flutter pub get
flutter run
```

Notes:
- The backend currently uses mock PR/repo fetchers and returns mock analysis if Ollama is unreachable.
- Next steps: integrate GitHub/GitLab API clients, persist settings, add push notifications.
