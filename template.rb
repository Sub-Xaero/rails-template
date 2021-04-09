#  Ignore IDE Files
run "echo /.idea > .gitignore"

gem 'rack-cors'
gem 'devise'
gem 'simple_form'
gem 'hotwire-rails'
gem 'sidekiq'

gem_group :development do
  gem "better_errors"
end

# Remove unwanted default gems
gsub_file "Gemfile", /^# Use SCSS for stylesheets*$/,''
gsub_file "Gemfile", /^gem\s+["']sass-rails["'].*$/,''

environment "config.active_job.queue_adapter = :sidekiq"

after_bundle do 
  run "yarn install"

  rails_command('turbo:install')
  generate('simple_form:install:bootstrap')
  generate('devise:install')

  run "yarn add bootstrap@next @popperjs/core@latest chokidar stimulus-library"
  insert_into_file "config/webpack/development.js", before: /^module\.exports\s\=\senvironment\.toWebpackConfig\(\)/ do 
    <<-CODE
  const chokidar = require('chokidar')
  environment.config.devServer.before = (app, server) => {
  chokidar.watch([
    'config/locales/*.yml',
    'app/views/**/*.erb',
    'app/views/**/*.haml',
    'app/views/**/*.slim',
  ]).on('change', () => server.sockWrite(server.sockets, 'content-changed'))
  }

    CODE
  end
  
  gsub_file 'config/webpacker.yml', /^(\s+source_path\:\s)app\/javascript/, '\1app/assets'
  gsub_file 'config/webpacker.yml', /^(\s+)hmr\:\sfalse/, '\1hmr: true'
  
  run "mv app/javascript/* app/assets/"
  run "rm -rf app/javascript"
  
  append_to_file "app/assets/packs/application.js", <<-CODE
  import "bootstrap"'
  import "bootstrap/dist/css/bootstrap.min.css"
  CODE

  environment <<-CONFIG
      config.generators do |g|
        g.helper false
        g.helpers false
        g.stylesheets false
      end
  CONFIG

  initializer 'better_errors.rb', <<-CODE
    BetterErrors::Middleware.allow_ip! "0.0.0.0/0" if defined?(BetterErrors)
  CODE

  initializer 'cors.rb', <<-CODE
    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins(
          "https://localhost:3000",
        )
        resource "/packs/*", headers: :any, methods: [:get, :options, :head]
      end
    end
  CODE

  initializer 'boolean.rb', <<-CODE
  class TrueClass

    def yesno
      "Yes"
    end

  end

  class FalseClass

    def yesno
      "False"
    end

  end
  CODE

  rakefile("integrity.rake") do
    <<-TASK
  namespace :integrity do
  end
    TASK
  end

  rakefile("scheduled.rake") do
    <<-TASK
  namespace :scheduled do
    task hourly: [
    ]

    task daily: [
    ]

    task weekly: [
    ]
  end
    TASK
  end

  rakefile("release.rake") do
    <<-TASK
  namespace :release do
    task all: [
      "db:migrate",
    ]
  end
    TASK
  end


  # generate(:controller, "Public index")
  route "root to: 'public#index'"

  create_file "app/helpers/layout_helper.rb" do
  <<-CODE
  module LayoutHelper

    def standard_page_layout
      content_tag('div', class: 'container') do
        yield
      end
    end

    def page_title(title, meta_title: nil)
      content_for(:title, meta_title.present? ? meta_title : title)
      content_tag('h1', title)
    end

  end
  CODE
  end

  gsub_file 'app/views/layouts/application.html.erb' , "stylesheet_link_tag", "stylesheet_pack_tag"
  gsub_file 'app/views/layouts/application.html.erb' , "data-turbolinks-track", "data-turbo-track"


  # Config Devise for Turbo
  gsub_file "config/initializers/devise.rb", '# frozen_string_literal: true', ''
  prepend_to_file "config/initializers/devise.rb", <<-CODE
class TurboFailureApp < Devise::FailureApp
  def respond
    if request_format == :turbo_stream
      redirect
    else
      super
    end
  end

  def skip_format?
    %w(html turbo_stream */*).include? request_format.to_s
  end
end
  CODE

  gsub_file "config/initializers/devise.rb", "# config.parent_controller = 'DeviseController'", "config.parent_controller = 'TurboController'"
  gsub_file "config/initializers/devise.rb", "# config.navigational_formats = ['*/*', :html]", "config.navigational_formats = ['*/*', :html, :turbo_stream]"
  gsub_file "config/initializers/devise.rb", /config\.warden do.*?end/, <<-CODE
  config.warden do |manager|
    #   manager.intercept_401 = false
    #   manager.default_strategies(scope: :user).unshift :some_external_strategy
    manager.failure_app = TurboFailureApp
  end
  CODE


end