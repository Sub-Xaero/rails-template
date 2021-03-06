# frozen_string_literal: true

module UserRoutes
  def self.extended(router)
    router.instance_exec do
      devise_for :users, path: "/", class_name: "User"

    end
  end
end
