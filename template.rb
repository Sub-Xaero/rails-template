dirname = File.basename(Dir.getwd)

#  Ignore IDE Files
run "echo /.idea > .gitignore"
# Ignore dev ssl certs
run "echo /config/certs > .gitignore"

gem 'rack-cors'
gem 'devise'
gem 'simple_form'
gem 'hotwire-rails'
gem 'sidekiq'
gem 'rubocop'
gem 'rubocop-rails'
gem "view_component", require: "view_component/engine"

gem_group :development, :test do
  gem 'dotenv-rails'
end

gem_group :development do
  gem "better_errors"
end

# Remove unwanted default gems
gsub_file "Gemfile", /^# Use SCSS for stylesheets*$/, ''
gsub_file "Gemfile", /^gem\s+["']sass-rails["'].*$/, ''
gsub_file "Gemfile", /^# gem 'redis'.*$/, "gem 'redis'"
gsub_file "Gemfile", /^# gem 'image_processing'.*$/, "gem 'image_processing'"
gsub_file "Gemfile", /^# gem 'bcrypt'.*$/, "gem 'bcrypt'"

environment "config.active_job.queue_adapter = :sidekiq"

after_bundle do
  run "bundle install"
  run "yarn install"

  rails_command('turbo:install')
  generate('simple_form:install:bootstrap')

  generate('devise:install')
  generate('devise', "Admin::User")
  gsub_file "config/routes.rb", 'devise_for :users, class_name: "Admin::User"', 'devise_for :admin_users, class_name: "Admin::User"'
  generate('devise', "User")

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

  run "mv app/javascript/* app/assets/"
  run "rm -rf app/javascript"
  run "rm app/assets/stylesheets/application.css"

  inside('app/assets/stylesheets') do
    empty_directory('config')
    create_file "application.scss" do
      <<-CODE
      @import "./config/bootstrap";
      CODE
    end
    inside('config') do
      create_file "bootstrap.scss" do
        <<-CODE
@import "~bootstrap/scss/functions";
@import "~bootstrap/scss/variables";
@import "~bootstrap/scss/mixins";
@import "~bootstrap/scss/utilities";

// Layout & components
@import "~bootstrap/scss/root";
@import "~bootstrap/scss/reboot";
@import "~bootstrap/scss/type";
@import "~bootstrap/scss/images";
@import "~bootstrap/scss/containers";
@import "~bootstrap/scss/grid";
@import "~bootstrap/scss/tables";
@import "~bootstrap/scss/forms";
@import "~bootstrap/scss/buttons";
@import "~bootstrap/scss/transitions";
@import "~bootstrap/scss/dropdown";
@import "~bootstrap/scss/button-group";
@import "~bootstrap/scss/nav";
@import "~bootstrap/scss/navbar";
@import "~bootstrap/scss/card";
@import "~bootstrap/scss/accordion";
@import "~bootstrap/scss/breadcrumb";
@import "~bootstrap/scss/pagination";
@import "~bootstrap/scss/badge";
@import "~bootstrap/scss/alert";
@import "~bootstrap/scss/progress";
@import "~bootstrap/scss/list-group";
@import "~bootstrap/scss/close";
@import "~bootstrap/scss/toasts";
@import "~bootstrap/scss/modal";
@import "~bootstrap/scss/tooltip";
@import "~bootstrap/scss/popover";
@import "~bootstrap/scss/carousel";
@import "~bootstrap/scss/spinners";
@import "~bootstrap/scss/offcanvas";

// Helpers
@import "~bootstrap/scss/helpers";

// Utilities
@import "~bootstrap/scss/utilities/api";
        CODE
      end
    end
  end


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

  rakefile("cleanup.rake") do
    <<-TASK
  namespace :cleanup do
    desc "Cleans up orphaned ActiveStorage::Blob objects"
    task active_storage_orphans: :environment do
      ActiveStorage::Blob.unattached.where("active_storage_blobs.created_at < ?", 1.day.ago).find_each(&:purge_later)
    end
  end
    TASK
  end

  rakefile("scheduled.rake") do
    <<-TASK
  namespace :scheduled do
    task hourly: [
    ]

    task daily: [
      "cleanup:active_storage_orphans"
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

  generate(:controller, "Public index")
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

  gsub_file 'app/views/layouts/application.html.erb', "stylesheet_link_tag", "stylesheet_pack_tag"
  gsub_file 'app/views/layouts/application.html.erb', "data-turbolinks-track", "data-turbo-track"

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

  create_file 'app/controllers/turbo_controller.rb', <<-CODE
class TurboController < ApplicationController
  class Responder < ActionController::Responder
    def to_turbo_stream
      controller.render(options.merge(formats: :html))
    rescue ActionView::MissingTemplate => error
      if get?
        raise error
      elsif has_errors? && default_action
        render rendering_options.merge(formats: :html, status: :unprocessable_entity)
      else
        redirect_to navigation_location, status: :see_other
      end
    end
  end

  self.responder = Responder
  respond_to :html, :turbo_stream
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
      - POSTGRES_USER=#{dirname}
      - POSTGRES_PASSWORD=oiverb
      - POSTGRES_DB=#{dirname}_development
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

  create_file "Procfile.dev" do
    <<-CODE
web: shutup && bundle exec rails server -p 3000 -b "ssl://0.0.0.0:3000?key=./config/certs/localhost/key.pem&cert=./config/certs/localhost/cert.pem"
webpack-dev-server: bin/webpack-dev-server
docker-services: docker-compose up
    CODE
  end

  create_file ".foreman" do
    <<-CODE
procfile: Procfile.dev
    CODE
  end

  create_file ".env.local" do
    <<-CODE
HOST=localhost:3000
DATABASE_URL=postgres://#{dirname}:oiverb@localhost:5432
    CODE
  end

  insert_into_file "app/channels/application_cable/connection.rb", after: 'class Connection < ActionCable::Connection::Base' do
    <<-CODE
    identified_by :current_user, :current_admin_user

    def connect
      self.current_user = find_verified_user
      self.current_admin_user = find_verified_admin_user
      reject_unauthorized_connection if current_admin_user.blank? && current_user.blank?

      logger.add_tags "ActionCable", (current_admin_user || current_user).email
    end

    protected

    # this checks whether a user is authenticated with devise
    def find_verified_user
      env["warden"].user(:user)
    rescue
      nil
    end

    def find_verified_admin_user
      env["warden"].user(:admin_user)
    rescue
      nil
    end
    CODE
  end
  generate('webpacker:install:stimulus')
end