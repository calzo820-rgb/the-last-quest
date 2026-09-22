import fs from 'node:fs';
import vm from 'node:vm';
const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8');
for(const token of ['The Last Quest','id="creator"','id="join"','id="game"','startCreator','renderQuests']){
  if(!html.includes(token)) throw new Error(`Missing ${token}`);
}
for(const token of ['bachelor_party','bachelorette_party','previewMissionCount']){
  if(!html.includes(token)) throw new Error(`Missing event catalog behavior: ${token}`);
}
if(/<strong>30<\/strong><span>missioni/.test(html)) throw new Error('Misleading mission count is still present');
for(const file of ['../api/create-checkout.js','../api/stripe-webhook.js','../.env.example']){
  if(!fs.existsSync(new URL(file,import.meta.url))) throw new Error(`Missing ${file}`);
}
if(/Andrea|MALAGA26|Pasaporte del Novio/i.test(html)) throw new Error('Prototype-specific content leaked into product');

const checkout=fs.readFileSync(new URL('../api/create-checkout.js',import.meta.url),'utf8');
const webhook=fs.readFileSync(new URL('../api/stripe-webhook.js',import.meta.url),'utf8');
const serviceWorker=fs.readFileSync(new URL('../sw.js',import.meta.url),'utf8');
const manifest=JSON.parse(fs.readFileSync(new URL('../manifest.webmanifest',import.meta.url),'utf8'));
const vercel=JSON.parse(fs.readFileSync(new URL('../vercel.json',import.meta.url),'utf8'));
const inlineScripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
  .map(match=>match[1]).filter(Boolean);

new vm.Script(inlineScripts.at(-1),{filename:'index.inline.js'});
new vm.Script(checkout,{filename:'create-checkout.js'});
new vm.Script(webhook,{filename:'stripe-webhook.js'});
new vm.Script(serviceWorker,{filename:'sw.js'});

for(const token of ['reopenEventAfterCheckout','purchase_status','serviceWorker.register']){
  if(!html.includes(token)) throw new Error(`Missing checkout/PWA behavior: ${token}`);
}
for(const token of ['/auth/v1/user','event.owner_user_id !== user.id','{CHECKOUT_SESSION_ID}']){
  if(!checkout.includes(token)) throw new Error(`Missing checkout security: ${token}`);
}
for(const token of ['stripe-signature','activate_paid_event','checkout.session.async_payment_succeeded']){
  if(!webhook.includes(token)) throw new Error(`Missing webhook behavior: ${token}`);
}
if(!manifest.icons?.length || !manifest.scope) throw new Error('PWA manifest is incomplete');
if(!fs.existsSync(new URL('../sw.js',import.meta.url))) throw new Error('Missing service worker');
if(!fs.existsSync(new URL('../privacy.html',import.meta.url)) || !fs.existsSync(new URL('../terms.html',import.meta.url))) throw new Error('Missing legal drafts');
if(!fs.existsSync(new URL('../docs/RELEASE_CHECKLIST.md',import.meta.url))) throw new Error('Missing release checklist');
if(!JSON.stringify(vercel).includes('X-Frame-Options')) throw new Error('Security headers are incomplete');
if(/sk_(?:test|live)_|whsec_|service_role\s*=\s*[A-Za-z0-9_-]{20,}/.test([html,checkout,webhook].join('\n'))){
  throw new Error('A server secret appears to be committed');
}
console.log('The Last Quest checks passed');
