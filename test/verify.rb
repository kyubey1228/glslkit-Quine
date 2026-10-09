require 'open3'
ROOT = File.expand_path('..', __dir__)
require File.join(ROOT, 'config/environment')
require 'minitest/autorun'
class OuroborosTest < Minitest::Test
  def source
    File.binread(File.join(ROOT, 'public/ouroboros.rb'))
  end
  def test_periodic_quine_executes_24_distinct_generations_without_source_file_access
    current=source
    seen=[]
    24.times do |phase|
      assert_equal phase, current[/n=0x(\h+)/,1].to_i(16)
      refute_includes seen,current
      seen<<current
      output,status=Open3.capture2('ruby',stdin_data:current)
      assert status.success?
      refute_equal current,output.b
      current=output.b
    end
    assert_equal source,current
    assert_operator seen.map { _1.lines[1..80].join.gsub(/\S/,'#') }.uniq.size,:>,20
  end
  def test_shader_embeds_exact_source_and_survives_glslkit_minification
    fragment, status = Open3.capture2('ruby', '-', '--shader', stdin_data: source)
    assert status.success?
    refute_match(/@[A-Z]+@/,fragment)
    [fragment, Glslkit::Minifier.minify(fragment)].each do |code|
      blocks=code.scan(/const uvec4 SRC\d+\[(\d+)\]=uvec4\[\]\((.*?)\);/m)
      refute_empty blocks
      assert blocks.all? { |size,_| size.to_i<=256 }
      assert blocks.all? { |size,data| data.scan(/uvec4\(/).size==size.to_i }
      words=blocks.flat_map { |_,data| data.scan(/uvec4\(([^)]*)\)/).flatten.flat_map { |v| v.split(',').map { _1.delete_suffix('u').to_i(16) } } }
      assert_equal source, words.pack('V*').byteslice(0, source.bytesize)
    end
    assert_equal File.binread(File.join(ROOT,'app/shaders/ouroboros.frag')), fragment.b
  end
  def test_rails_serves_glslkit_compiled_shaders_and_manifest
    session=ActionDispatch::Integration::Session.new(Rails.application)
    session.host! 'localhost'
    session.get('/')
    assert_equal 200, session.response.status
    html=session.response.body
    assert_includes html, 'id="ouroboros-frag"'
    assert_includes html, 'href="/frame-viewer.html"'
    session.get('/frame-viewer.html')
    assert_equal 200,session.response.status
    assert_includes session.response.body.b,'frame.frag を選ぶ'.b
    refute_match(/__(?:VERTEX|MANIFEST)__/,session.response.body)
    manifest=JSON.parse(html[/<script[^>]*id="glsl-manifest"[^>]*>(.*?)<\/script>/m,1])
    uniforms=manifest.fetch('programs').fetch('ouroboros').fetch('uniforms')
    assert_equal %w[u_data u_mode u_pointer u_resolution], uniforms.map { _1.fetch('name') }.sort
    assert_equal 'uniform2fv', uniforms.find { _1['name']=='u_resolution' }.fetch('setter')
    session.get('/ouroboros.rb')
    assert_equal 200, session.response.status
    assert_equal source, session.response.body.b
  end
end
