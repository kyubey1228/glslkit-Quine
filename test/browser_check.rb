require 'fileutils'
root=File.expand_path('..',__dir__)
FileUtils.mkdir_p(File.join(root,'tmp'))
html=File.read(File.expand_path('../index.html',__dir__))
check=<<~'JS'
ready=true;showStatus();
const checks={};
const begin=source;
checks.visible_pixels_equal_source=extractCode()===begin;
// Prove the next source is read from visible pixels: flipping one bit changes extraction.
const originalPixel=code2d.getImageData(0,7,1,1),flipped=code2d.getImageData(0,7,1,1);
flipped.data[0]=flipped.data[0]>128?0:255;code2d.putImageData(flipped,0,7);
checks.extraction_depends_on_drawn_pixels=extractCode()!==begin;
code2d.putImageData(originalPixel,0,7);
function sample(){gl.viewport(0,0,canvas.width,canvas.height);set('u_mode',1);set('u_resolution',new Float32Array([canvas.width,canvas.height]));set('u_pointer',new Float32Array([0,0]));gl.drawArrays(gl.TRIANGLES,0,3);const data=new Uint8Array(96*96*4);gl.readPixels(Math.floor(canvas.width*.76),Math.floor(canvas.height*.5),96,96,gl.RGBA,gl.UNSIGNED_BYTE,data);return data;}
const first=sample(),expectedNext=execute(extractCode());
last=performance.now()-100;accumulator=.34;paused=false;render(performance.now());
checks.automatic_playback_executes_ruby=source===expectedNext&&generation===1;
const second=sample();
checks.real_ruby_output_becomes_next_frame=source===expectedNext;
checks.next_art_changes_pixels=first.some((v,i)=>v!==second[i]);
const phases=[generation];for(let i=1;i<24;i++){advance();phases.push(generation);}
checks.all_24_generations_executed=new Set(phases).size===24&&ready;
checks.cycle_source_exact=source===begin;
checks.cycle_visible_pixels_exact=extractCode()===begin;
const final=sample();checks.cycle_art_exact=first.every((v,i)=>v===final[i]);
checks.glslkit_runs_in_browser=vm.eval('Glslkit::VERSION').toString().length>0;
paused=false;pauseLabel();$('pause').click();checks.pause=paused;$('pause').click();checks.resume=!paused;
$('speed').value='1.5';$('speed').dispatchEvent(new Event('input'));checks.speed=speed===1.5;
$('source-open').click();checks.source_dialog=$('source').open;const logicalWidth=sourceCanvas.width;$('code-zoom').click();checks.zoom_preserves_extraction=sourceCanvas.width===logicalWidth&&extractCode()===source;$('code-zoom').click();$('source').close();
paused=true;pauseLabel();
$('source').showModal();
const clipboardDescriptor=Object.getOwnPropertyDescriptor(navigator,'clipboard'),originalExec=document.execCommand;
let copied;
try{
 Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>{copied=text;}}});
 await $('code-copy').onclick();
 checks.copy_preserves_all_source_bytes=copied===extractCode()&&$('copy-status').textContent.includes('コピーしました');
 navigator.clipboard.writeText=async()=>{throw new Error('clipboard unavailable');};
 document.execCommand=command=>{const field=$('source').querySelector('textarea');copied=field?.value;return command==='copy'&&field===document.activeElement&&field.selectionStart===0&&field.selectionEnd===copied.length;};
 copied=null;await $('code-copy').onclick();
 checks.copy_fallback_preserves_source=copied===extractCode()&&!$('source').querySelector('textarea')&&!$('code-copy').disabled;
 document.execCommand=()=>false;await $('code-copy').onclick();
 checks.copy_failure_is_reported=$('copy-status').textContent.includes('コピーできません')&&!$('code-copy').disabled;
}finally{
 if(clipboardDescriptor)Object.defineProperty(navigator,'clipboard',clipboardDescriptor);else delete navigator.clipboard;
 document.execCommand=originalExec;$('source').close();
}
checks.no_gl_error=gl.getError()===gl.NO_ERROR;
const report=document.createElement('pre');report.id='browser-check';report.style.display='none';report.textContent=JSON.stringify(checks);document.body.append(report);
JS
html=html.sub('ready=true;showStatus();') { check }
File.write(File.join(root,'tmp/browser-check.html'),html)
