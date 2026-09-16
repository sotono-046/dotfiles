// Shared by the local SQLite adapter and the Cloudflare D1 worker.
const json = (value, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' } });
const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };
const field = (value, name, max = 200) => {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(400, `${name}が不正です`);
  return value.trim();
};
const shape = row => ({ id: row.id, projectId: row.project_id, targetType: row.target_type, targetId: row.target_id, author: row.author, body: row.body, createdAt: row.created_at, doneReason: row.done_reason, doneAt: row.done_at });
const targetShape = row => ({ projectId: row.project_id, id: row.id, pagePath: row.page_path, selector: row.selector, textHint: row.text_hint, revision: row.revision, createdAt: row.created_at });
async function payload(request) {
  if (!request.headers.get('content-type')?.startsWith('application/json')) fail(415, 'JSON が必要です');
  const reader = request.body?.getReader();
  if (!reader) fail(400, '本文が必要です');
  let size = 0; const chunks = [];
  while (true) {
    const { done, value } = await reader.read(); if (done) break;
    size += value.byteLength;
    if (size > 16384) { await reader.cancel(); fail(413, '本文が大きすぎます'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { const value = JSON.parse(new TextDecoder().decode(bytes)); if (!value || typeof value !== 'object' || Array.isArray(value)) fail(400, 'JSON object が必要です'); return value; }
  catch { fail(400, 'JSON が不正です'); }
}
export async function handleApi(request, db, data) {
  try {
    const url = new URL(request.url);
    if (!['GET', 'POST'].includes(request.method)) return json({ error: '許可されていない操作です' }, 405);
    if (request.method === 'POST' && (request.headers.get('origin') !== url.origin || request.headers.get('sec-fetch-site') === 'cross-site')) fail(403, '同一オリジンから操作してください');
    const input = request.method === 'GET' ? Object.fromEntries(url.searchParams) : await payload(request);
    const projectId = field(input.projectId, 'projectId');
    if (projectId !== data.projectId) fail(404, 'プロジェクトがありません');
    if (url.pathname === '/api/targets') {
      if (request.method === 'GET') {
        const rows = await db.prepare('SELECT * FROM targets WHERE project_id = ? ORDER BY created_at,id').bind(projectId).all();
        return json({ targets: rows.results.map(targetShape) });
      }
      const id = field(input.id, 'id'); const pagePath = field(input.pagePath, 'pagePath', 1000);
      if (!pagePath.startsWith('/') || pagePath.startsWith('//')) fail(400, 'pagePath は相対パスが必要です');
      const selector = field(input.selector, 'selector', 2000);
      const textHint = typeof input.textHint === 'string' ? input.textHint.slice(0, 500) : '';
      const revision = field(input.revision, 'revision', 200);
      await db.prepare('INSERT OR IGNORE INTO targets(project_id,id,page_path,selector,text_hint,revision,created_at) VALUES(?,?,?,?,?,?,?)').bind(projectId,id,pagePath,selector,textHint,revision,new Date().toISOString()).run();
      return json({ target: targetShape(await db.prepare('SELECT * FROM targets WHERE project_id = ? AND id = ?').bind(projectId,id).first()) }, 201);
    }
    const doneMatch = url.pathname.match(/^\/api\/comments\/([^/]+)\/done$/);
    if (doneMatch && request.method === 'POST') {
      const reason = field(input.reason, '理由', 2000);
      const existing = await db.prepare('SELECT * FROM comments WHERE id = ? AND project_id = ?').bind(doneMatch[1],projectId).first();
      if (!existing) fail(404, 'コメントがありません');
      if (existing.done_at) fail(409, 'すでに Done です');
      const result = await db.prepare('UPDATE comments SET done_reason = ?, done_at = ? WHERE id = ? AND project_id = ? AND done_at IS NULL').bind(reason,new Date().toISOString(),doneMatch[1],projectId).run();
      if (!result.meta.changes) fail(409, 'すでに Done です');
      return json({ comment: shape(await db.prepare('SELECT * FROM comments WHERE id = ? AND project_id = ?').bind(doneMatch[1],projectId).first()) });
    }
    if (url.pathname === '/api/comments/history' && request.method === 'GET') {
      const rows = await db.prepare('SELECT * FROM comments WHERE project_id = ? ORDER BY created_at,id').bind(projectId).all();
      return json({ comments: rows.results.map(shape) });
    }
    if (url.pathname !== '/api/comments') fail(404, 'API がありません');
    const type = field(input.targetType, 'targetType'); const id = field(input.targetId, 'targetId');
    let exists = false;
    if (type === 'flow') exists = data.flows.some(flow => flow.id === id);
    if (type === 'step') exists = data.flows.some(flow => flow.rows.some(row => [row.before,row.after].some(step => step?.id === id)));
    if (type === 'gap') exists = (data.gaps || []).some(gap => gap.id === id) || data.flows.some(flow => (flow.gaps || []).some(gap => gap.id === id));
    if (type === 'element') exists = !!await db.prepare('SELECT id FROM targets WHERE project_id = ? AND id = ?').bind(projectId,id).first();
    if (!exists && request.method === 'GET') exists = !!await db.prepare('SELECT id FROM comments WHERE project_id = ? AND target_type = ? AND target_id = ? LIMIT 1').bind(projectId,type,id).first();
    if (!exists) fail(404, '対象がありません');
    if (request.method === 'GET') {
      const rows = await db.prepare('SELECT * FROM comments WHERE project_id = ? AND target_type = ? AND target_id = ? ORDER BY created_at,id').bind(projectId,type,id).all();
      return json({ comments: rows.results.map(shape) });
    }
    const author = field(input.author, '名前', 80); const body = field(input.body, 'コメント', 4000); const commentId = crypto.randomUUID();
    await db.prepare('INSERT INTO comments(id,project_id,target_type,target_id,author,body,created_at) VALUES(?,?,?,?,?,?,?)').bind(commentId,projectId,type,id,author,body,new Date().toISOString()).run();
    return json({ comment: shape(await db.prepare('SELECT * FROM comments WHERE id = ?').bind(commentId).first()) }, 201);
  } catch (error) { if (!error.status) console.error(error); return json({ error: error.status ? error.message : '保存に失敗しました' }, error.status || 500); }
}
