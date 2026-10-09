require_relative 'boot'
require 'rails'
require 'action_controller/railtie'
require 'glslkit/rails'
module OuroborosGallery
  class Application < Rails::Application
    config.load_defaults 7.1
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = ENV.fetch('SECRET_KEY_BASE', 'ouroboros-local-artwork-' * 8)
    config.glslkit.paths = ['app/shaders']
    config.glslkit.minify = Rails.env.production?
    config.glslkit.line_directives = !Rails.env.production?
    config.hosts << '127.0.0.1'
    config.hosts << 'localhost'
  end
end
