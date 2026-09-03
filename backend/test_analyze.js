const http = require('http');
const data = JSON.stringify({ pr_link: 'http://example.com/mock/pr/123' });
const opts = { hostname: 'localhost', port: 3000, path: '/api/analyze-pr', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } };
const req = http.request(opts, res => { let s = ''; res.on('data', c => s += c); res.on('end', () => { console.log(s); }); });
req.on('error', e => console.error(e));
req.write(data);
req.end();
