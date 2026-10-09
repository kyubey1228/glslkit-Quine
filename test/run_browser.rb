require 'json'
require 'open3'
require 'tmpdir'
require 'rbconfig'
require_relative '../config/boot'
root=File.expand_path('..',__dir__)
abort 'Build first: bundle exec ruby build.rb' unless File.file?(File.join(root,'index.html'))
load File.join(__dir__,'browser_check.rb')
chrome=ENV['CHROME']
chrome ||= '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' if RUBY_PLATFORM.include?('darwin')
chrome ||= ENV.fetch('PATH','').split(File::PATH_SEPARATOR).flat_map { |dir| %w[google-chrome chromium chromium-browser].map { File.join(dir,_1) } }.find { File.executable?(_1) }
abort 'Set CHROME to the Chrome/Chromium executable path' unless chrome && File.executable?(chrome)
Dir.mktmpdir('glslkit-quine-browser-') do |profile|
  command=[chrome,'--headless','--no-first-run','--no-default-browser-check',"--user-data-dir=#{profile}",'--window-size=1440,1000','--virtual-time-budget=15000','--dump-dom',"file://#{File.join(root,'tmp/browser-check.html')}"]
  html,log,status=Open3.capture3(*command)
  File.write(File.join(root,'tmp/browser.log'),log)
  report=html[/<pre[^>]*id="browser-check"[^>]*>(.*?)<\/pre>/m,1]
  abort "Browser check did not finish: #{html[/<small[^>]*id=\"status\"[^>]*>(.*?)<\/small>/m,1]}" unless status.success? && report
  checks=JSON.parse(report)
  File.write(File.join(root,'test/browser-result.json'),JSON.pretty_generate(checks)+"\n")
  checks.each { |name,ok| puts "#{ok ? 'PASS' : 'FAIL'} #{name}" }
  abort 'Browser verification failed' unless checks.values.all? { _1==true }
end
