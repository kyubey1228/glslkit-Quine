// Upload only the data embedded in the generated shader. Never use the saved Ruby
// string as a substitute for the code recovered from displayed pixels.
window.OuroborosShaderData={prepare(gl,fragment){
 if(!fragment.includes('#ifdef OUROBOROS_TEXTURE_DATA'))return {fragment,texture:null,bind(){},dispose(){}};
 const integer=name=>{const match=fragment.match(new RegExp('const int '+name+'\\s*=\\s*(\\d+)'));if(!match)throw new Error('シェーダーデータがありません: '+name);return Number(match[1]);};
 const length=integer('LEN'),lineCount=integer('NL'),words=[];
 const blocks=[...fragment.matchAll(/const uvec4 SRC(\d+)\[(\d+)\]=uvec4\[\]\((.*?)\);/gs)];
 if(!blocks.length)throw new Error('シェーダーのソースデータがありません');
 blocks.forEach((match,index)=>{
  if(Number(match[1])!==index)throw new Error('シェーダーのソースブロックが欠けています');
  const vectors=[...match[3].matchAll(/uvec4\(([^)]*)\)/g)];
  if(vectors.length!==Number(match[2]))throw new Error('シェーダーのソース要素数が一致しません');
  for(const vector of vectors){const entries=vector[1].split(',').map(x=>x.trim());if(entries.length!==4||entries.some(x=>! /^(?:0x[\da-f]+|\d+)u$/i.test(x)))throw new Error('シェーダーのソース値が不正です');for(const entry of entries)words.push(Number(entry.slice(0,-1)));}
 });
 const lines=fragment.match(/const int LS\[\d+\]=int\[\]\((.*?)\);/s),font=fragment.match(/const uint FONT\[95\]=uint\[\]\((.*?)\);/s);
 if(!lines||!font||words.length*4<length)throw new Error('シェーダーデータが不足しています');
 const offsets=lines[1].split(',').map(Number),glyphs=font[1].split(',').map(x=>Number(x.trim().replace(/u$/,'')));
 if(offsets.length!==lineCount||offsets[0]!==0||offsets.at(-1)!==length||offsets.some((n,i)=>!Number.isInteger(n)||n<0||n>length||(i&&n<=offsets[i-1]))||glyphs.length!==95||glyphs.some(n=>!Number.isInteger(n)||n<0||n>0xffffffff))throw new Error('シェーダーの行情報かフォントが不正です');
 const width=256,height=Math.ceil((length+lineCount+glyphs.length)/width),data=new Uint32Array(width*height);
 for(let i=0;i<length;i++)data[i]=(words[i>>2]>>>(8*(i&3)))&255;
 data.set(offsets,length);data.set(glyphs,length+lineCount);
 const texture=gl.createTexture();if(!texture)throw new Error('コード用テクスチャを作成できません');
 try{
  gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,texture);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  gl.texImage2D(gl.TEXTURE_2D,0,gl.R32UI,width,height,0,gl.RED_INTEGER,gl.UNSIGNED_INT,data);
  if(gl.getError()!==gl.NO_ERROR)throw new Error('コード用テクスチャの転送に失敗しました');
 }catch(error){gl.deleteTexture(texture);throw error;}
 finally{gl.activeTexture(gl.TEXTURE0);}
 return {texture,fragment:fragment.replace(/^(#version[^\n]*\n)/,'$1#define OUROBOROS_TEXTURE_DATA 1\n'),bind(program){gl.useProgram(program);gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,texture);gl.uniform1i(gl.getUniformLocation(program,'u_data'),1);gl.activeTexture(gl.TEXTURE0);},dispose(){gl.deleteTexture(texture);}};
}};
