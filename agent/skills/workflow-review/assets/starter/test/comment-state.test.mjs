import test from 'node:test';
import assert from 'node:assert/strict';
import { archivedComments } from '../public/comment-state.js';

test('comments on gaps with a removed source flow remain visible in history', () => {
  const comments = [
    { id: 'orphan', targetType: 'gap', targetId: 'handoff-from-removed-flow', doneReason: '確認完了', doneAt: '2026-01-01T00:00:00.000Z' },
    { id: 'visible', targetType: 'gap', targetId: 'rendered-handoff' },
    { id: 'element', targetType: 'element', targetId: 'html-node' }
  ];
  const result = archivedComments(comments, ['flow:remaining-flow', 'gap:rendered-handoff']);
  assert.deepEqual(result.map(comment => comment.id), ['orphan']);
  assert.equal(result[0].doneAt, comments[0].doneAt);
  assert.equal(result[0].doneReason, '確認完了');
});
