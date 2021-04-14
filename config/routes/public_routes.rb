# frozen_string_literal: true

module PublicRoutes
  def self.extended(router)
    router.instance_exec do

      root to: "public#index"
    end
  end
end
