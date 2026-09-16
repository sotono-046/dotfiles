const PRIVATE = 'form,input,textarea,select,option,[contenteditable]:not([contenteditable="false"]),[data-feedback-private],[data-sensitive],script,style,noscript';
const HOST = '[data-element-feedback-host]';
const stableSelector = selector => selector.startsWith('#') || selector.startsWith('[data-feedback-id=');

export async function targetIdFor(projectId, metadata) {
  const identity = [projectId, metadata.pagePath, metadata.selector];
  if (!stableSelector(metadata.selector)) identity.push(metadata.textHint);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(identity)));
  return `element-${[...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('')}`;
}
const compact = value => value.replace(/\s+/g, ' ').trim().slice(0, 160);
const all = (selector, doc = document) => { try { return [...doc.querySelectorAll(selector)].filter(el => !el.closest(HOST)); } catch { return []; } };

/** Never reads form values. Mark application-specific private regions data-feedback-private. */
export function safeText(element) {
  if (element.closest(PRIVATE)) return '';
  const walker = element.ownerDocument.createTreeWalker(element, NodeFilter.SHOW_TEXT);
  let text = '', node;
  while ((node = walker.nextNode())) {
    if (!node.parentElement.closest(PRIVATE)) text += ` ${node.textContent}`;
    if (text.length > 640) break;
  }
  return compact(text);
}

export function describeElement(element, revision) {
  if (element.closest(PRIVATE) || element.closest(HOST)) throw new Error('この領域はコメント対象から除外されています。');
  const doc = element.ownerDocument;
  let selector;
  const feedbackId = element.getAttribute('data-feedback-id');
  if (feedbackId) {
    const candidate = `[data-feedback-id="${CSS.escape(feedbackId)}"]`;
    if (all(candidate, doc).length === 1) selector = candidate;
  }
  if (!selector && element.id) {
    const candidate = `#${CSS.escape(element.id)}`;
    if (all(candidate, doc).length === 1) selector = candidate;
  }
  if (!selector) {
    const parts = [];
    let current = element;
    while (current && current.nodeType === 1) {
      const tag = current.localName;
      const siblings = current.parentElement ? [...current.parentElement.children].filter(el => el.localName === tag) : [current];
      parts.unshift(`${tag}:nth-of-type(${siblings.indexOf(current) + 1})`);
      current = current.parentElement;
    }
    selector = parts.join(' > ');
  }
  return {pagePath: doc.location.pathname, selector, textHint: safeText(element), revision};
}

/** Structural paths are hints only: reattach solely with an unambiguous text fingerprint. */
export function locateTarget(target, doc = document) {
  if (target.pagePath !== doc.location.pathname) return {status: 'other-page', element: null};
  const matches = all(target.selector, doc);
  if (matches.some(element => element.closest(PRIVATE))) return {status: 'ambiguous', element: null};
  const stable = stableSelector(target.selector);
  if (stable) {
    if (!matches.length) return {status: 'missing', element: null};
    if (matches.length !== 1 || safeText(matches[0]) !== target.textHint) return {status: 'ambiguous', element: null};
    return {status: 'found', element: matches[0]};
  }
  if (!target.textHint) return {status: matches.length ? 'ambiguous' : 'missing', element: null};
  const tag = target.selector.split(' > ').at(-1).split(':')[0];
  const fingerprints = all(tag, doc).filter(el => safeText(el) === target.textHint);
  if (fingerprints.length === 1 && matches.length === 1 && matches[0] === fingerprints[0]) return {status: 'found', element: fingerprints[0]};
  return {status: fingerprints.length > 1 || matches.length ? 'ambiguous' : 'missing', element: null};
}

export function initElementFeedback({projectId, revision, apiBase = '/api', enabled = false} = {}) {
  if (!enabled) return {destroy() {}};
  if (!projectId || !revision) throw new Error('projectId and revision are required');
  if (document.querySelector(HOST)) throw new Error('Element feedback is already initialized');
  const base = new URL(apiBase.replace(/\/$/, '') + '/', location.href);
  if (base.origin !== location.origin) throw new Error('apiBase must be same-origin');
  const host = document.createElement('div');
  host.dataset.elementFeedbackHost = '';
  document.body.append(host);
  const shadow = host.attachShadow({mode: 'open'});
  shadow.innerHTML = `<style>
    :host{all:initial;font:16px/1.7 system-ui,sans-serif;color:#1a1a1c}
    *{box-sizing:border-box}button,input,textarea{font:inherit}button{cursor:pointer;border:1px solid #9cabba;background:white;border-radius:4px;padding:8px 16px;min-height:44px;color:#0017c1}button:disabled{opacity:.5;cursor:default}button:focus-visible,input:focus-visible,textarea:focus-visible{outline:3px solid #0017c1;outline-offset:2px}
    .launcher{position:fixed;right:16px;bottom:16px;z-index:2147483646;background:#0017c1;color:white;padding:8px 16px;box-shadow:0 2px 12px #0003}
    .panel{position:fixed;right:16px;bottom:72px;width:min(400px,calc(100vw - 32px));max-height:calc(100dvh - 96px);overflow:auto;background:#fff;border:1px solid #a5b4c1;border-radius:8px;box-shadow:0 8px 35px #0003;padding:16px;z-index:2147483646}
    [hidden]{display:none!important}h2{font-size:18px;margin:0}h3{font-size:16px;margin:16px 0 8px}p{margin:8px 0}.row{display:flex;align-items:center;gap:8px}.spread{justify-content:space-between}label{display:block;margin:8px 0 4px}input,textarea{display:block;width:100%;padding:8px;border:1px solid #a5b4c1;border-radius:4px;background:white;color:#172b3b}textarea{min-height:86px;resize:vertical}.muted{font-size:12px;color:#536777}.error{color:#a22222;white-space:pre-wrap}.target{display:block;text-align:left;width:100%;margin:8px 0;overflow-wrap:anywhere}.target[aria-current=true]{border:2px solid #0017c1}.comment{border-top:1px solid #dbe2e8;padding:8px 0}.body{white-space:pre-wrap;overflow-wrap:anywhere}.outline{position:fixed;pointer-events:none;border:2px solid #0017c1;background:#0017c118;z-index:2147483645}.tag{position:absolute;left:0;bottom:100%;background:#0017c1;color:white;font:12px system-ui;white-space:nowrap;padding:3px 6px;max-width:90vw;overflow:hidden}.reason{padding:8px;background:#f1f5f8;border-radius:4px}small{font-size:12px}
  </style>
  <div class="outline" hidden><span class="tag"></span></div>
  <button class="launcher" aria-expanded="false">要素にコメント</button>
  <section class="panel" aria-label="HTML要素へのコメント" hidden>
    <div class="row spread"><h2>要素へのコメント</h2><button class="close" aria-label="閉じる">×</button></div>
    <p class="muted">選択中はページ操作を止めます。要素をタップ、または Tab で移動して Enter。「要素を選択」ボタン上では ↑↓ で全要素を巡回し Enter。Esc で解除。iframe 内部・Shadow DOM 内部は非対応です。</p>
    <button class="inspect" aria-pressed="false">要素を選択</button>
    <p class="status" role="status" aria-live="polite"></p>
    <p class="error" role="alert"></p>
    <div class="row spread"><h3>登録済みの対象</h3><button class="reload">再読み込み</button></div><div class="targets"></div>
    <section class="detail" hidden><h3 class="selected-title"></h3><p class="selected-status muted"></p><div class="comments"></div>
      <label for="ef-author">名前（必須）</label><input id="ef-author" autocomplete="off" maxlength="80" placeholder="表示する名前">
      <button class="clear-author" type="button">名前を消去</button>
      <label for="ef-body">コメント</label><textarea id="ef-body" maxlength="4000" placeholder="コメントを入力してください"></textarea>
      <div class="row spread"><small class="muted">⌘ / Ctrl + Enter で送信</small><button class="send">送信</button></div>
    </section>
  </section>`;
  const q = selector => shadow.querySelector(selector);
  let inspecting = false, hovered = null, selected = null, targets = [], comments = [], pending = false, destroyed = false, refreshFrame;
  let targetsLoaded = false, commentsLoaded = false;
  let loadingToken = 0, swallowedTarget = null, swallowUntil = 0;
  const known = new WeakMap();
  const authorKey = `element-feedback:${projectId}:author`;
  try { q('#ef-author').value = localStorage.getItem(authorKey) || ''; } catch {}
  const setError = message => { q('.error').textContent = message; };
  async function request(path, data) {
    const url = new URL(path, base);
    const response = await fetch(url, {method: data ? 'POST' : 'GET', credentials: 'same-origin', headers: data ? {'Content-Type': 'application/json'} : {}, ...(data ? {body: JSON.stringify(data)} : {})});
    if (!response.ok) throw new Error(`保存・読み込みに失敗しました（${response.status}）。再試行できます。`);
    return response.json();
  }
  const query = extras => new URLSearchParams({projectId, ...extras}).toString();
  const labels = {'found': '対象を確認済み', 'missing': '対象が見つかりません', 'ambiguous': '要確認（対象を一意に確認できません）', 'other-page': '別ページの対象'};
  function outline(element) {
    const box = q('.outline');
    if (!element?.isConnected || element.closest(PRIVATE) || element.closest(HOST)) { box.hidden = true; return; }
    const rect = element.getBoundingClientRect();
    Object.assign(box.style, {left: `${rect.left}px`, top: `${rect.top}px`, width: `${rect.width}px`, height: `${rect.height}px`});
    q('.tag').textContent = element.localName;
    q('.tag').style.bottom = rect.top < 24 ? 'auto' : '100%';
    box.hidden = false;
  }
  function refresh() {
    if (destroyed) return;
    for (const button of q('.targets').children) {
      const target = targets.find(item => item.id === button.dataset.id);
      const result = locateTarget(target);
      button.textContent = `${target.textHint || target.selector} — ${labels[result.status]}`;
    }
    if (selected) {
      const result = locateTarget(selected);
      q('.selected-status').textContent = `${labels[result.status]} · ${selected.pagePath} · 記録時: ${selected.revision}${selected.revision !== revision ? "（現在のrevisionと異なります）" : ""}`;
      if (!inspecting) outline(q('.panel').hidden ? null : result.element);
    }
    if (inspecting) outline(hovered);
  }
  function renderTargets() {
    q('.targets').replaceChildren();
    for (const target of targets) {
      const button = document.createElement('button');
      button.className = 'target'; button.dataset.id = target.id;
      button.setAttribute('aria-current', String(target.id === selected?.id));
      button.onclick = () => openTarget(target);
      q('.targets').append(button);
    }
    if (!targets.length) q('.status').textContent = '要素を選択するとコメントを残せます。';
    refresh();
  }
  function setInspect(value) {
    inspecting = value; hovered = null;
    q('.inspect').setAttribute('aria-pressed', String(value));
    q('.inspect').textContent = value ? '選択を解除（Esc）' : '要素を選択';
    q('.status').textContent = value ? 'コメントしたい要素を選んでください。' : '';
    outline(null); refresh();
  }
  function renderComments() {
    const root = q('.comments'); root.replaceChildren();
    for (const comment of comments) {
      const item = document.createElement('article'); item.className = 'comment';
      const header = document.createElement('div'); header.className = 'row spread';
      const author = document.createElement('strong'); author.textContent = comment.author;
      const done = document.createElement('button');
      const isDone = Boolean(comment.done || comment.status === 'done' || comment.doneAt);
      done.textContent = isDone ? '✓ Done' : '✓'; done.setAttribute('aria-label', isDone ? 'Done済み' : 'Doneにする'); done.disabled = isDone;
      header.append(author, done);
      const body = document.createElement('p'); body.className = 'body'; body.textContent = comment.body;
      item.append(header, body);
      const timestamps = document.createElement('p'); timestamps.className = 'muted';
      const formatTime = value => { const date = new Date(value); return Number.isNaN(date.getTime()) ? '日時不明' : date.toLocaleString('ja-JP'); };
      timestamps.textContent = `投稿：${comment.createdAt ? formatTime(comment.createdAt) : '日時不明'}${comment.doneAt ? ` · Done：${formatTime(comment.doneAt)}` : ''}`;
      item.append(timestamps);
      if (isDone) { const reason = document.createElement('p'); reason.className = 'muted body'; reason.textContent = `理由：${comment.doneReason || ''}`; item.append(reason); }
      done.onclick = () => {
        if (item.querySelector('.reason')) return;
        const editor = document.createElement('div'); editor.className = 'reason';
        const row = document.createElement('div'); row.className = 'row spread';
        const label = document.createElement('label'); label.textContent = '理由';
        const close = document.createElement('button'); close.textContent = '×'; close.setAttribute('aria-label', '理由入力を閉じる');
        const input = document.createElement('textarea'); input.placeholder = '理由を書いてください'; input.maxLength = 2000; input.id = `ef-reason-${comment.id}`; label.htmlFor = input.id;
        const ok = document.createElement('button'); ok.textContent = 'OK'; ok.disabled = true;
        row.append(label, close); editor.append(row, input, ok); item.append(editor);
        close.onclick = () => { editor.remove(); done.focus(); };
        input.oninput = () => { ok.disabled = !input.value.trim(); };
        ok.onclick = async () => {
          if (ok.disabled) return;
          ok.disabled = true; input.disabled = true; close.disabled = true; setError('');
          try {
            const data = await request(`comments/${encodeURIComponent(comment.id)}/done`, {projectId, reason: input.value.trim()});
            Object.assign(comment, data.comment || data, {done: true, doneReason: input.value.trim()}); renderComments();
          } catch (error) { setError(error.message); ok.disabled = false; input.disabled = false; close.disabled = false; }
        };
        input.focus();
      };
      root.append(item);
    }
  }
  async function openTarget(target) {
    if (pending) return;
    if (selected?.id !== target.id && q('#ef-body').value.trim()) {
      q('.status').textContent = '入力中のコメントを送信するか、本文を空にしてから対象を切り替えてください。'; return;
    }
    selected = target; setInspect(false); renderTargets(); q('.detail').hidden = false;
    q('.selected-title').textContent = target.textHint || target.selector;
    comments = []; commentsLoaded = false; q('.send').disabled = true; renderComments();
    const token = ++loadingToken;
    try { const data = await request(`comments?${query({targetType: 'element', targetId: target.id})}`); if (token === loadingToken && !destroyed) { comments = data.comments || data; commentsLoaded = true; q('.send').disabled = false; renderComments(); } }
    catch (error) { if (token === loadingToken) setError(error.message); }
  }
  async function choose(element) {
    if (!targetsLoaded || pending || !element || element === document.documentElement || element === document.body) return;
    if (element.closest(PRIVATE) || element.closest(HOST)) { outline(null); q('.status').textContent = 'この領域はコメント対象から除外されています。'; return; }
    if (element.localName === 'iframe' || element.shadowRoot) { q('.status').textContent = 'iframe・Shadow DOM 内部の選択には対応していません。'; return; }
    if (selected && q('#ef-body').value.trim()) { q('.status').textContent = '入力中のコメントを送信するか、本文を空にしてから対象を切り替えてください。'; return; }
    const metadata = describeElement(element, revision);
    // A stable anchor keeps its discussion even when text changed. Resolution stays
    // conservative: openTarget displays ambiguity and never highlights changed text.
    if (stableSelector(metadata.selector)) {
      const anchored = targets.filter(target => target.pagePath === metadata.pagePath && target.selector === metadata.selector);
      if (anchored.length > 1) { setError('同じ安定IDの登録対象が複数あります。登録済みの対象一覧から選んでください。'); return; }
      if (anchored.length === 1) { await openTarget(anchored[0]); return; }
    }
    // Structural candidates must still resolve to this exact DOM element.
    const candidates = targets.filter(target => locateTarget(target).element === element || (known.get(element) === target.id && target.pagePath === metadata.pagePath && target.selector === metadata.selector && target.textHint === metadata.textHint));
    if (candidates.length > 1) { setError('一致する登録対象が複数あります。登録済みの対象一覧から選んでください。'); return; }
    if (candidates.length === 1) { await openTarget(candidates[0]); return; }
    // Blank/duplicate structural fingerprints cannot safely be reused across reloads.
    const exact = targets.filter(target => target.pagePath === metadata.pagePath && target.selector === metadata.selector && target.textHint === metadata.textHint);
    if (exact.length) { setError('同じ位置の登録対象を確認できません。既存コメントは一覧から確認できます。data-feedback-id を付けて対象を安定させてください。'); return; }
    pending = true; q('.inspect').disabled = true; setInspect(false); setError('');
    try {
      const target = {id: await targetIdFor(projectId, metadata), ...metadata};
      const data = await request('targets', {projectId, ...target});
      const saved = data.target || (data.id ? data : target);
      if (!targets.some(existing => existing.id === saved.id)) targets.push(saved); known.set(element, saved.id); pending = false; await openTarget(saved);
    } catch (error) { setError(error.message); }
    finally { pending = false; q('.inspect').disabled = false; }
  }
  async function send() {
    const author = q('#ef-author').value.trim(), body = q('#ef-body').value.trim();
    if (pending || !selected || !commentsLoaded) return;
    if (!author || !body) { setError('名前とコメントを入力してください。'); return; }
    pending = true; q('.send').disabled = true; setError('');
    // Freeze fields while a request is in flight so success cannot erase later edits.
    q('#ef-body').disabled = true; q('#ef-author').disabled = true;
    try {
      const data = await request('comments', {projectId, targetType: 'element', targetId: selected.id, author, body});
      comments.push(data.comment || data); q('#ef-body').value = '';
      try { localStorage.setItem(authorKey, author); } catch {}
      renderComments();
    } catch (error) { setError(error.message); }
    finally { pending = false; q('.send').disabled = false; q('#ef-body').disabled = false; q('#ef-author').disabled = false; }
  }
  function isOwn(event) { return event.composedPath().includes(host); }
  const listeners = [];
  function listen(target, name, handler, options) { target.addEventListener(name, handler, options); listeners.push(() => target.removeEventListener(name, handler, options)); }
  const stop = event => { event.preventDefault(); event.stopImmediatePropagation(); };
  listen(window, 'pointermove', event => { if (inspecting && !isOwn(event)) { hovered = event.target; outline(hovered); } }, true);
  listen(window, 'focusin', event => { if (inspecting && !isOwn(event)) { hovered = event.target; outline(hovered); } }, true);
  // Cancel default focus/drag/touch activation and page pointer handlers while picking.
  for (const name of ['pointerdown', 'mousedown', 'mouseup', 'dblclick', 'contextmenu']) listen(window, name, event => { if (inspecting && !isOwn(event)) stop(event); }, {capture: true, passive: false});
  listen(window, 'pointerup', event => { if (inspecting && !isOwn(event)) { stop(event); if (event.pointerType === 'touch' || event.pointerType === 'pen') { swallowedTarget = event.target; swallowUntil = Date.now() + 900; choose(event.target); } } }, true);
  listen(window, 'click', event => {
    if (isOwn(event)) return;
    if (event.target === swallowedTarget && Date.now() < swallowUntil) { stop(event); return; }
    if (inspecting) { stop(event); choose(event.target); return; }
    // A normal page click dismisses feedback without swallowing the site's action.
    if (!q('.panel').hidden) {
      q('.panel').hidden = true;
      q('.launcher').setAttribute('aria-expanded', 'false');
      outline(null);
    }
  }, true);
  listen(window, 'submit', event => { if (inspecting && !isOwn(event)) stop(event); }, true);
  listen(window, 'keydown', event => {
    if (event.key === 'Escape') {
      if (inspecting) { stop(event); setInspect(false); q('.inspect').focus(); }
      else if (!q('.panel').hidden) { stop(event); q('.panel').hidden = true; q('.launcher').setAttribute('aria-expanded', 'false'); outline(null); q('.launcher').focus(); }
      return;
    }
    if (!inspecting || isOwn(event)) return;
    if (event.key === 'Enter' && !event.isComposing) { stop(event); choose(event.target); }
    else if (event.key !== 'Tab') stop(event);
  }, true);
  listen(window, 'keyup', event => { if (inspecting && !isOwn(event) && event.key !== 'Tab') stop(event); }, true);
  listen(window, 'scroll', refresh, true); listen(window, 'resize', refresh);
  const observer = new MutationObserver(() => { cancelAnimationFrame(refreshFrame); refreshFrame = requestAnimationFrame(refresh); });
  observer.observe(document.body, {childList: true, subtree: true, characterData: true, attributes: true});
  q('.launcher').onclick = () => { q('.panel').hidden = !q('.panel').hidden; q('.launcher').setAttribute('aria-expanded', String(!q('.panel').hidden)); if (q('.panel').hidden) setInspect(false); refresh(); };
  q('.close').onclick = () => { q('.panel').hidden = true; q('.launcher').setAttribute('aria-expanded', 'false'); setInspect(false); q('.launcher').focus(); };
  q('.inspect').onclick = () => setInspect(!inspecting);
  q('.inspect').onkeydown = event => {
    if (!inspecting || event.isComposing) return;
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const elements = all('body *').filter(el => !el.closest(PRIVATE) && !el.closest(HOST) && el.getClientRects().length && el.localName !== 'iframe' && !el.shadowRoot);
      if (!elements.length) return;
      const index = elements.indexOf(hovered);
      hovered = elements[(index + (event.key === 'ArrowDown' ? 1 : -1) + elements.length) % elements.length];
      hovered.scrollIntoView({block: 'nearest'}); outline(hovered);
      q('.status').textContent = `選択候補：${hovered.localName} ${safeText(hovered)}`;
    } else if (event.key === 'Enter' && hovered) { event.preventDefault(); choose(hovered); }
  };
  q('.send').onclick = send;
  q('.clear-author').onclick = () => {
    if (pending) return;
    try { localStorage.removeItem(authorKey); } catch {}
    q('#ef-author').value = ''; q('#ef-author').focus();
  };
  q('#ef-body').onkeydown = event => { if (event.key === 'Enter' && (event.metaKey || event.ctrlKey) && !event.isComposing && event.keyCode !== 229) { event.preventDefault(); send(); } };
  async function loadTargets() {
    q('.reload').disabled = true; q('.inspect').disabled = true; setError('');
    try {
      const data = await request(`targets?${query()}`);
      if (!destroyed) { targets = data.targets || data; targetsLoaded = true; renderTargets(); }
    } catch (error) { setError(error.message); }
    finally { q('.reload').disabled = false; q('.inspect').disabled = !targetsLoaded; }
  }
  q('.reload').onclick = loadTargets;
  const ready = loadTargets();
  return {ready, destroy() { destroyed = true; ++loadingToken; observer.disconnect(); cancelAnimationFrame(refreshFrame); listeners.forEach(remove => remove()); host.remove(); }};
}
