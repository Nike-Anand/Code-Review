const axios = require('axios');
const crypto = require('crypto');
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

const upstreamOwner = 'Nike-Anand';
const upstreamRepo = 'Code-Review';

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function run() {
  console.log('Starting GitHub PR creation flow...');

  // whoami
  const me = (await api.get('/user')).data.login;
  console.log('Authenticated as', me);

  // ensure fork exists
  let forkExists = false;
  try {
    await api.get(`/repos/${me}/${upstreamRepo}`);
    forkExists = true;
    console.log('Fork already exists:', `${me}/${upstreamRepo}`);
  } catch (e) {
    console.log('Fork not found, creating fork...');
    try {
      await api.post(`/repos/${upstreamOwner}/${upstreamRepo}/forks`);
    } catch (err) {
      console.error('Fork creation request failed:', err.response ? `${err.response.status} ${JSON.stringify(err.response.data)}` : err.message);
      throw err;
    }
    // wait for fork to be provisioned
    for (let i = 0; i < 12; i++) {
      try {
        await sleep(2000);
        await api.get(`/repos/${me}/${upstreamRepo}`);
        forkExists = true;
        console.log('Fork is ready');
        break;
      } catch (err) {
        process.stdout.write('.');
      }
    }
    if (!forkExists) throw new Error('Timed out waiting for fork to be created');
  }

  // get default branch of upstream
  const upstream = (await api.get(`/repos/${upstreamOwner}/${upstreamRepo}`)).data;
  const defaultBranch = upstream.default_branch || 'main';
  console.log('Upstream default branch:', defaultBranch);

  // get base sha from fork's default branch
  let baseSha;
  try {
    const refResp = await api.get(`/repos/${me}/${upstreamRepo}/git/ref/heads/${defaultBranch}`);
    baseSha = refResp.data.object.sha;
  } catch (err) {
    console.error('Failed to read ref from fork:', err.response ? `${err.response.status} ${JSON.stringify(err.response.data)}` : err.message);
    throw err;
  }

  const branchName = `pr-sim-${Date.now().toString(36)}`;
  // create new branch ref
  try {
    await api.post(`/repos/${me}/${upstreamRepo}/git/refs`, { ref: `refs/heads/${branchName}`, sha: baseSha });
    console.log('Created branch', branchName);
  } catch (err) {
    console.error('Failed to create branch ref:', err.response ? `${err.response.status} ${JSON.stringify(err.response.data)}` : err.message);
    throw err;
  }

  // create a small change: a new file
  const filePath = `simulated-change-${Date.now()}.md`;
  const content = `Simulation generated change at ${new Date().toISOString()}\n\nThis file is created by an automated test.`;
  const message = 'Simulated change for PR analysis test';
  const encoded = Buffer.from(content).toString('base64');
  try {
    await api.put(`/repos/${me}/${upstreamRepo}/contents/${encodeURIComponent(filePath)}`, {
      message,
      content: encoded,
      branch: branchName
    });
    console.log('Created file', filePath, 'on branch', branchName);
  } catch (err) {
    console.error('Failed to create file in branch:', err.response ? `${err.response.status} ${JSON.stringify(err.response.data)}` : err.message);
    throw err;
  }

  // create PR against upstream
  const prTitle = 'Simulated PR: automated test';
  const prBody = 'This PR was created by an automated simulation test to exercise the backend analysis flow.';
  let pr;
  try {
    const prResp = await api.post(`/repos/${upstreamOwner}/${upstreamRepo}/pulls`, {
      title: prTitle,
      head: `${me}:${branchName}`,
      base: defaultBranch,
      body: prBody
    });
    pr = prResp.data;
    console.log('Created PR:', pr.html_url);
  } catch (err) {
    console.error('Failed to create PR:', err.response ? `${err.response.status} ${JSON.stringify(err.response.data)}` : err.message);
    throw err;
  }

  // call backend analyze endpoint with the PR URL
  try {
    const analyzeResp = await axios.post(`${BASE}/api/analyze-pr`, { pr_link: pr.html_url }, { timeout: 120000 });
    console.log('Backend analysis result:');
    console.log(JSON.stringify(analyzeResp.data, null, 2));
  } catch (e) {
    console.error('Backend analyze call failed:', e.response ? e.response.data : e.message);
  }

  console.log('GitHub PR simulation complete.');
}

run().catch(e => {
  console.error('Simulation script error:', e.message || e);
  process.exit(1);
});
