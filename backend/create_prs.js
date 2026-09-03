require('dotenv').config();
const axios = require('axios');
const b64 = (s) => Buffer.from(s, 'utf8').toString('base64');

const REPO = process.env.TEST_REPO || 'Nike-Anand/demo-code-review-mtgd0f2d';
const [owner, repo] = REPO.split('/');
const GITHUB_API = process.env.GITHUB_API_URL || 'https://api.github.com';
const TOKEN = process.env.GITHUB_TOKEN;

if (!TOKEN) {
  console.error('GITHUB_TOKEN not set in env. Cannot create PRs.');
  process.exit(2);
}

const headers = { Authorization: `token ${TOKEN}`, Accept: 'application/vnd.github.v3+json', 'User-Agent': 'pRAssist-script' };

async function getDefaultBranch() {
  const r = await axios.get(`${GITHUB_API}/repos/${owner}/${repo}`, { headers });
  return r.data.default_branch;
}

async function getRef(branch) {
  const r = await axios.get(`${GITHUB_API}/repos/${owner}/${repo}/git/refs/heads/${branch}`, { headers });
  return r.data.object.sha;
}

async function createRef(newBranch, sha) {
  const r = await axios.post(`${GITHUB_API}/repos/${owner}/${repo}/git/refs`, { ref: `refs/heads/${newBranch}`, sha }, { headers });
  return r.data;
}

async function createFile(path, content, branch, message) {
  const url = `${GITHUB_API}/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}`;
  const body = { message, content: b64(content), branch };
  const r = await axios.put(url, body, { headers });
  return r.data;
}

async function createPR(title, head, base, body) {
  const r = await axios.post(`${GITHUB_API}/repos/${owner}/${repo}/pulls`, { title, head, base, body }, { headers });
  return r.data;
}

function nowTs() { return new Date().toISOString(); }

(async ()=>{
  try {
    const base = await getDefaultBranch();
    console.log('Default branch:', base);

    const prs = [
      { tag: 'RED', title: 'CRITICAL: RED - security fix required', file: 'pr_red_1.txt', body: 'This PR introduces a critical security fix. Severity: CRITICAL. ' + nowTs() },
      { tag: 'RED', title: 'CRITICAL: RED - block on failing tests', file: 'pr_red_2.txt', body: 'This PR intentionally breaks tests and needs urgent attention. Severity: CRITICAL. ' + nowTs() },
      { tag: 'YELLOW', title: 'YELLOW: Needs changes - minor refactor', file: 'pr_yellow_1.txt', body: 'This PR suggests a refactor with potential minor behavioral changes. Severity: MINOR. ' + nowTs() },
      { tag: 'YELLOW', title: 'YELLOW: Needs changes - style updates', file: 'pr_yellow_2.txt', body: 'This PR updates formatting and style; review for consistency. Severity: MINOR. ' + nowTs() },
      { tag: 'GREEN', title: 'GREEN: Approve - small doc update', file: 'pr_green_1.txt', body: 'This PR updates documentation and is safe to approve. Severity: NONE. ' + nowTs() },
      { tag: 'GREEN', title: 'GREEN: Approve - typo fix', file: 'pr_green_2.txt', body: 'This PR fixes a typo in README; safe to merge. Severity: NONE. ' + nowTs() },
    ];

    for (const p of prs) {
      const branch = `pRAssist/demo-${p.tag.toLowerCase()}-${Math.random().toString(36).slice(2,8)}`;
      console.log('\nCreating branch', branch);
      const baseSha = await getRef(base);
      await createRef(branch, baseSha);
      console.log('Created branch', branch);

      const filePath = `pRAssist_prs/${p.file}`;
      const content = `${p.title}\n\n${p.body}\n\nCreated by pRAssist script.`;
      await createFile(filePath, content, branch, `pRAssist: create ${p.file}`);
      console.log('Created file', filePath, 'on', branch);

      const pr = await createPR(p.title, branch, base, `${p.body}\n\nTag: ${p.tag}`);
      console.log('Created PR:', pr.html_url);
    }

    console.log('\nAll PRs created');
  } catch (e) {
    console.error('Error creating PRs:', e.response ? (e.response.status + ' ' + JSON.stringify(e.response.data)) : e.message);
    process.exit(1);
  }
})();
