// Test the report's filtering and paging logic without a browser or UI automation.
const fs=require('fs'),vm=require('vm'),assert=require('assert'),path=require('path');
const home=__dirname,html=fs.readFileSync(path.join(home,'index.html'),'utf8');
const raw=html.match(/<script id="data" type="application\/json">([\s\S]*?)<\/script>/)[1];
const js=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
class E{constructor(tag='div'){this.tag=tag;this.textContent='';this.children=[];this.value='';this.dataset={};this.events={};}append(...c){this.children.push(...c)}replaceChildren(...c){this.children=[...c]}addEventListener(n,f){this.events[n]=f}scrollIntoView(){} }
const ids={};for(const id of ['data','search','domain','status','priority','count','rows','pagecount','prev','next','reset','matrix'])ids[id]=new E();ids.data.textContent=raw;
const quick=[new E('button'),new E('button')];quick[0].dataset.query='CFG-X06';quick[1].dataset.domain='control';
const document={getElementById:id=>ids[id],createElement:tag=>new E(tag),querySelectorAll:()=>quick};
vm.runInNewContext(js,{document,console});
const all=JSON.parse(raw).report.rows,tests=[];
function check(name,condition){assert(condition,name);tests.push(name)}
check('default350rows',ids.count.textContent.startsWith('350 of 350'));
check('firstPage35',ids.rows.children.length===35);
ids.search.value='DATA-117';ids.search.events.input();check('searchExactID',ids.count.textContent.startsWith('1 of 350'));check('correctID',ids.rows.children[0].id==='DATA-117');
ids.reset.onclick();ids.domain.value='config';ids.domain.events.change();check('config100',ids.count.textContent.startsWith('100 of 350'));
ids.status.value='missing';ids.status.events.change();check('combinedDomainStatus',ids.count.textContent.startsWith(all.filter(r=>r.domain==='config'&&r.status==='missing').length+' of'));
ids.reset.onclick();ids.priority.value='P0';ids.priority.events.change();check('priorityFilter',ids.count.textContent.startsWith(all.filter(r=>r.priority==='P0').length+' of'));
ids.reset.onclick();ids.next.onclick();check('nextPage',ids.rows.children[0].id===all[35].id);ids.prev.onclick();check('previousPage',ids.rows.children[0].id===all[0].id);
quick[0].onclick();check('findingShortcut',ids.rows.children.length===1&&ids.rows.children[0].id==='CFG-X06');
quick[1].onclick();check('domainShortcut',ids.count.textContent.startsWith('38 of 350'));
ids.reset.onclick();ids.search.value='nothing_matches_this_audit_123456';ids.search.events.input();check('emptyResults',ids.rows.children.length===0&&ids.next.disabled&&ids.prev.disabled);
ids.reset.onclick();check('reset',ids.count.textContent.startsWith('350 of 350'));
const result={passed:true,method:'Node VM with minimal DOM shim; tests filtering,paging,shortcuts and generated row construction. Not browser rendering or physical visual QA.',tests};
fs.writeFileSync(path.join(home,'report-js-validation.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
