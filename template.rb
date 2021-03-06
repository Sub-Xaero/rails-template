# Add the current directory to the path Thor uses to look up files
def source_paths
  Array(super) + [File.expand_path(File.dirname(__FILE__))]
end

app_name = File.basename(Dir.getwd)
underscore_app_name = app_name.gsub("-", "_")

append_to_file ".gitignore", "/.idea\n" #  Ignore IDE Files
append_to_file ".gitignore", "/config/certs\n" # Ignore dev ssl certs

installing_hotwire = yes?("Do you want to setup Hotwire?")

gem 'rack-cors'
gem 'rack-attack'
gem 'brakeman'
gem 'devise'
gem 'friendly_id'
gem 'hashid-rails'
gem 'simple_form'
gem 'hotwire-rails' if installing_hotwire
gem 'sidekiq'
gem 'rubocop', require: false
gem 'rubocop-rails', require: false
gem 'rubocop-performance', require: false
gem "view_component", require: "view_component/engine"
gem_group :development, :test do
  gem 'dotenv-rails'
end
gem_group :development do
  gem "better_errors"
  gem "binding_of_caller"
end

# Remove unwanted default gems
gsub_file "Gemfile", /^# Use SCSS for stylesheets*$/, ''
gsub_file "Gemfile", /^gem\s+["']sass-rails["'].*$/, ''
gsub_file "Gemfile", /^# gem 'redis'.*$/, "gem 'redis'"
gsub_file "Gemfile", /^# gem 'image_processing'.*$/, "gem 'image_processing'"
gsub_file "Gemfile", /^# gem 'bcrypt'.*$/, "gem 'bcrypt'"

environment "config.active_job.queue_adapter = :sidekiq"

run "rvm gemset create #{app_name}"
run "echo '#{app_name}' > .ruby-gemset"

after_bundle do
  run "bundle install"
  run "yarn install"

  rails_command('turbo:install') if installing_hotwire
  generate('simple_form:install --bootstrap')

  generate('devise:install')
  generate('devise', "Admin::User")
  gsub_file "config/routes.rb", 'devise_for :users, class_name: "Admin::User"', 'devise_for :admin_users, class_name: "Admin::User"'
  generate('devise', "User")
  rails_command('webpacker:install:stimulus')

  run "yarn add bootstrap@next @popperjs/core@latest chokidar stimulus-library"
  insert_into_file "config/webpack/development.js", before: /^module\.exports\s\=\senvironment\.toWebpackConfig\(\)/ do
    <<-CODE
  const chokidar = require('chokidar')
  environment.config.devServer.before = (app, server) => {
  chokidar.watch([
    'config/locales/*.yml',
    'app/views/**/*.erb',
    'app/views/**/*.haml',
    'app/helpers/**/*.rb',
    'app/components/**/*.rb',
    'app/components/**/*.erb',
    'app/components/**/*.haml',
  ]).on('change', () => server.sockWrite(server.sockets, 'content-changed'))
  }

    CODE
  end

  gsub_file 'config/webpacker.yml', /^(\s+source_path\:\s)app\/javascript/, '\1app/assets'
  gsub_file 'config/webpacker.yml', /^(\s+)hmr\:\sfalse/, '\1hmr: true'
  gsub_file 'config/webpacker.yml', /^(\s+)https\:\sfalse/, '\1https: true'

  run "mv app/javascript/* app/assets/"
  run "rm -rf app/javascript"
  run "rm -rf app/assets/stylesheets"

  copy_file "app/assets/stylesheets/application.scss"
  copy_file "app/assets/stylesheets/utilities.scss"
  
  copy_file "app/assets/lib/utils/notifications.ts"
  copy_file "app/assets/lib/utils/stimulus.ts"
  copy_file "app/assets/lib/utils/typeguards.ts"

  empty_directory 'app/assets/stylesheets/config'
  copy_file "app/assets/stylesheets/config/bootstrap.scss"
  
  empty_directory "app/assets/stylesheets/components"
  copy_file "app/assets/stylesheets/components/buttons.scss"

  append_to_file "app/assets/packs/application.js", <<-CODE
  import "bootstrap";
  import "../stylesheets/application.scss";
  CODE

  environment <<-CONFIG
      config.generators do |g|
        g.helper false
        g.helpers false
        g.stylesheets false
      end
  CONFIG

  environment <<-CONFIG
    config.autoload_paths += [
      Rails.root.join("config", "routes"),
      Rails.root.join("lib"),
    ]
  CONFIG

  copy_file ".rubocop.yml"
  remove_file "config/routes.rb"
  copy_file "config/routes.rb"

  insert_into_file "config/routes.rb", before: "end" do
    <<-CODE
    extend AdminRoutes
    extend UserRoutes
    extend PublicRoutes
    CODE
  end

  empty_directory "config/routes"
  copy_file "config/routes/admin_routes.rb"
  copy_file "config/routes/user_routes.rb"
  copy_file "config/routes/public_routes.rb"

  copy_file "config/initializers/better_errors.rb"
  copy_file "config/initializers/cors.rb"
  copy_file "config/initializers/boolean.rb"
  copy_file "config/initializers/rack_attack.rb"

  copy_file "lib/tasks/integrity.rake"
  copy_file "lib/tasks/cleanup.rake"
  copy_file "lib/tasks/scheduled.rake"
  copy_file "lib/tasks/release.rake"

  copy_file "app/helpers/layout_helper.rb"
  
  gsub_file 'app/views/layouts/application.html.erb', "stylesheet_link_tag", "stylesheet_pack_tag"
  gsub_file 'app/views/layouts/application.html.erb', "data-turbolinks-track", "data-turbo-track"
  directory "app/views/devise", "app/views/devise"

  if installing_hotwire
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

    copy_file "app/controllers/turbo_controller.rb"
    
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
  copy_file "app/controllers/public_controller.rb"
  copy_file "app/controllers/admin/base_controller.rb"
  copy_file "app/controllers/admin/dashboard_controller.rb"

  copy_file "app/views/public/index.html.erb"
  copy_file "app/views/admin/dashboard/index.html.erb"

  create_file "docker-compose.yml" do
    <<-CODE
version: '3.4'

services:

  postgres:
    image: postgres:12-alpine
    restart: always
    volumes:
      - postgres:/var/lib/postgresql/data
    environment:
      - PSQL_HISTFILE=/root/log/.psql_history
      - POSTGRES_USER=#{app_name}
      - POSTGRES_PASSWORD=oiverb
      - POSTGRES_DB=#{underscore_app_name}_development
    ports:
      - '5432:5432'

  redis:
    image: redis:latest
    volumes:
      - redis:/data
    ports:
      - "6379:6379"


volumes:
  postgres:
  redis:
    CODE
  end

  # Generate SSL certificates for localhost
  inside('config') do
    empty_directory('certs')
    inside('certs') do
      run('minica -domains localhost')
    end
  end

  copy_file "Procfile.dev"
  copy_file ".foreman"
  create_file ".env.local" do
    <<-CODE
HOST=localhost:3000
DATABASE_URL=postgres://#{app_name}:oiverb@localhost:5432
    CODE
  end
  remove_file "app/channels/application_cable/connection.rb"
  copy_file "app/channels/application_cable/connection.rb"

  run "gem install shutup foreman"

end