import http from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Readable } from 'node:stream';
import { openDatabase } from './sqlite.mjs';
import { handleApi } from '../shared/api.mjs';
const root = new URL('../', import.meta.url);
await mkdir(new URL('.data/',root), { recursive: true });
const db = openDatabase(fileURLToPath(new URL('.data/comments.sqlite',root)));
db.exec(await readFile(new URL('migrations/0001_comments.sql',root),'utf8'));
const assets = { '/': ['index.html','text/html'], '/index.html': ['index.html','text/html'], '/styles.css': ['styles.css','text/css'], '/app.js': ['app.js','text/javascript'], '/comment-state.js': ['comment-state.js','text/javascript'], '/flow-data.json': ['flow-data.json','application/json'] };
const port = Number(process.env.PORT || 4173);
const origin = `http://127.0.0.1:${port}`;
const server = http.createServer(async (req,res) => {
  try {
    if (req.headers.host !== `127.0.0.1:${port}` && req.headers.host !== `localhost:${port}`) { res.writeHead(403); res.end('Invalid host'); return; }
    const requestOrigin = `http://${req.headers.host}`;
    const url = new URL(req.url,requestOrigin);
    let response;
    if (url.pathname.startsWith('/api/')) {
      const data = JSON.parse(await readFile(new URL('public/flow-data.json',root),'utf8'));
      response = await handleApi(new Request(url,{ method:req.method,headers:req.headers,...(!['GET','HEAD'].includes(req.method) ? { body:Readable.toWeb(req),duplex:'half' } : {}) }),db,data);
    } else if (/^\/element-feedback\/[a-zA-Z0-9_-]+\.(?:html|mjs|js|css)$/.test(url.pathname) && req.method === 'GET') {
      const type = url.pathname.endsWith('.css') ? 'text/css' : url.pathname.endsWith('.html') ? 'text/html' : 'text/javascript';
      try { response = new Response(await readFile(new URL(`public${url.pathname}`,root)),{headers:{'content-type':`${type}; charset=utf-8`}}); }
      catch (error) { if (error.code === 'ENOENT') response = new Response('Not found',{status:404}); else throw error; }
    } else if (assets[url.pathname] && req.method === 'GET') {
      const [file,type] = assets[url.pathname];
      response = new Response(await readFile(new URL(`public/${file}`,root)),{ headers:{'content-type':`${type}; charset=utf-8`,'cache-control':'no-store'} });
    } else response = new Response('Not found',{status:404});
    res.writeHead(response.status,{...Object.fromEntries(response.headers),'x-content-type-options':'nosniff','referrer-policy':'same-origin'});
    res.end(Buffer.from(await response.arrayBuffer()));
  } catch (error) { console.error(error); res.writeHead(500); res.end('Server error'); }
});
server.listen(port,'127.0.0.1',()=>console.log(`Workflow review: ${origin}`));
for (const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>server.close(()=>{db.close();process.exit(0);}));
