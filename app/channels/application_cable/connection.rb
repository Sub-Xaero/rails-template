# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
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
    rescue StandardError
      nil
    end

    def find_verified_admin_user
      env["warden"].user(:admin_user)
    rescue StandardError
      nil
    end

  end
end
  