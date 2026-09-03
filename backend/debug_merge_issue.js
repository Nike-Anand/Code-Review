const axios = require('axios');
require('dotenv').config();

const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
if (!GITHUB_TOKEN) {
  console.error('GITHUB_TOKEN not set');
  process.exit(1);
}

const api = axios.create({ baseURL: 'https://api.github.com', headers: { Authorization: `token ${GITHUB_TOKEN}`, Accept: 'application/vnd.github.v3+json' }, timeout: 60000 });

async function run() {
  const owner = 'Nike-Anand';
  const repo = 'pr-test-sim-mtgchl28';
  const number = 1;

  try {
    const pr = (await api.get(`/repos/${owner}/${repo}/pulls/${number}`)).data;
    console.log('PR info:');
    console.log({ number: pr.number, title: pr.title, user: pr.user.login, state: pr.state, merged: pr.merged, mergeable: pr.mergeable, mergeable_state: pr.mergeable_state, draft: pr.draft });
  } catch (e) {
    console.error('Failed to fetch PR:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
  }

  try {
    console.log('\nAttempting to submit APPROVE review...');
    const r = await api.post(`/repos/${owner}/${repo}/pulls/${number}/reviews`, { event: 'APPROVE' });
    console.log('Approve response:', r.status, r.data);
  } catch (e) {
    console.error('Approve failed:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
  }

  try {
    console.log('\nAttempting to merge PR...');
    const r = await api.put(`/repos/${owner}/${repo}/pulls/${number}/merge`, { commit_title: 'Merging via test script' });
    console.log('Merge response:', r.status, r.data);
  } catch (e) {
    console.error('Merge failed:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
  }

  try {
    console.log('\nChecking branch protection for default branch...');
    const repoInfo = (await api.get(`/repos/${owner}/${repo}`)).data;
    const branch = repoInfo.default_branch || 'main';
    try {
      const bp = await api.get(`/repos/${owner}/${repo}/branches/${branch}/protection`);
      console.log('Branch protection:', JSON.stringify(bp.data, null, 2));
    } catch (err) {
      console.error('Branch protection fetch failed:', err.response ? `${err.response.status} ${JSON.stringify(err.response.data)}` : err.message);
    }
  } catch (e) {
    console.error('Failed to get repo info:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
  }
}

run().catch(e => { console.error('Script error', e); process.exit(1); });
