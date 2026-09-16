import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../worker.mjs';

test('Worker serves explicit HTML paths and maps root without exposing private files', async () => {
  const paths = [];
  const env = { ASSETS: { async fetch(request) {
    paths.push(new URL(request.url).pathname);
    return new Response('asset');
  } } };
  for (const [path, asset] of [['/', '/index.html'], ['/index.html', '/index.html'], ['/element-feedback/demo.html', '/element-feedback/demo.html']]) {
    const response = await worker.fetch(new Request(`http://localhost${path}`), env);
    assert.equal(response.status, 200);
    assert.equal(paths.at(-1), asset);
  }
  const before = paths.length;
  assert.equal((await worker.fetch(new Request('http://localhost/.data/comments.sqlite'), env)).status, 404);
  assert.equal(paths.length, before);
});
