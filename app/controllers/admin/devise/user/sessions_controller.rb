# frozen_string_literal: true

class Admin::Devise::User::SessionsController < Devise::SessionsController
  layout "admin"

  def new
    super
  end

  def create
    super
  end

  private

  def after_sign_in_path_for(_resource)
    admin_dashboard_path
  end

end
