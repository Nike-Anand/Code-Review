const axios = require('axios');
require('dotenv').config();

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const BASE = process.env.BASE_URL || 'http://localhost:3000';

if (!GITHUB_TOKEN) {
  console.error('GITHUB_TOKEN not set');
  process.exit(1);
}

const api = axios.create({ baseURL: 'https://api.github.com', headers: { Authorization: `token ${GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' }, timeout: 60000 });

async function sleep(ms){return new Promise(r=>setTimeout(r,ms));}

async function createRepo(name){
  try{
    const r = await api.post('/user/repos', { name, description: 'Demo project for PR analysis tests', auto_init: false, private: true });
    return r.data;
  }catch(e){
    console.error('Create repo failed:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
    throw e;
  }
}

async function addFile(owner, repo, path, content, branch, message){
  const encoded = Buffer.from(content).toString('base64');
  // check if file exists on the target branch to decide create vs update
  try{
    const existing = await api.get(`/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}?ref=${branch}`);
    const sha = existing.data.sha;
    return api.put(`/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}`, { message, content: encoded, branch, sha });
  }catch(e){
    // if not found, create new
    if (e.response && e.response.status === 404) {
      return api.put(`/repos/${owner}/${repo}/contents/${encodeURIComponent(path)}`, { message, content: encoded, branch });
    }
    throw e;
  }
}

async function createBranch(owner, repo, base, branch){
  const ref = await api.get(`/repos/${owner}/${repo}/git/ref/heads/${base}`);
  const sha = ref.data.object.sha;
  await api.post(`/repos/${owner}/${repo}/git/refs`, { ref: `refs/heads/${branch}`, sha });
}

async function createPR(owner, repo, head, base, title, body){
  const r = await api.post(`/repos/${owner}/${repo}/pulls`, { title, head, base, body });
  return r.data;
}

async function analyzePR(url){
  try{
    const r = await axios.post(`${BASE}/api/analyze-pr`, { pr_link: url }, { timeout: 120000 });
    return r.data;
  }catch(e){
    return { error: e.response ? e.response.data : e.message };
  }
}

async function run(){
  const me = (await api.get('/user')).data.login;
  const repoName = `demo-code-review-${Date.now().toString(36)}`;
  console.log('Creating demo repo', repoName, 'under', me);
  const repo = await createRepo(repoName);
  const owner = me;
  const defaultBranch = 'main';

  // create initial commit by adding README and package.json on main
  // create main branch by creating files via PUT which creates branch implicitly
  await addFile(owner, repoName, 'README.md', `# Demo Code Review\n\nDemo project for automated PR analysis.`, defaultBranch, 'Add README');
  await addFile(owner, repoName, 'package.json', JSON.stringify({ name: repoName, version: '0.1.0', main: 'src/index.js' }, null, 2), defaultBranch, 'Add package.json');
  await addFile(owner, repoName, 'src/index.js', `function add(a,b){return a+b;}\nmodule.exports = { add };`, defaultBranch, 'Add src/index.js');
  console.log('Initialized main branch with basic project');

  // create list of PR scenarios
  const scenarios = [
    {
      branch: 'bugfix-correct-add',
      title: 'BUGFIX: fix add behavior',
      change: { path: 'src/index.js', content: `function add(a,b){return Number(a)+Number(b);}\nmodule.exports = { add };` },
      body: 'Fixes addition when given numeric strings.'
    },
    {
      branch: 'style-whitespace',
      title: 'STYLE: whitespace only',
      change: { path: 'src/index.js', content: `function add(a,b){ return a + b; }\nmodule.exports = { add };` },
      body: 'Formatting change only.'
    },
    {
      branch: 'risky-change',
      title: 'FEATURE: change add to subtract (experimental)',
      change: { path: 'src/index.js', content: `function add(a,b){return a-b;}\nmodule.exports = { add };` },
      body: 'Introduces breaking change that subtracts instead of adding.'
    },
    {
      branch: 'docs-update',
      title: 'DOCS: update README',
      change: { path: 'README.md', content: `# Demo Code Review\n\nThis is a demo project for PR analysis. Updated docs.` },
      body: 'Docs only change.'
    }
  ];

  const results = [];
  for (const s of scenarios){
    console.log('\n--- Creating scenario', s.title);
    // create branch
    await createBranch(owner, repoName, defaultBranch, s.branch);
    // commit change
    await addFile(owner, repoName, s.change.path, s.change.content, s.branch, `Apply scenario: ${s.title}`);
    // create PR
    const pr = await createPR(owner, repoName, `${owner}:${s.branch}`, defaultBranch, s.title, s.body);
    console.log('PR created:', pr.html_url);
    // wait a short moment for GitHub to settle
    await sleep(1500);
    // analyze
    const analysis = await analyzePR(pr.html_url);
    console.log('Analysis result:', analysis.verdict || analysis.error || analysis);
    results.push({ pr: pr.html_url, title: s.title, analysis });
  }

  console.log('\nAll scenarios complete. Summary:');
  for (const r of results) console.log(r.title, '->', r.analysis.verdict || r.analysis.error);
}

run().catch(e=>{ console.error('Demo script error:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message); process.exit(1); });
