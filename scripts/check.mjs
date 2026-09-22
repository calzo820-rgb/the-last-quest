import fs from 'node:fs';
const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8');
for(const token of ['The Last Quest','id="creator"','id="join"','id="game"','startCreator','renderQuests']){
  if(!html.includes(token)) throw new Error(`Missing ${token}`);
}
for(const file of ['../api/create-checkout.js','../api/stripe-webhook.js','../.env.example']){
  if(!fs.existsSync(new URL(file,import.meta.url))) throw new Error(`Missing ${file}`);
}
if(/Andrea|MALAGA26|Pasaporte del Novio/i.test(html)) throw new Error('Prototype-specific content leaked into product');
console.log('The Last Quest checks passed');
