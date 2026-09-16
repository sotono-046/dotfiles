// Regression harness executes the real module with minimal DOM and fetch doubles.
import {readFile} from 'node:fs/promises';
const calls=[], listeners={};
class E { constructor(){this.dataset={};this.style={};this.children=[];this.value='';this.hidden=false;this.isConnected=true;this.localName='div';this.nodeType=1;} append(...xs){this.children.push(...xs);} replaceChildren(...xs){this.children=xs;} setAttribute(){} getAttribute(){return null;} closest(){return null;} focus(){} getBoundingClientRect(){return {left:0,top:0,width:10,height:10};} }
const fields=new Map();const shadow={querySelector(s){if(!fields.has(s))fields.set(s,new E());return fields.get(s);}};
const host=new E();host.attachShadow=()=>shadow;
const privateElement=new E();privateElement.id='private-button';privateElement.localName='button';privateElement.closest=(s)=>s.includes('data-feedback-private')?{}:null;
globalThis.location=new URL('http://127.0.0.1:4173/private.html');
globalThis.document={body:new E(),documentElement:new E(),location,querySelector(){return null;},querySelectorAll(s){return s==='#private-button'?[privateElement]:[];},createElement(){return host;}};
privateElement.ownerDocument=document;
globalThis.window={addEventListener(n,fn){(listeners[n]??=[]).push(fn);},removeEventListener(){}};
globalThis.CSS={escape:s=>s};globalThis.MutationObserver=class{observe(){} disconnect(){}};
globalThis.localStorage={getItem(){return '';},setItem(){}};
globalThis.cancelAnimationFrame=()=>{};globalThis.requestAnimationFrame=()=>0;
globalThis.fetch=async(u,opts)=>{const body=opts.body?JSON.parse(opts.body):null;calls.push({path:new URL(u).pathname,body});return new Response(JSON.stringify(body?{target:body}:new URL(u).pathname.endsWith('targets')?{targets:[]}:{comments:[]}));};
const src=await readFile(new URL('../element-feedback.js', import.meta.url),'utf8');
const {initElementFeedback}=await import('data:text/javascript;base64,'+Buffer.from(src).toString('base64'));
const ui=initElementFeedback({projectId:'contract-audit',revision:'v1',enabled:true});await ui.ready;
fields.get('.inspect').onclick();
for(const fn of listeners.click) fn({target:privateElement,composedPath:()=>[privateElement],preventDefault(){},stopImmediatePropagation(){}});
await new Promise(r=>setTimeout(r,25));

const assert=(await import('node:assert/strict')).default;
assert.equal(calls.filter(c=>c.path==='/api/targets'&&c.body).length,0,'PRIVATE target must never be registered');
const exported=await import('data:text/javascript;base64,'+Buffer.from(src).toString('base64'));
assert.throws(()=>exported.describeElement(privateElement,'v1'),/除外/);
assert.equal(exported.locateTarget({pagePath:location.pathname,selector:'#private-button',textHint:''}).element,null,'legacy private anchor must not resolve');
for(const fn of listeners.pointermove) fn({target:privateElement,composedPath:()=>[privateElement]});
assert.equal(fields.get('.outline').hidden,true,'PRIVATE hover must not outline');
let removedKey=null;
localStorage.removeItem=key=>{removedKey=key;};
fields.get('#ef-author').value='remembered name';
fields.get('.clear-author').onclick();
assert.equal(removedKey,'element-feedback:contract-audit:author');
assert.equal(fields.get('#ef-author').value,'');
// Exit inspection, then simulate a normal outside page click.
fields.get('.inspect').onclick();
shadow.querySelector('.panel').hidden=false;
let swallowed=0;
for(const fn of listeners.click) fn({target:privateElement,composedPath:()=>[privateElement],preventDefault(){swallowed++;},stopImmediatePropagation(){swallowed++;}});
assert.equal(fields.get('.panel').hidden,true);
assert.equal(swallowed,0,'outside click must keep page action');
console.log('PASS: PRIVATE selection/metadata/legacy/outline, author clear, outside dismissal preserving page action');
