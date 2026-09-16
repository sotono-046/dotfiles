import { handleApi } from './shared/api.mjs';
export default {
  async fetch(request,env) {
    const path = new URL(request.url).pathname;
    if (path.startsWith('/api/')) {
      const dataResponse = await env.ASSETS.fetch(new Request(new URL('/flow-data.json',request.url)));
      if (!dataResponse.ok) return new Response('Missing flow data',{status:500});
      return handleApi(request,env.DB,await dataResponse.json());
    }
    if ((!['/','/index.html','/app.js','/comment-state.js','/styles.css','/flow-data.json'].includes(path) && !/^\/element-feedback\/[a-zA-Z0-9_-]+\.(?:html|mjs|js|css)$/.test(path)) || request.method !== 'GET') return new Response('Not found',{status:404});
    // Keep explicit .html URLs identical to the Node preview. With html_handling
    // disabled the root document needs an explicit mapping.
    return env.ASSETS.fetch(path === '/' ? new Request(new URL('/index.html',request.url),request) : request);
  }
};
