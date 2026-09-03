require('dotenv').config();
const axios = require('axios');

const REPO = process.env.TEST_REPO || 'Nike-Anand/demo-code-review-mtgd0f2d';
const [owner, repo] = REPO.split('/');
const GITHUB_API = process.env.GITHUB_API_URL || 'https://api.github.com';
const BASE = process.env.BASE_URL || 'http://localhost:3000';
const TOKEN = process.env.GITHUB_TOKEN;

if (!TOKEN) {
  console.error('GITHUB_TOKEN not set in env. Cannot create PRs.');
  process.exit(2);
}

const api = axios.create({
  baseURL: GITHUB_API,
  headers: { Authorization: `token ${TOKEN}`, Accept: 'application/vnd.github.v3+json', 'User-Agent': 'pRAssist-script' },
  timeout: 60000,
});
const b64 = (s) => Buffer.from(s, 'utf8').toString('base64');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function nowTs() { return new Date().toISOString(); }

async function getDefaultBranch() {
  const r = await api.get(`/repos/${owner}/${repo}`);
  return r.data.default_branch;
}

async function getHeadSha(branch) {
  const r = await api.get(`/repos/${owner}/${repo}/git/refs/heads/${branch}`);
  return r.data.object.sha;
}

async function createBranch(branch, sha) {
  const r = await api.post(`/repos/${owner}/${repo}/git/refs`, { ref: `refs/heads/${branch}`, sha });
  return r.data;
}

async function getFileSha(path, branch) {
  try {
    const r = await api.get(`/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}?ref=${branch}`);
    return r.data.sha;
  } catch (e) {
    if (e.response && e.response.status === 404) return null;
    throw e;
  }
}

async function writeFile(path, content, branch, message) {
  const sha = await getFileSha(path, branch);
  const body = { message, content: b64(content), branch };
  if (sha) body.sha = sha; // update existing file, otherwise create new
  const r = await api.put(`/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}`, body);
  return r.data;
}

async function createPR(title, head, base, body) {
  const r = await api.post(`/repos/${owner}/${repo}/pulls`, { title, head, base, body });
  return r.data;
}

async function analyzePR(url) {
  try {
    const r = await axios.post(`${BASE}/api/analyze-pr`, { pr_link: url }, { timeout: 180000 });
    return r.data;
  } catch (e) {
    return { error: e.response ? e.response.data : e.message };
  }
}// -------------------------------------------------------------------
// The three scenarios. Each makes real source changes on top of the
// repo's current default branch:
//   GREEN  - clean, validated, tested utility -> APPROVE
//   YELLOW - feature with minor flaws (no validation / no tests)
//   RED    - security-critical code (hardcoded secret)
// -------------------------------------------------------------------

const GREEN_GREET_JS = "/**\n * Format a user name for display.\n * @param {string} name - The user's name.\n * @returns {string} A capitalized name, or 'Unknown' for empty/null input.\n */\nfunction formatName(name) {\n  const trimmed = String(name || '').trim();\n  if (!trimmed) return 'Unknown';\n  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1).toLowerCase();\n}\n\nmodule.exports = { formatName };\n";

const GREEN_TEST_JS = "const assert = require('assert');\nconst { formatName } = require('../src/greet');\n\nassert.strictEqual(formatName('alice'), 'Alice');\nassert.strictEqual(formatName('  Bob  '), 'Bob');\nassert.strictEqual(formatName(''), 'Unknown');\nassert.strictEqual(formatName(null), 'Unknown');\nconsole.log('All greet tests passed');\n";

const YELLOW_COUNTWORDS_JS = '// Simple word counter - counts occurrences of each word in a text.\n// TODO: validate input, strip punctuation, skip empty tokens.\nfunction countWords(text) {\n  const counts = {};\n  const words = text.toLowerCase().split(/\\s+/);\n  for (const w of words) {\n    counts[w] = (counts[w] || 0) + 1;\n  }\n  return counts;\n}\n\nmodule.exports = { countWords };\n';

const RED_AUTHENTICATE_JS = "// Authenticates requests against the demo service API secret.\nconst API_SECRET = 'fake_secret_for_demo_purposes_only_123'; // hardcoded production secret!\n\nfunction authenticate(token) {\n  return token === API_SECRET; // timing-unsafe comparison\n}\n\nmodule.exports = { authenticate, API_SECRET };\n";

const scenarios = [
  {
    tag: 'GREEN',
    branch: `pRAssist/scenario-green-${Math.random().toString(36).slice(2, 8)}`,
    title: 'GREEN: add formatName util with validation and tests',
    body: [
      'Adds a small, well-documented name-formatting utility.',
      'Includes input validation (handles null/empty), lowercase normalization,',
      'and a full unit-test file covering the happy path and edge cases.',
      'Severity: NONE - safe, scoped change.',
      'Created at ' + nowTs(),
    ].join('\n'),
    files: {
      'src/greet.js': GREEN_GREET_JS,
      'test/greet.test.js': GREEN_TEST_JS,
    },
  },
  {
    tag: 'YELLOW',
    branch: `pRAssist/scenario-yellow-${Math.random().toString(36).slice(2, 8)}`,
    title: 'YELLOW: add countWords helper for text stats',
    body: [
      'Adds a word-counter helper used by the future reports page.',
      'NOTE: no input validation yet; may throw on null/undefined input.',
      'Also counts empty strings and does not strip punctuation.',
      'Severity: MINOR - functional but needs moderate refactor + tests.',
      'Created at ' + nowTs(),
    ].join('\n'),
    files: {
      'src/countWords.js': YELLOW_COUNTWORDS_JS,
    },
  },
  {
    tag: 'RED',
    branch: `pRAssist/scenario-red-${Math.random().toString(36).slice(2, 8)}`,
    title: 'RED: add authenticate helper with API secret',
    body: [
      'Adds authentication helper that compares a caller-supplied token against a',
      'secret API key used by the service.',
      'Severity: CRITICAL - hardcoded production credential, timing-unsafe comparison,',
      'secret exported from module.',
      'Created at ' + nowTs(),
    ].join('\n'),
    files: {
      'src/authenticate.js': RED_AUTHENTICATE_JS,
    },
  },
];

async function run() {
  try {
    const base = await getDefaultBranch();
    console.log('Default branch:', base);

    const results = [];
    for (const s of scenarios) {
      console.log('\n--- [' + s.tag + '] ' + s.title);
      const sha = await getHeadSha(base);
      const branch = s.branch;
      await createBranch(branch, sha);
      console.log('Created branch', branch);

      for (const [path, content] of Object.entries(s.files)) {
        await writeFile(path, content, branch, 'pRAssist: write ' + path + ' (' + s.tag + ')');
        console.log('Wrote', path, 'on', branch);
      }

      const pr = await createPR(s.title, branch, base, s.body);
      console.log('Created PR:', pr.html_url);
      results.push(pr);
      await sleep(2000);
    }

    console.log('\nAll PRs created:');
    for (const r of results) console.log('  ' + r.html_url);

    // Optionally auto-analyze each to verify the expected verdicts
    // (requires the backend server to be running)
    if (process.env.ANALYZE === '1') {
      for (const r of results) {
        const a = await analyzePR(r.html_url);
        console.log(r.number, r.html_url, '=>', a.verdict || a.error || a);
        await sleep(1000);
      }
    }
  } catch (e) {
    console.error('Error:', e.response ? (e.response.status + ' ' + JSON.stringify(e.response.data)) : e.message);
    process.exit(1);
  }
}

run();

