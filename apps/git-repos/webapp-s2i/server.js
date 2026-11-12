const http = require('http');
const fs = require('fs');
const path = require('path');
const ms = require('ms');

const read = (f, d) => { try { return fs.readFileSync(path.join(__dirname, f), 'utf8').trim(); } catch (e) { return d; } };
const branch = read('BRANCH', 'unknown');
const buildInfo = read('build-info.txt', '');
const message = process.env.APP_MESSAGE || 'hello';

http.createServer((req, res) => {
  if (req.url === '/healthz') { res.writeHead(200); return res.end('ok\n'); }
  if (req.url === '/build-info') { res.writeHead(200); return res.end((buildInfo || 'none') + '\n'); }
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ app: 'webapp', branch, message, uptime: ms(Math.round(process.uptime() * 1000)) }) + '\n');
}).listen(process.env.PORT || 8080, () => console.log('webapp listening on ' + (process.env.PORT || 8080)));
