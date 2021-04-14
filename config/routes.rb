# frozen_string_literal: true

Rails.application.routes.draw do
  extend AdminRoutes
  extend UserRoutes
  extend PublicRoutes
end
  