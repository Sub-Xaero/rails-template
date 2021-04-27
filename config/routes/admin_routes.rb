# frozen_string_literal: true

require "sidekiq/web"

module AdminRoutes
  def self.extended(router)
    router.instance_exec do
      namespace :admin do
        devise_for :users,
                   path: "/",
                   class_name: "Admin::User",
                   only: %i[ sessions passwords unlocks],
                   controllers: {
                     passwords: "admin/devise/user/passwords",
                     sessions: "admin/devise/user/sessions",
                     unlocks: "admin/devise/user/unlocks"
                   }

        get "dashboard", to: "dashboard#index"

        authenticate :admin_user do
          mount Sidekiq::Web => "/sidekiq"
        end
      end
    end
  end
end
