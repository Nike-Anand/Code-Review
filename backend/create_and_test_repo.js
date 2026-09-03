const axios = require('axios');
require('dotenv').config();

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const BASE = process.env.BASE_URL || 'http://localhost:3000';

if (!GITHUB_TOKEN) {
  console.error('GITHUB_TOKEN not set in environment. Aborting.');
  process.exit(1);
}

const api = axios.create({
  baseURL: 'https://api.github.com',
  headers: { Authorization: `token ${GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' },
  timeout: 60000
});

async function sleep(ms){return new Promise(r=>setTimeout(r,ms));}

async function run(){
  console.log('Create-and-test flow starting');
  const me = (await api.get('/user')).data.login;
  console.log('Authenticated as', me);

  const repoName = `pr-test-sim-${Date.now().toString(36)}`;
  console.log('Creating repo', repoName);
  try{
    await api.post('/user/repos', { name: repoName, auto_init: true, private: true });
  }catch(e){
    console.error('Repo creation failed:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
    process.exit(1);
  }

  // wait for repo
  for(let i=0;i<10;i++){
    try{
      await sleep(1000);
      const r = await api.get(`/repos/${me}/${repoName}`);
      if(r && r.data) break;
    }catch(e){process.stdout.write('.');}
  }

  const repo = (await api.get(`/repos/${me}/${repoName}`)).data;
  const defaultBranch = repo.default_branch || 'main';
  console.log('Repo created with default branch', defaultBranch);

  // create a branch
  const refResp = await api.get(`/repos/${me}/${repoName}/git/ref/heads/${defaultBranch}`);
  const baseSha = refResp.data.object.sha;
  const branch = `sim-branch-${Date.now().toString(36)}`;
  await api.post(`/repos/${me}/${repoName}/git/refs`, { ref: `refs/heads/${branch}`, sha: baseSha });
  console.log('Created branch', branch);

  // add a file
  const filePath = 'SIMULATED_CHANGE.md';
  const content = `Automated simulation change\n\nTimestamp: ${new Date().toISOString()}`;
  await api.put(`/repos/${me}/${repoName}/contents/${encodeURIComponent(filePath)}`, { message: 'Add simulated change', content: Buffer.from(content).toString('base64'), branch });
  console.log('Committed file to branch');

  // create PR
  const prResp = await api.post(`/repos/${me}/${repoName}/pulls`, { title: 'Simulation PR', head: `${me}:${branch}`, base: defaultBranch, body: 'Automated PR for backend analysis test' });
  const pr = prResp.data;
  console.log('Created PR:', pr.html_url);

  // call backend analyze
  try{
    const analyze = await axios.post(`${BASE}/api/analyze-pr`, { pr_link: pr.html_url }, { timeout: 120000 });
    console.log('Analyze result:', analyze.data.verdict, 'provider:', analyze.data.provider);
  }catch(e){
    console.error('Analyze call failed:', e.response ? e.response.data : e.message);
  }

  // call backend approve (will attempt approval and merge)
  try{
    const approve = await axios.post(`${BASE}/api/approve-pr`, { pr_link: pr.html_url }, { timeout: 60000 });
    console.log('Approve result:', approve.data);
  }catch(e){
    console.error('Approve call failed (may need permissions):', e.response ? e.response.data : e.message);
  }

  console.log('Create-and-test flow complete');
}

run().catch(e=>{ console.error('Script error:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message); process.exit(1); });
