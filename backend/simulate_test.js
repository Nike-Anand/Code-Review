const axios = require('axios');
require('dotenv').config();

const PORT = process.env.PORT || 3000;
const BASE = process.env.BASE_URL || `http://localhost:${PORT}`;

async function run() {
  console.log('Simulation test starting against', BASE);

  try {
    const h = await axios.get(`${BASE}/health`, { timeout: 5000 });
    console.log('Health:', h.data);
  } catch (e) {
    console.error('Health check failed:', e.message);
    return;
  }

  // 1) Register a dummy notification endpoint (will likely be unreachable - tests removal logic)
  const dummyCallback = 'http://localhost:9999/callback';
  try {
    const r = await axios.post(`${BASE}/notify/register`, { url: dummyCallback }, { timeout: 5000 });
    console.log('Register callback:', r.data);
  } catch (e) {
    console.warn('Register failed:', e.response ? e.response.data : e.message);
  }

  // 2) Run an analyze PR flow using a mock GitLab MR URL (backend will use fetchPRFromGitLab if token present, otherwise mock)
  const testMR = process.env.TEST_MR || 'https://gitlab.com/example/project/-/merge_requests/1';
  try {
    const r = await axios.post(`${BASE}/api/analyze-pr`, { pr_link: testMR }, { timeout: 120000 });
    console.log('Analyze PR response:', {
      verdict: r.data.verdict,
      provider: r.data.provider,
      pr_id: r.data.pr_id,
    });
  } catch (e) {
    console.error('Analyze PR failed:', e.response ? e.response.data : e.message);
  }

  // 3) Send a GitLab webhook event (will trigger notifyPhone)
  try {
    const payload = { object_kind: 'merge_request', object_attributes: { id: 1, title: 'Simulated MR', url: testMR } };
    const r = await axios.post(`${BASE}/webhooks/gitlab`, payload, { headers: { 'X-Gitlab-Token': process.env.GITLAB_WEBHOOK_SECRET || '' }, timeout: 10000 });
    console.log('GitLab webhook response:', r.status, r.data);
  } catch (e) {
    console.error('GitLab webhook failed:', e.response ? `${e.response.status} ${JSON.stringify(e.response.data)}` : e.message);
  }

  // 4) Optionally attempt approve/merge (skip by default). To enable set RUN_APPROVE=1 in your env.
  if (process.env.RUN_APPROVE === '1') {
    try {
      const r = await axios.post(`${BASE}/api/approve-pr`, { pr_link: testMR }, { timeout: 30000 });
      console.log('Approve response:', r.data);
    } catch (e) {
      console.error('Approve PR failed (this may require valid tokens/permissions):', e.response ? e.response.data : e.message);
    }
  } else {
    console.log('Skipping approve/merge step (set RUN_APPROVE=1 to enable)');
  }

  // 5) Unregister the dummy callback
  try {
    const r = await axios.post(`${BASE}/notify/unregister`, { url: dummyCallback }, { timeout: 5000 });
    console.log('Unregister callback:', r.data);
  } catch (e) {
    console.warn('Unregister failed:', e.response ? e.response.data : e.message);
  }

  console.log('Simulation test complete');
}

run().catch((e) => {
  console.error('Simulation script error:', e);
  process.exit(1);
});
