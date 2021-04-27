# frozen_string_literal: true

class Admin::Devise::User::UnlocksController < Devise::UnlocksController
  layout "admin"

  def show
    super
  end
end
