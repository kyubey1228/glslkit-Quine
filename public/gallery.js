document.addEventListener('DOMContentLoaded', async () => {
'use strict';
const $=id=>document.getElementById(id);
let source=JSON.parse($('ruby-data').textContent),initial=source,generation=0,loops=0;
const sourceCanvas=$('code-canvas'),code2d=sourceCanvas.getContext('2d',{willReadFrequently:true});
$('code-zoom').onclick=()=>{const zoomed=sourceCanvas.style.width==='auto';sourceCanvas.style.width=zoomed?'100%':'auto';$('code-zoom').textContent=zoomed?'↗ 原寸で見る':'↙ 全体を見る';};
for(const name of ['about','source'])$(name+'-open').onclick=()=>$(name).showModal();
for(const button of document.querySelectorAll('[data-close]'))button.onclick=()=>$(button.dataset.close).close();
function download(text,name){const url=URL.createObjectURL(new Blob([text],{type:'text/plain'}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
try {
const canvas=$('art'),gl=canvas.getContext('webgl2',{alpha:false,antialias:false});
if(!gl)throw new Error('WebGL2対応ブラウザで開いてください。');
let program,uniforms,fragment=$('ouroboros-frag').textContent,rows=82;
const vertex=$('ouroboros-vert').textContent;
function compile(type,text){const shader=gl.createShader(type);gl.shaderSource(shader,text);gl.compileShader(shader);if(!gl.getShaderParameter(shader,gl.COMPILE_STATUS)){const log=gl.getShaderInfoLog(shader);gl.deleteShader(shader);throw new Error(log);}return shader;}
function install(frag,manifest){
 const next=gl.createProgram(),vs=compile(gl.VERTEX_SHADER,vertex),fs=compile(gl.FRAGMENT_SHADER,frag);
 gl.attachShader(next,vs);gl.attachShader(next,fs);gl.linkProgram(next);gl.deleteShader(vs);gl.deleteShader(fs);
 if(!gl.getProgramParameter(next,gl.LINK_STATUS)){const log=gl.getProgramInfoLog(next);gl.deleteProgram(next);throw new Error(log);}
 if(program)gl.deleteProgram(program);program=next;fragment=frag;gl.useProgram(program);uniforms={};
 for(const u of manifest.programs.ouroboros.uniforms){const loc=gl.getUniformLocation(program,u.name);uniforms[u.name]=v=>gl[u.setter](loc,typeof v==='number'?[v]:v);}
 rows=Number(frag.match(/const int NL\s*=\s*(\d+)/)[1])-1;
}
const set=(name,value)=>uniforms[name](value);
const pointer=[0,0],target=[0,0];let speed=1,paused=matchMedia('(prefers-reduced-motion: reduce)').matches,ready=false,busy=false,accumulator=0,last=performance.now(),raf;
function pauseLabel(){$('pause').textContent=paused?'▶ 再生':'Ⅱ 静止';$('pause').setAttribute('aria-pressed',String(paused));}
pauseLabel();$('pause').onclick=()=>{paused=!paused;pauseLabel();};
$('speed').oninput=e=>{speed=Number(e.target.value);$('speed-value').value=speed.toFixed(1)+'×';};
canvas.addEventListener('pointermove',e=>{target[0]=e.clientX/innerWidth*2-1;target[1]=1-e.clientY/innerHeight*2;});canvas.addEventListener('pointerleave',()=>target.fill(0));
function resize(){const dpr=Math.min(devicePixelRatio,1.5);canvas.width=Math.round(innerWidth*dpr);canvas.height=Math.round(innerHeight*dpr);}addEventListener('resize',resize);resize();
canvas.addEventListener('webglcontextlost',e=>{e.preventDefault();cancelAnimationFrame(raf);ready=false;$('status').textContent='GPU接続が切れました。再読み込みしてください。';});
install(fragment,JSON.parse($('glsl-manifest').textContent));
// Render the complete Ruby source into a visible, readable glyph sheet.
// Each glyph's eighth row contains eight visible bits, including spaces and newlines.
function drawCode(){
 const w=201*8,h=rows*9,fb=gl.createFramebuffer(),tex=gl.createTexture(),pixels=new Uint8Array(w*h*4);
 try{gl.bindTexture(gl.TEXTURE_2D,tex);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA8,w,h,0,gl.RGBA,gl.UNSIGNED_BYTE,null);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);gl.bindFramebuffer(gl.FRAMEBUFFER,fb);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,tex,0);if(gl.checkFramebufferStatus(gl.FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE)throw new Error('コード描画用バッファを作成できません');gl.disable(gl.DITHER);gl.viewport(0,0,w,h);set('u_resolution',new Float32Array([w,h]));set('u_mode',2);gl.drawArrays(gl.TRIANGLES,0,3);gl.readPixels(0,0,w,h,gl.RGBA,gl.UNSIGNED_BYTE,pixels);if(gl.getError()!==gl.NO_ERROR)throw new Error('GPUコード描画に失敗しました');}
 finally{gl.bindFramebuffer(gl.FRAMEBUFFER,null);gl.deleteTexture(tex);gl.deleteFramebuffer(fb);set('u_mode',1);}
 sourceCanvas.width=w;sourceCanvas.height=h;const image=code2d.createImageData(w,h);
 for(let y=0;y<h;y++)image.data.set(pixels.subarray((h-1-y)*w*4,(h-y)*w*4),y*w*4);
 code2d.putImageData(image,0,0);
}
function extractCode(){
 // Read the actual displayed glyph pixels. No SRC[] or source string is used here.
 const w=sourceCanvas.width,pixels=code2d.getImageData(0,0,w,sourceCanvas.height).data,bytes=[];
 for(let row=0;row<rows;row++){
  let ended=false;
  for(let col=0;col<201;col++){
   let byte=0;for(let bit=0;bit<8;bit++){const offset=((row*9+7)*w+col*8+bit)*4;if(pixels[offset]>128)byte|=1<<bit;}
   bytes.push(byte);if(byte===10){ended=true;break;}if(byte===0)throw new Error('描画コードを読み取れません: '+row+','+col);
  }
  if(!ended)throw new Error('コードの改行を読み取れません');
 }
 return new TextDecoder('utf-8',{fatal:true}).decode(new Uint8Array(bytes));
}
function showStatus(){ $('generation').textContent=String(generation+1).padStart(2,'0')+' / 24';$('status').textContent='✓ 描画したRuby → 実行 → glslkit → 次の姿 · '+loops+'周'; }
function checkCurrent(){const recovered=extractCode();if(recovered!==source)throw new Error('描画コードがRubyと一致しません');return recovered;}
drawCode();checkCurrent();
$('save').onclick=()=>download(checkCurrent(),'ouroboros-'+String(generation).padStart(2,'0')+'.rb');
function render(now){const dt=Math.min((now-last)/1000,.1);last=now;if(!paused&&ready&&!busy){accumulator+=dt*speed;if(accumulator>=.35){accumulator=0;advance();}}pointer.forEach((v,i)=>pointer[i]+=(target[i]-v)*.035);gl.viewport(0,0,canvas.width,canvas.height);set('u_mode',1);set('u_resolution',new Float32Array([canvas.width,canvas.height]));set('u_pointer',new Float32Array(pointer));gl.drawArrays(gl.TRIANGLES,0,3);raf=requestAnimationFrame(render);}
raf=requestAnimationFrame(render);
$('status').textContent='Ruby処理系を読み込んでいます…';
const embedded=$('ruby-wasm-data');let wasm;
if(embedded){const binary=atob(embedded.textContent.trim());wasm=Uint8Array.from(binary,c=>c.charCodeAt(0));}else{const response=await fetch('/ruby.wasm');if(!response.ok)throw new Error('Ruby処理系を読み込めません');wasm=await response.arrayBuffer();}
const {vm}=await window['ruby-wasm-wasi'].DefaultRubyVM(await WebAssembly.compile(wasm),{consolePrint:false});
const b64=text=>btoa(Array.from(new TextEncoder().encode(text),c=>String.fromCharCode(c)).join(''));
const sources=JSON.parse($('glslkit-sources').textContent);
vm.eval(`SOURCES=JSON.parse("${b64(JSON.stringify(sources))}".unpack1("m"))` .replace('SOURCES=JSON.parse','require "json";SOURCES=JSON.parse'));
vm.eval($('ruby-bootstrap').textContent);
function execute(text,shader=false){return atob(vm.eval(`__saved=$stdout;__args=ARGV.dup;$stdout=StringIO.new;ARGV.replace(${shader?'["--shader"]':'[]'});begin;eval("${b64(text)}".unpack1("m"),TOPLEVEL_BINDING,"drawn.rb");[$stdout.string].pack("m0");ensure;$stdout=__saved;ARGV.replace(__args);end`).toString());}
function bundle(frag){return JSON.parse(vm.eval(`f="${b64(frag)}".unpack1("m");v="${b64(vertex)}".unpack1("m");b=Glslkit::Bundle.build(resolver:Glslkit::Resolvers::Hash.new("ouroboros.vert"=>v,"ouroboros.frag"=>f),name:"ouroboros",vertex:"ouroboros.vert",fragment:"ouroboros.frag",line_directives:false);raise(b.diagnostics.map(&:to_s).join)unless(b.ok?);JSON.generate({fragment:b.fragment.code,manifest:b.manifest})`).toString());}
function advance(){
 if(busy)return;busy=true;
 try{const drawn=checkCurrent(),next=execute(drawn),phase=(generation+1)%24;
  if(next===drawn)throw new Error('世代が変化していません');
  if(phase===0&&next!==initial)throw new Error('24世代で最初のコードに戻りません');
  const built=bundle(execute(next,true));install(built.fragment,built.manifest);source=next;generation=phase;if(phase===0)loops++;
  drawCode();checkCurrent();showStatus();
 }catch(e){ready=false;paused=true;pauseLabel();$('status').textContent='循環エラー: '+e.message;console.error(e);}
 finally{busy=false;}
}
$('next').disabled=false;$('next').onclick=()=>{accumulator=0;advance();};
$('verify').disabled=false;$('verify').onclick=async()=>{
 const before=source,wasPaused=paused;paused=true;pauseLabel();$('verify').disabled=true;
 try{for(let i=0;i<24;i++){if(!ready)throw new Error('循環が停止しました');advance();await new Promise(resolve=>requestAnimationFrame(resolve));}if(source!==before)throw new Error('一周後の不一致');$('status').textContent='✓ 描画ピクセルから24世代を実行、一周後に全バイト一致';}
 catch(e){$('status').textContent=e.message;}
 finally{$('verify').disabled=false;paused=wasPaused;pauseLabel();accumulator=0;}
};
ready=true;showStatus();
} catch(e){$('status').textContent='作品エラー: '+e.message;document.body.classList.add('failed');console.error(e);}
});
