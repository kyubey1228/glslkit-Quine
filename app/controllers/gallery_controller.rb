class GalleryController < ActionController::Base
  def show
    @core_json = File.read(Rails.root.join('public/glslkit-sources.json'))
    @bootstrap = File.read(Rails.root.join('public/ruby-bootstrap.txt'))
    @source_json = JSON.generate(File.binread(Rails.root.join('public/ouroboros.rb'))).gsub('</', '<\\/')
  end
end
