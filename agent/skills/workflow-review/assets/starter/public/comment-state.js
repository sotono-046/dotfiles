// Visible DOM target keys are authoritative: a manifest gap may reference a removed flow.
export function archivedComments(comments, renderedTargetKeys) {
  const rendered = new Set(renderedTargetKeys);
  return comments.filter(comment => comment.targetType !== 'element' && !rendered.has(`${comment.targetType}:${comment.targetId}`));
}
