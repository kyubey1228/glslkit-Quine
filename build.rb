require_relative 'config/boot'
require 'zlib'
require 'open3'
require 'json'
require 'fileutils'
require_relative 'lib/font'
require 'glslkit'
root = __dir__
hex = Zlib::Deflate.deflate(File.read(File.join(root, 'scene.frag.in')), 9).unpack1('H*')
# The emitter lives in every generation. $s is the executed, whitespace-free body.
# Its only comment begins at the final #; no source files are read.
emitter = 'e=->(k){a=k*Math::PI/12;v=($s.split(35.chr)[0]+35.chr).chars;rows=Array.new(80){|y|Array.new(200){|x|xx=(x-99.5)/98;yy=(y-39.5)/38;rr=Math.sqrt(xx*xx+yy*yy);ang=Math.atan2(yy,xx);on=rr<0.97+0.025*Math.cos(3*ang+a)&&rr>0.40+0.035*Math.sin(2*ang+a);(on)?(v.shift||35.chr):32.chr}.join.rstrip};raise"capacity"unless(v.empty?);"n=0x%02x;eval$s=%%w"%k+33.chr+10.chr+rows.join(10.chr)+10.chr+33.chr+"*"+34.chr*2+10.chr};'
payload = emitter + 'if(ARGV[0]=="--shader");r=e.call(n);require"zlib";b=r.bytes;b+=[0]*(-b.size%4);w=b.each_slice(4).map{|x|"0x%08xu"%x.reverse.inject{_1<<8|_2}};g=Zlib::Inflate.inflate(["' + hex + '"].pack("H*"));ls=[0];r.bytes.each_with_index{|c,i|ls<<i+1if(c==10)};g=g.gsub("@NL@",ls.size.to_s).sub("@LINES@",ls.join(",")).sub("@LEN@",r.bytesize.to_s).sub("@COUNT@",w.size.to_s).sub("@WORDS@",w.join(",")).sub("@PHASE@",n.to_s).sub("@FONT@","' + FONT_HEX.scan(/.{8}/).map { '0x'+_1+'u' }.join(',') + '");print(g);else;print(e.call((n+1)%24));end;#'
raise 'unsafe whitespace or delimiter' if payload.match?(/[\s!\\]/)
# Bootstrap generation 0 using exactly the emitter embedded in every child.
scope = binding
scope.local_variable_set(:k, 0)
$s = payload
source = eval(emitter + 'e.call(0)', scope)
path = File.join(root,'public','ouroboros.rb')
File.write(path,source)
current = source
24.times do |i|
  output,status=Open3.capture2('ruby', stdin_data: current)
  raise "generation #{i} failed" unless status.success?
  raise "generation #{i} did not evolve" if output.b==current.b
  current=output
end
raise 'cycle does not close' unless current.b==source.b
frag,status=Open3.capture2('ruby','-','--shader',stdin_data:source)
raise 'shader generation failed' unless status.success?
vert="#version 300 es\nvoid main(){vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(p*2.-1.,0,1);}\n"
File.write(File.join(root,'app/shaders/ouroboros.vert'),vert)
File.write(File.join(root,'app/shaders/ouroboros.frag'),frag)
resolver=Glslkit::Resolvers::Hash.new('ouroboros.vert'=>vert,'ouroboros.frag'=>frag)
bundle=Glslkit::Bundle.build(resolver: resolver,name:'ouroboros',vertex:'ouroboros.vert',fragment:'ouroboros.frag',line_directives:false)
raise bundle.diagnostics.map(&:to_s).join("\n") unless bundle.ok?
File.write(File.join(root,'public','manifest.json'),JSON.pretty_generate(bundle.manifest))
viewer=File.read(File.join(root,'lib/frame-viewer.html.in'))
viewer=viewer.sub('__VERTEX__') { JSON.generate(vert) }.sub('__MANIFEST__') { JSON.generate(bundle.manifest) }
File.write(File.join(root,'public/frame-viewer.html'),viewer)
core_root=File.join(Gem.loaded_specs.fetch('glslkit').full_gem_path,'lib')
core=Dir[File.join(core_root,'**/*.rb')].to_h { |f| ['/core/lib/'+f.delete_prefix(core_root+'/'),File.read(f)] }
core_json=JSON.generate(core).gsub('</','<\\/')
File.write(File.join(root,'public/glslkit-sources.json'),core_json)
bootstrap=File.read(File.join(root,'public/ruby-bootstrap.txt'))
# Runtime comes from the already installed package; no CDN is required.
FileUtils.cp(File.expand_path('node_modules/@ruby/wasm-wasi/dist/browser.umd.js', root),File.join(root,'public/ruby-runtime.js'))
FileUtils.cp(File.expand_path('node_modules/@ruby/4.0-wasm-wasi/dist/ruby+stdlib.wasm', root),File.join(root,'public/ruby.wasm'))
page=File.read(File.join(root,'app/views/gallery/show.html.erb'))
replacements={
 '<%= glsl_script_tag "ouroboros.vert" %>' => "<script type=\"x-shader/x-vertex\" id=\"ouroboros-vert\">#{bundle.vertex.code}</script>",
 '<%= glsl_script_tag "ouroboros.frag" %>' => "<script type=\"x-shader/x-fragment\" id=\"ouroboros-frag\">#{bundle.fragment.code}</script>",
 '<%= glsl_manifest_tag %>' => "<script type=\"application/json\" id=\"glsl-manifest\">#{JSON.generate(bundle.manifest)}</script>",
 '<%= raw @core_json %>' => core_json,
 '<%= raw @bootstrap %>' => bootstrap,
 '<%= raw @source_json %>' => JSON.generate(source).gsub('</') { '<\\/' },
 '<link rel="stylesheet" href="/gallery.css">' => "<style>#{File.read(File.join(root,'public/gallery.css'))}</style>",
 '<script src="/ruby-runtime.js" defer></script>' => "<script>#{File.read(File.join(root,'public/ruby-runtime.js'))}</script>",
 '<script src="/gallery.js" defer></script>' => "<script>#{File.read(File.join(root,'public/gallery.js'))}</script>"
}
replacements.each { |from,to| page=page.sub(from) { to } }
page=page.gsub('href="/frame-viewer.html"','href="public/frame-viewer.html"')
# Embed the runtime for the file:// edition. Rails serves the same binary locally.
wasm=[File.binread(File.join(root,'public/ruby.wasm'))].pack('m0')
page=page.sub('</body>') { "<script type=\"application/octet-stream\" id=\"ruby-wasm-data\">#{wasm}</script></body>" }
File.write(File.join(root,'index.html'),page)
puts "Built #{source.bytesize} bytes; 24 executed Ruby generations close byte-exactly; glslkit validation passed."
