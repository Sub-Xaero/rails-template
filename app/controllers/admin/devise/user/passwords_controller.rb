# frozen_string_literal: true

class Admin::Devise::User::PasswordsController < Devise::PasswordsController
  layout "admin"

  # PUT /resource/password
  def update
    super
  end
end
