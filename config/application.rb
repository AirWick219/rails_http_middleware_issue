require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsHttpMiddlewareIssue
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    #
    config.middleware.insert_before Rack::Sendfile, ActionDispatch::DebugLocks

    ActiveSupport::Reloader.before_class_unload do
      puts 'Before class unload'
    end

    ActiveSupport::Reloader.after_class_unload do
      puts 'After class unload'
    end

    ActiveSupport::Reloader.to_run do
      puts 'Reloading'
    end
    ActiveSupport::Reloader.to_complete do
      puts 'DONE Reloading'
    end
  end
end
