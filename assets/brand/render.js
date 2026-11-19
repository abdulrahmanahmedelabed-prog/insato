const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage();
const svg=fs.readFileSync(process.argv[2],'utf8');const sizes=process.argv.slice(4).map(Number);
for(const s of sizes){await p.setViewportSize({width:s,height:s});
await p.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('<svg ','<svg width="'+s+'" height="'+s+'" ')}</body></html>`);
await p.screenshot({path:`${process.argv[3]}-${s}.png`,omitBackground:true});}
await b.close()})();
