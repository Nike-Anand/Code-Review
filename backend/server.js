const express = require('express');
const axios = require('axios');
const cors = require('cors');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors());

// Simple in-memory caches
const ANALYSIS_CACHE_TTL = parseInt(process.env.ANALYSIS_CACHE_TTL || '300', 10); // seconds
const analysisCache = new Map(); // key: pr_link, value: { ts, data }
const prFilesCache = new Map(); // key: pr_link, value: { ts, files }
// LLM metrics
let llmCallCount = 0;
const llmProviderCounts = {}; // provider -> count

function getCachedAnalysis(key) {
  const e = analysisCache.get(key);
  if (!e) return null;
  if ((Date.now() - e.ts) > ANALYSIS_CACHE_TTL * 1000) { analysisCache.delete(key); return null; }
  return e.data;
}

function setCachedAnalysis(key, data) {
  try { analysisCache.set(key, { ts: Date.now(), data }); } catch (e) { /* ignore */ }
}

// simple metrics endpoint
app.get('/metrics', (req, res) => {
  res.json({
    analysis_cache_size: analysisCache.size,
    prfiles_cache_size: prFilesCache.size,
    analysis_cache_ttl: ANALYSIS_CACHE_TTL,
    llm_call_count: llmCallCount,
    llm_provider_counts: llmProviderCounts,
  });
});

function getCachedFiles(key) {
  const e = prFilesCache.get(key);
  if (!e) return null;
  if ((Date.now() - e.ts) > ANALYSIS_CACHE_TTL * 1000) { prFilesCache.delete(key); return null; }
  return e.files;
}

function setCachedFiles(key, files) {
  try { prFilesCache.set(key, { ts: Date.now(), files }); } catch (e) { }
}

// Ollama local API (fallback)
const OLLAMA_API = process.env.OLLAMA_API || 'http://localhost:11434/api/generate';
// Gemini (Google) settings - if you set GEMINI_API_KEY the server will use Gemini for analysis
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-3.6-flash';
const GEMINI_API_URL = process.env.GEMINI_API_URL || `https://generativelanguage.googleapis.com/v1beta2/models/${GEMINI_MODEL}:generate`;
const GITHUB_API = process.env.GITHUB_API_URL || 'https://api.github.com';
const GITLAB_API = process.env.GITLAB_API_URL || 'https://gitlab.com/api/v4';
const DEFAULT_PROVIDER = process.env.DEFAULT_PROVIDER || 'github';
const DEFAULT_REPO = process.env.DEFAULT_REPO || '';

// Simple health
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Quick LLM connectivity test - returns which provider responded and a short sample
app.get('/api/llm-test', async (req, res) => {
  try {
    const prompt = req.query.prompt || 'Hello from PRAssist LLM test.';
    const r = await runMistral(prompt);
    return res.json({ ok: true, provider: r.provider, success: r.success, text: r.text, error: r.error || null });
  } catch (e) {
    return res.status(500).json({ ok: false, error: e.message });
  }
});

// Analyze PR endpoint
app.post('/api/analyze-pr', async (req, res) => {
  const { pr_link, repo_url } = req.body;

  if (!pr_link) return res.status(400).json({ error: 'pr_link is required' });

  try {
    let pr_data;
    if (isGitHubPR(pr_link)) {
      pr_data = await fetchPRFromGitHub(pr_link);
    } else if (isGitLabMR(pr_link)) {
      pr_data = await fetchPRFromGitLab(pr_link);
    } else {
      pr_data = await fetchPRMock(pr_link);
    }

    const repo_context = repo_url
      ? await fetchRepoContextMock(repo_url)
      : await fetchRepoContextMock(pr_data.repo_url);

    const prompt = buildAnalysisPrompt(pr_data, repo_context);

    // Check cache first
    const cacheKey = pr_link;
    const cached = getCachedAnalysis(cacheKey);
    if (cached) {
      return res.json(Object.assign({}, cached, { cached: true }));
    }

    const llmResult = await runMistral(prompt);
    const analysisText = llmResult && llmResult.text ? llmResult.text : '';

    const verdict = parseVerdict(analysisText);
    const comments = generateComments(analysisText);
    const issues = parseIssuesFromAnalysis(analysisText);

    const responseBody = {
      verdict,
      analysis: analysisText,
      comments,
      issues,
      additions: pr_data.additions || 0,
      deletions: pr_data.deletions || 0,
      files_changed: pr_data.files_changed || [],
      files_changed_count: pr_data.files_changed_count || (pr_data.files_changed || []).length,
      pr_id: pr_data.id,
      provider: pr_data.provider,
      llm: { provider: llmResult.provider || null, success: !!llmResult.success, error: llmResult.error || null }
    };

    // cache the analysis
    if (responseBody.llm && responseBody.llm.provider !== 'mock') { try { setCachedAnalysis(cacheKey, responseBody); } catch (e) { } }

    res.json(responseBody);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// Return files changed for a PR with additions/deletions and optional snippet
app.post('/api/pr-files', async (req, res) => {
  const { pr_link } = req.body || {};
  if (!pr_link) return res.status(400).json({ error: 'pr_link is required' });

  try {
    const cached = getCachedFiles(pr_link);
    if (cached) return res.json({ provider: 'cache', files: cached });

    if (isGitHubPR(pr_link)) {
      const files = await fetchPRFilesFromGitHub(pr_link);
      setCachedFiles(pr_link, files);
      return res.json({ provider: 'github', files });
    }

    if (isGitLabMR(pr_link)) {
      const files = await fetchPRFilesFromGitLab(pr_link);
      return res.json({ provider: 'gitlab', files });
    }

    // fallback: simple mock based on url
    const mock = (await fetchPRMock(pr_link)).files_changed || [];
    const files = mock.map(f => ({ filename: f, additions: 0, deletions: 0 }));
    return res.json({ provider: 'mock', files });
  } catch (e) {
    console.error('pr-files error', e.response ? e.response.data : e.message);
    res.status(500).json({ error: e.message });
  }
});

// Approve PR endpoint - accepts pr_link or provider-specific identifiers
app.post('/api/approve-pr', async (req, res) => {
  const { pr_link, provider } = req.body;

  try {
    if (pr_link && isGitHubPR(pr_link)) {
      const m = pr_link.match(/github\.com\/([^\/]+)\/([^\/]+)\/pull\/(\d+)/i);
      const owner = m[1], repo = m[2], number = m[3];
      await approveAndMergeGitHub(owner, repo, number);
      // record activity and notify clients
      const title = `${owner}/${repo}#${number}`;
      addActivity({ type: 'pr_merged', pr_link, title, provider: 'github', actor: 'pRAssist', message: `PR ${number} merged` });
      notifyPhone({ type: 'pr_merged', pr_link, title, provider: 'github' }).catch(err => console.warn('notifyPhone error', err));
      return res.json({ success: true, message: 'GitHub PR approved and merged' });
    }

    if (pr_link && isGitLabMR(pr_link)) {
      const m = pr_link.match(/gitlab\.com\/(.+?)\/-\/merge_requests\/(\d+)/i);
      const projectPath = encodeURIComponent(m[1]);
      const iid = m[2];
      await approveAndMergeGitLab(projectPath, iid);
      const title = `${m[1]}#${iid}`;
      addActivity({ type: 'pr_merged', pr_link, title, provider: 'gitlab', actor: 'pRAssist', message: `MR ${iid} merged` });
      notifyPhone({ type: 'pr_merged', pr_link, title, provider: 'gitlab' }).catch(err => console.warn('notifyPhone error', err));
      return res.json({ success: true, message: 'GitLab MR approved and merged' });
    }

    return res.status(400).json({ error: 'pr_link (GitHub or GitLab) is required' });
  } catch (err) {
    console.error('approve error', err);
    res.status(500).json({ error: err.message });
  }
});

// Request changes on a PR (create review with REQUEST_CHANGES or post MR note)
app.post('/api/request-changes', async (req, res) => {
  const { pr_link, comment } = req.body || {};
  const note = comment || 'Please address the issues highlighted by PRAssist.';
  try {
    if (!pr_link) return res.status(400).json({ error: 'pr_link is required' });

    if (isGitHubPR(pr_link)) {
      const m = pr_link.match(/github\.com\/([^\/]+)\/([^\/]+)\/pull\/(\d+)/i);
      const owner = m[1], repo = m[2], number = m[3];
      if (!process.env.GITHUB_TOKEN) return res.status(400).json({ error: 'GITHUB_TOKEN not set' });
      const headers = { Authorization: `token ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' };
      try {
        await axios.post(`${GITHUB_API}/repos/${owner}/${repo}/pulls/${number}/reviews`, { body: note, event: 'REQUEST_CHANGES' }, { headers });
        const title = `${owner}/${repo}#${number}`;
        addActivity({ type: 'pr_changes_requested', pr_link, title, provider: 'github', actor: 'pRAssist', message: note });
        notifyPhone({ type: 'pr_changes_requested', pr_link, title, provider: 'github', note }).catch(err => console.warn('notifyPhone error', err));
        return res.json({ success: true, message: 'Requested changes on GitHub PR' });
      } catch (err) {
        console.error('request-changes github error', err.response ? err.response.data : err.message);
        const status = err.response && err.response.status ? err.response.status : 500;
        const details = err.response ? err.response.data : null;
        // If GitHub rejects REQUEST_CHANGES because the token is the PR author
        // fall back to posting a regular issue comment instead of a review.
        try {
          const errorsArr = details && details.errors ? details.errors : [];
          const isSelfReview = Array.isArray(errorsArr) && errorsArr.some(e => {
            try { return (typeof e === 'string' ? e : (e.message||'')).toLowerCase().includes('can not request changes'); } catch (x) { return false; }
          });

          if (status === 422 && isSelfReview) {
            // create an issue comment as a fallback
            try {
              await axios.post(`${GITHUB_API}/repos/${owner}/${repo}/issues/${number}/comments`, { body: note }, { headers });
              const title = `${owner}/${repo}#${number}`;
              addActivity({ type: 'pr_changes_requested', pr_link, title, provider: 'github', actor: 'pRAssist', message: note, fallback: 'comment' });
              notifyPhone({ type: 'pr_changes_requested', pr_link, title, provider: 'github', note, fallback: 'comment' }).catch(err => console.warn('notifyPhone error', err));
              return res.json({ success: true, message: 'Could not create review (self-review); posted a comment instead', fallback: 'comment' });
            } catch (e2) {
              console.error('request-changes github fallback comment error', e2.response ? e2.response.data : e2.message);
              const status2 = e2.response && e2.response.status ? e2.response.status : 500;
              const msg2 = e2.response && e2.response.data && (e2.response.data.message || JSON.stringify(e2.response.data)) ? (e2.response.data.message || JSON.stringify(e2.response.data)) : e2.message;
              return res.status(status2).json({ error: msg2, provider: 'github', details: e2.response ? e2.response.data : null });
            }
          }
        } catch (ex) {
          console.warn('Error checking fallback condition for request-changes', ex.message);
        }

        const msg = details && (details.message || JSON.stringify(details)) ? (details.message || JSON.stringify(details)) : err.message;
        return res.status(status).json({ error: msg, provider: 'github', details });
      }
    }

    if (isGitLabMR(pr_link)) {
      const m = pr_link.match(/gitlab\.com\/(.+?)\/-\/merge_requests\/(\d+)/i);
      const projectPathRaw = m[1];
      const iid = m[2];
      const projectPath = encodeURIComponent(projectPathRaw);
      if (!process.env.GITLAB_TOKEN) return res.status(400).json({ error: 'GITLAB_TOKEN not set' });
      const headers = { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN };
      try {
        await axios.post(`${GITLAB_API}/projects/${projectPath}/merge_requests/${iid}/notes`, { body: note }, { headers });
        const title = `${projectPathRaw}#${iid}`;
        addActivity({ type: 'pr_changes_requested', pr_link, title, provider: 'gitlab', actor: 'pRAssist', message: note });
        notifyPhone({ type: 'pr_changes_requested', pr_link, title, provider: 'gitlab', note }).catch(err => console.warn('notifyPhone error', err));
        return res.json({ success: true, message: 'Requested changes on GitLab MR' });
      } catch (err) {
        console.error('request-changes gitlab error', err.response ? err.response.data : err.message);
        const status = err.response && err.response.status ? err.response.status : 500;
        const msg = err.response && err.response.data && (err.response.data.message || JSON.stringify(err.response.data)) ? (err.response.data.message || JSON.stringify(err.response.data)) : err.message;
        return res.status(status).json({ error: msg, provider: 'gitlab', details: err.response ? err.response.data : null });
      }
    }

    res.status(400).json({ error: 'Unsupported PR provider or missing pr_link' });
  } catch (err) {
    console.error('request-changes error', err);
    res.status(500).json({ error: err.message });
  }
});

// Return latest open PR for the configured repo (GitHub or GitLab)
app.get('/api/latest-pr', async (req, res) => {
  try {
    if (DEFAULT_PROVIDER.toLowerCase() === 'github') {
      if (!process.env.GITHUB_TOKEN) return res.status(400).json({ error: 'GITHUB_TOKEN not set' });
      const headers = { Authorization: `token ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' };
      if (DEFAULT_REPO) {
        const m = DEFAULT_REPO.match(/([^\/]+)\/([^\/]+)/);
        if (!m) return res.status(400).json({ error: 'DEFAULT_REPO must be owner/repo' });
        const owner = m[1], repo = m[2];
        const pulls = (await axios.get(`${GITHUB_API}/repos/${owner}/${repo}/pulls?state=open&sort=updated&direction=desc&per_page=1`, { headers })).data;
        if (!pulls || !pulls.length) return res.status(404).json({ error: 'No open PRs' });
        const pr = pulls[0];
        return res.json({ provider: 'github', pr_link: pr.html_url, title: pr.title, number: pr.number, owner, repo });
      }

      // Fallback: search most recently updated open PRs accessible to the token
      const search = (await axios.get(`${GITHUB_API}/search/issues?q=type:pr+state:open&sort=updated&order=desc&per_page=1`, { headers })).data;
      const item = search?.items?.[0];
      if (!item) return res.status(404).json({ error: 'No open PRs found in search' });
      return res.json({ provider: 'github', pr_link: item.html_url, title: item.title });
    }

    if (DEFAULT_PROVIDER.toLowerCase() === 'gitlab') {
      if (!process.env.GITLAB_TOKEN) return res.status(400).json({ error: 'GITLAB_TOKEN not set' });
      // DEFAULT_REPO expected in "namespace/project" form
      const projectPath = encodeURIComponent(DEFAULT_REPO);
      const headers = { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN };
      const mrs = (await axios.get(`${GITLAB_API}/projects/${projectPath}/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page=1`, { headers })).data;
      if (!mrs || !mrs.length) return res.status(404).json({ error: 'No open MRs' });
      const mr = mrs[0];
      return res.json({ provider: 'gitlab', pr_link: mr.web_url, title: mr.title, iid: mr.iid, project: DEFAULT_REPO });
    }

    res.status(400).json({ error: 'Unsupported DEFAULT_PROVIDER' });
  } catch (e) {
    console.error('latest-pr error', e.response ? e.response.data : e.message);
    res.status(500).json({ error: e.message });
  }
  
});

// Return list of open PRs for the configured repo (latest first)
app.get('/api/prs', async (req, res) => {
  try {
    if (DEFAULT_PROVIDER.toLowerCase() === 'github') {
      if (!process.env.GITHUB_TOKEN) return res.status(400).json({ error: 'GITHUB_TOKEN not set' });
      if (!DEFAULT_REPO) return res.status(400).json({ error: 'DEFAULT_REPO not configured' });
      const m = DEFAULT_REPO.match(/([^\/]+)\/([^\/]+)/);
      if (!m) return res.status(400).json({ error: 'DEFAULT_REPO must be owner/repo' });
      const owner = m[1], repo = m[2];
      const headers = { Authorization: `token ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' };
      const pulls = (await axios.get(`${GITHUB_API}/repos/${owner}/${repo}/pulls?state=open&sort=updated&direction=desc&per_page=100`, { headers })).data || [];
      const mapped = pulls.map(p => ({ provider: 'github', number: p.number, title: p.title, pr_link: p.html_url, author: p.user && p.user.login, created_at: p.created_at, updated_at: p.updated_at, draft: p.draft, labels: (p.labels||[]).map(l=>l.name) }));
      return res.json({ provider: 'github', repo: DEFAULT_REPO, prs: mapped });
    }

    if (DEFAULT_PROVIDER.toLowerCase() === 'gitlab') {
      if (!process.env.GITLAB_TOKEN) return res.status(400).json({ error: 'GITLAB_TOKEN not set' });
      if (!DEFAULT_REPO) return res.status(400).json({ error: 'DEFAULT_REPO not configured' });
      const projectPath = encodeURIComponent(DEFAULT_REPO);
      const headers = { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN };
      const mrs = (await axios.get(`${GITLAB_API}/projects/${projectPath}/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page=100`, { headers })).data || [];
      const mapped = mrs.map(m => ({ provider: 'gitlab', iid: m.iid, title: m.title, pr_link: m.web_url, author: m.author && m.author.username, created_at: m.created_at, updated_at: m.updated_at, labels: m.labels }));
      return res.json({ provider: 'gitlab', repo: DEFAULT_REPO, prs: mapped });
    }

    res.status(400).json({ error: 'Unsupported DEFAULT_PROVIDER' });
  } catch (e) {
    console.error('prs error', e.response ? e.response.data : e.message);
    res.status(500).json({ error: e.message });
  }
});

// Teams webhook
app.post('/webhooks/teams', (req, res) => {
  const message = req.body;
  console.log('Teams webhook received:', JSON.stringify(message).slice(0, 200));
  // extract PR link if present and notify registered clients
  const pr_link = extractPRLinkFromTeams(message);
  if (pr_link) notifyPhone({ type: 'new_pr', pr_link, message: message.summary || '' }).catch(err => console.warn('notifyPhone error', err));
  res.status(200).send('OK');
});

// GitLab webhook (with optional token verification)
app.post('/webhooks/gitlab', (req, res) => {
  const token = req.headers['x-gitlab-token'];
  if (process.env.GITLAB_WEBHOOK_SECRET && token !== process.env.GITLAB_WEBHOOK_SECRET) {
    return res.status(401).send('Invalid token');
  }
  const event = req.body;
  console.log('GitLab webhook event:', event?.object_kind || 'unknown');
  // If MR opened, notify phone endpoints
  try {
    if (event?.object_kind === 'merge_request') {
      const pr_link = event?.object_attributes?.url || event?.object_attributes?.url;
      notifyPhone({ type: 'new_pr', pr_link, title: event?.object_attributes?.title }).catch(err => console.warn('notifyPhone error', err));
    }
  } catch (e) {
    console.warn('processing gitlab webhook', e.message);
  }
  res.status(200).send('OK');
});

// Client registration for push/notification callbacks (persistent)
const fs = require('fs');
const path = require('path');
const CLIENTS_FILE = path.join(__dirname, 'clients.json');

let registeredClients = new Set();

function loadRegisteredClients() {
  try {
    if (fs.existsSync(CLIENTS_FILE)) {
      const data = JSON.parse(fs.readFileSync(CLIENTS_FILE, 'utf8')) || [];
      registeredClients = new Set(data);
    }
  } catch (e) {
    console.warn('Failed to load clients.json', e.message);
    registeredClients = new Set();
  }
}

function saveRegisteredClients() {
  try {
    fs.writeFileSync(CLIENTS_FILE, JSON.stringify(Array.from(registeredClients), null, 2));
  } catch (e) {
    console.warn('Failed to save clients.json', e.message);
  }
}

loadRegisteredClients();

// In-memory activity log for feed (most recent first)
const ACTIVITY_MAX = 200;
const activityLog = [];
function addActivity(entry) {
  try {
    entry.timestamp = entry.timestamp || Date.now();
    activityLog.unshift(entry);
    if (activityLog.length > ACTIVITY_MAX) activityLog.length = ACTIVITY_MAX;
  } catch (e) { /* ignore */ }
}

// Expose activity for clients
app.get('/api/activity', (req, res) => {
  const limit = Math.min(100, parseInt(req.query.limit || '50', 10));
  res.json({ count: activityLog.length, activity: activityLog.slice(0, limit) });
});

// Test-only: add an activity entry (useful locally)
app.post('/api/activity/add', (req, res) => {
  const { type, title, pr_link, message, provider } = req.body || {};
  if (!type || !title) return res.status(400).json({ error: 'type and title required' });
  addActivity({ type, title, pr_link: pr_link || '', message: message || '', provider: provider || 'local', actor: 'local-test' });
  res.json({ success: true });
});

app.post('/notify/register', (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'url is required' });
  registeredClients.add(url);
  saveRegisteredClients();
  res.json({ success: true });
});

app.post('/notify/unregister', (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'url is required' });
  registeredClients.delete(url);
  saveRegisteredClients();
  res.json({ success: true });
});

// GitHub webhook endpoint with signature verification
app.post('/webhooks/github', (req, res) => {
  if (!verifyGitHubSignature(req)) return res.status(401).send('Invalid signature');
  const event = req.body;
  console.log('GitHub webhook:', req.headers['x-github-event']);
  res.status(200).send('OK');
});

// --- Helpers ---
function isGitHubPR(url) {
  return /github\.com\/[^\/]+\/[^\/]+\/pull\/[0-9]+/i.test(url);
}

function isGitLabMR(url) {
  return /gitlab\.com\/.+?\/-\/merge_requests\/[0-9]+/i.test(url);
}

// Compute additions/deletions dynamically from a unified diff (patch) so that
// "lines added / lines deleted / files changed" are accurate even when the
// provider (e.g. GitHub) reports wrong, missing, or truncated counts for large
// files (common in the Flutter/Dart codebase).
function countDiffLines(patch) {
  if (!patch || typeof patch !== 'string') return { additions: 0, deletions: 0 };
  const first = patch.split('\n')[0] || '';
  // Git cannot produce a text diff for binary files; skip them so callers can
  // fall back to the provider-reported counts instead of a bogus 0.
  if (/^GIT binary patch|^Binary files|similarity index/i.test(first)) return { additions: 0, deletions: 0 };
  let additions = 0, deletions = 0;
  for (const raw of patch.split('\n')) {
    const line = raw.replace(/\r$/, '');
    // Skip structural/metadata lines (file markers, hunk headers, index lines...)
    if (/^(diff --git|index |@@|--- |\+\+\+ |new file mode|deleted file mode|rename |similarity index)/.test(line)) continue;
    // Unified diff content lines start with a single '+' or '-'
    if (line.startsWith('+') && !line.startsWith('+++')) additions++;
    else if (line.startsWith('-') && !line.startsWith('---')) deletions++;
  }
  return { additions, deletions };
}

async function fetchPRFromGitHub(prUrl) {
  const m = prUrl.match(/github\.com\/([^\/]+)\/([^\/]+)\/pull\/(\d+)/i);
  if (!m) throw new Error('Bad GitHub PR URL');
  const owner = m[1], repo = m[2], number = m[3];
  const headers = { Authorization: `token ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' };
  const pr = (await axios.get(`${GITHUB_API}/repos/${owner}/${repo}/pulls/${number}`, { headers })).data;
  const files = (await axios.get(`${GITHUB_API}/repos/${owner}/${repo}/pulls/${number}/files`, { headers })).data || [];
  // Compute additions/deletions dynamically from the actual diff patches rather
  // than trusting pr.additions/pr.deletions (only populated with diff/patch
  // media types, and often wrong for large Flutter/Dart files).
  let additions = 0, deletions = 0;
  for (const f of files) {
    const counts = countDiffLines(f.patch || f.diff);
    additions += counts.additions;
    deletions += counts.deletions;
  }
  return {
    provider: 'github',
    id: pr.number,
    number: pr.number,
    owner,
    repo,
    title: pr.title,
    description: pr.body,
    files_changed: files.map(f => f.filename),
    files_changed_count: Math.max(files.length, pr.changed_files || files.length),
    additions: files.length > 0 ? additions : (pr.additions || 0),
    deletions: files.length > 0 ? deletions : (pr.deletions || 0),
    repo_url: `https://github.com/${owner}/${repo}`
  };
}

async function fetchPRFilesFromGitHub(prUrl) {
  const m = prUrl.match(/github\.com\/([^\/]+)\/([^\/]+)\/pull\/(\d+)/i);
  if (!m) throw new Error('Bad GitHub PR URL');
  const owner = m[1], repo = m[2], number = m[3];
  if (!process.env.GITHUB_TOKEN) throw new Error('GITHUB_TOKEN not set');
  const headers = { Authorization: `token ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' };
  const files = (await axios.get(`${GITHUB_API}/repos/${owner}/${repo}/pulls/${number}/files`, { headers })).data || [];
  // map fields the frontend expects; compute line counts dynamically from the
  // patch when possible and relay GitHub's per-file status for accurate badges
  return files.map(f => {
    const counts = countDiffLines(f.patch || f.diff);
    return {
      filename: f.filename,
      path: f.filename,
      status: f.status || null,
      additions: counts.additions > 0 ? counts.additions : (f.additions || 0),
      deletions: counts.deletions > 0 ? counts.deletions : (f.deletions || 0),
      patch: f.patch || null
    };
  });
}

async function fetchPRFromGitLab(prUrl) {
  const m = prUrl.match(/gitlab\.com\/(.+?)\/-\/merge_requests\/(\d+)/i);
  if (!m) throw new Error('Bad GitLab MR URL');
  const projectPathRaw = m[1];
  const iid = m[2];
  const projectPath = encodeURIComponent(projectPathRaw);
  const headers = { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN };
  let mrResp;
  try {
    mrResp = (await axios.get(`${GITLAB_API}/projects/${projectPath}/merge_requests/${iid}`, { headers }));
  } catch (e) {
    const status = e.response && e.response.status;
    if (status === 404) {
      throw new Error(`GitLab project or MR not found. Check DEFAULT_REPO and GITLAB_TOKEN access. Project: ${projectPathRaw}, MR: ${iid}`);
    }
    throw e;
  }
  const mr = mrResp.data;
  const changes = (await axios.get(`${GITLAB_API}/projects/${projectPath}/merge_requests/${iid}/changes`, { headers })).data;
  const files = changes?.changes || [];
  // Compute line counts dynamically from the diff payload; fall back to the
  // MR-level counts only when no diff is available to inspect.
  let additions = 0, deletions = 0;
  for (const c of files) {
    const counts = countDiffLines(c.diff);
    additions += counts.additions;
    deletions += counts.deletions;
  }
  return {
    provider: 'gitlab',
    id: mr.iid,
    iid: mr.iid,
    project: projectPathRaw,
    title: mr.title,
    description: mr.description,
    files_changed: files.map(c => c.new_path || c.old_path),
    files_changed_count: files.length,
    additions: files.length > 0 ? additions : (mr.additions || 0),
    deletions: files.length > 0 ? deletions : (mr.deletions || 0),
    repo_url: mr.web_url ? mr.web_url.replace(/\/-\/merge_requests\/.+$/, '') : ''
  };
}

async function fetchPRFilesFromGitLab(prUrl) {
  const m = prUrl.match(/gitlab\.com\/(.+?)\/-\/merge_requests\/(\d+)/i);
  if (!m) throw new Error('Bad GitLab MR URL');
  const projectPathRaw = m[1];
  const iid = m[2];
  if (!process.env.GITLAB_TOKEN) throw new Error('GITLAB_TOKEN not set');
  const projectPath = encodeURIComponent(projectPathRaw);
  const headers = { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN };
  const resp = (await axios.get(`${GITLAB_API}/projects/${projectPath}/merge_requests/${iid}/changes`, { headers })).data;
  const changes = resp?.changes || [];
  return changes.map(c => {
    // Count lines directly from the diff so per-file stats are accurate
    const counts = countDiffLines(c.diff);
    const newPath = c.new_path || c.old_path;
    return {
      filename: newPath,
      path: newPath,
      status: c.new_path && c.old_path && c.new_path !== c.old_path ? 'renamed' : (c.new_path ? 'added' : 'removed'),
      additions: counts.additions,
      deletions: counts.deletions,
      diff: c.diff || null
    };
  });
}

async function approveAndMergeGitHub(owner, repo, number) {
  if (!process.env.GITHUB_TOKEN) throw new Error('GITHUB_TOKEN not set');
  const headers = { Authorization: `token ${process.env.GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' };
  // submit review approving; if the user is the PR author GitHub returns 422 (cannot approve your own PR)
  try {
    await axios.post(`${GITHUB_API}/repos/${owner}/${repo}/pulls/${number}/reviews`, { event: 'APPROVE' }, { headers });
  } catch (err) {
    const status = err.response && err.response.status;
    const msg = err.response && err.response.data;
    // If it's the self-approval 422, log and continue to merge. Otherwise rethrow.
    if (status === 422 && msg && (msg.errors || []).some(e => (typeof e === 'string' ? e : e.message).toLowerCase().includes('can not approve') || JSON.stringify(msg).toLowerCase().includes('can not approve'))) {
      console.warn('GitHub approve skipped: cannot approve own PR, proceeding to merge');
    } else {
      throw err;
    }
  }
  // attempt merge
  await axios.put(`${GITHUB_API}/repos/${owner}/${repo}/pulls/${number}/merge`, {}, { headers });
}

async function approveAndMergeGitLab(projectPath, iid) {
  if (!process.env.GITLAB_TOKEN) throw new Error('GITLAB_TOKEN not set');
  const headers = { 'PRIVATE-TOKEN': process.env.GITLAB_TOKEN };
  // approve
  await axios.post(`${GITLAB_API}/projects/${projectPath}/merge_requests/${iid}/approve`, {}, { headers });
  // merge
  await axios.put(`${GITLAB_API}/projects/${projectPath}/merge_requests/${iid}/merge`, {}, { headers });
}

function verifyGitHubSignature(req) {
  const secret = process.env.GITHUB_WEBHOOK_SECRET;
  if (!secret) return true;
  const sig = req.headers['x-hub-signature-256'];
  const body = JSON.stringify(req.body);
  const h = 'sha256=' + crypto.createHmac('sha256', secret).update(body).digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(h), Buffer.from(sig || ''));
  } catch (e) {
    return false;
  }
}

function extractPRLinkFromTeams(message) {
  try {
    // Teams message structure varies; search for http(s) links in message
    const text = JSON.stringify(message);
      const m = text.match(/https?:\/\/[^"'\s]+/i);
    return m ? m[0] : null;
  } catch (e) {
    return null;
  }
}

async function notifyPhone(payload) {
  // Simple notifier that POSTs payload to all registered client URLs
  const urls = Array.from(registeredClients);
  if (!urls.length) {
    console.log('No registered clients to notify');
    return;
  }

  // Notify with retry and remove repeatedly failing clients
  await Promise.all(urls.map(async (url) => {
    let attempts = 0;
    let success = false;
    while (attempts < 3 && !success) {
      attempts += 1;
      try {
        await axios.post(url, payload, { timeout: 5000 });
        console.log('Notified', url);
        success = true;
      } catch (e) {
        console.warn(`Notify attempt ${attempts} failed for ${url}:`, e.message);
        await new Promise(r => setTimeout(r, 500 * attempts));
      }
    }

    if (!success) {
      console.warn('Removing unreachable client', url);
      registeredClients.delete(url);
      saveRegisteredClients();
    }
  }));
}

// Fallback mock PR fetcher
async function fetchPRMock(pr_link) {
  return {
    provider: 'mock',
    id: pr_link.split('/').pop() || '123',
    title: 'Mock PR Title',
    description: 'Mock PR description',
    files_changed: ['src/example.js'],
    additions: 10,
    deletions: 2,
    repo_url: pr_link.split('/-/')[0] || ''
  };
}

async function fetchRepoContextMock(repo_url) {
  return `Mock repo context for ${repo_url || 'unknown repo'}`;
}

function buildAnalysisPrompt(pr_data, repo_context) {
  return `You are a senior code reviewer. Analyze this PR:\n\nPR Title: ${pr_data.title}\nPR Description: ${pr_data.description}\nFiles Changed: ${pr_data.files_changed.join(', ')}\nLines Changed: +${pr_data.additions} -${pr_data.deletions}\n\nRepo Context:\n${repo_context}\n\nYour task:\n1. Is this PR needed?\n2. Does it fix the claimed bug?\n3. Does it conflict with existing code?\n4. What's missing?\n5. Final verdict: GREEN (approve) / YELLOW (needs changes) / RED (block)\n\nRespond in format:\nVERDICT: [GREEN/YELLOW/RED]\nREASON: [explanation]\nISSUES: [list]\nRECOMMENDATION: [what to do]`;
}

async function runMistral(prompt) {
  // Return structured result: { success, provider, text, error? }
  // Priority: if GEMINI_API_KEY is present, try calling the local Python runner
  if (GEMINI_API_KEY) {
    try {
      const { spawn } = require('child_process');
      const candidates = [process.env.PYTHON_PATH, 'python', 'python3', 'py'].filter(Boolean);
      let lastErr = null;
      for (const py of candidates) {
        try {
          const proc = spawn(py, ['gemini_run_prompt.py'], { cwd: __dirname, stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true });
          const chunks = [];
          const errChunks = [];
          proc.stdout.on('data', c => chunks.push(c));
          proc.stderr.on('data', c => errChunks.push(c));

          // send prompt via stdin to avoid CLI-escaping issues
          proc.stdin.write(prompt);
          proc.stdin.end();

          const out = await new Promise((resolve, reject) => {
            proc.on('error', e => reject(e));
            proc.on('close', (code) => {
              const stdout = Buffer.concat(chunks).toString('utf8');
              const stderr = Buffer.concat(errChunks).toString('utf8');
              if (code !== 0) return reject(new Error(`exit=${code} ${stderr}`));
              resolve(stdout);
            });
          });

          if (out && out.trim()) {
            llmCallCount += 1;
            llmProviderCounts['gemini'] = (llmProviderCounts['gemini'] || 0) + 1;
            return { success: true, provider: 'gemini', text: out.trim() };
          }
        } catch (e) {
          lastErr = e;
          // try next candidate
        }
      }
      if (lastErr) throw lastErr;
    } catch (err) {
      // Provide a more helpful message when common Python errors occur
      let extra = '';
      try {
        const msg = (err && err.message) ? err.message : '';
        if (msg.includes("ModuleNotFoundError") || msg.toLowerCase().includes('no module named')) {
          extra = ' (python dependency missing: try `pip install python-dotenv google-genai` or run `pip install -r backend/requirements.txt`)';
        } else if (msg.toLowerCase().includes('spawn') || msg.toLowerCase().includes('enoent')) {
          extra = ' (python interpreter not found: ensure `python` is on PATH or set PYTHON_PATH env to your python executable)';
        } else if (msg.toLowerCase().includes('exit=')) {
          extra = ` (python runner exited with error: ${msg.substring(0,200)})`;
        }
      } catch (e) {}
      console.warn('Gemini python runner failed, falling back to Ollama. Error:', (err && err.message) ? err.message + extra : String(err));
      // fall through to Ollama
    }
  }

  try {
    const resp = await axios.post(OLLAMA_API, {
      model: 'mistral',
      prompt,
      stream: false
    }, { timeout: 120000 });

    const text = resp?.data?.response || resp?.data || JSON.stringify(resp.data);
    llmCallCount += 1;
    llmProviderCounts['ollama'] = (llmProviderCounts['ollama'] || 0) + 1;
    return { success: true, provider: 'ollama', text };
  } catch (err) {
    console.warn('Ollama call failed, returning mock analysis. Error:', err.message);
    const mock = `VERDICT: YELLOW\nREASON: Could not contact Ollama or Gemini; returning mock analysis.\nISSUES: []\nRECOMMENDATION: Run analysis locally.`;
    llmCallCount += 1;
    llmProviderCounts['mock'] = (llmProviderCounts['mock'] || 0) + 1;
    return { success: false, provider: 'mock', text: mock, error: err.message };
  }
}

function parseVerdict(analysis) {
  const a = (analysis || '').toUpperCase();
  if (a.includes('VERDICT: GREEN') || a.includes('GREEN')) return 'GREEN';
  if (a.includes('VERDICT: YELLOW') || a.includes('YELLOW')) return 'YELLOW';
  return 'RED';
}

function generateComments(analysis) {
  return [
    { path: 'src/example.js', line: 12, comment: 'Example comment from analysis.' }
  ];
}

function parseIssuesFromAnalysis(analysis) {
  try {
    const m = (analysis || '').match(/ISSUES:\s*\[(.*)\]/i);
    if (m && m[1]) {
      // split on commas, trimming whitespace and quotes
      return m[1].split(/,\s*/).map(s => s.replace(/^\s*['\"]?|['\"]?\s*$/g, '').trim()).filter(Boolean);
    }
    // fallback: lines starting with '-'
    const lines = (analysis || '').split('\n').map(l=>l.trim()).filter(Boolean);
    const issues = lines.filter(l=>l.startsWith('-') || l.toLowerCase().startsWith('issue')).map(l=>l.replace(/^[-\d\.\)\s]+/,'').trim());
    return issues;
  } catch (e) {
    let extra = '';
    if (err && err.code === 'ECONNREFUSED' || (err.message || '').toLowerCase().includes('econnrefused')) {
      extra = ' (connection refused — is Ollama running locally? Start Ollama or set OLLAMA_API env to a reachable host)';
    }
    console.warn('Ollama call failed, returning mock analysis. Error:', err.message + extra);
  }
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`PRAssist backend running on http://localhost:${PORT}`);
  console.log(`OLLAMA_API=${OLLAMA_API}`);
});


