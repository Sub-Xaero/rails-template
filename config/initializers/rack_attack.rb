# frozen_string_literal: true

class Rack::Attack
    class Request < ::Rack::Request
      def remote_ip
        @remote_ip ||= (env["HTTP_CF_CONNECTING_IP"] || env["action_dispatch.remote_ip"] || ip).to_s
      end
  
      def allowed_ip?
        allowed_ips = ["127.0.0.1", "::1"]
        allowed_ips.include?(remote_ip)
      end
  
      def sign_in_attempt?
        # TODO: Set login paths
        post? && (path == "admin/sign_in" || path == "sign_in")
      end
  
      def sign_in_params
        # TODO: Set login params for all configured user types
        params["admin_user"] || params["user"] || {}
      end
    end
  
    # ensure access
    safelist("allow from localhost and known good", &:allowed_ip?)
  
    # block obvious nonsense
    blocklist("fail2ban") do |req|
      Rack::Attack::Fail2Ban.filter("fail2ban-#{req.remote_ip}", maxretry: 1, findtime: 1.day, bantime: 1.day) do
        CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
          req.path.include?("/etc/passwd") ||
          req.path.include?("wp-admin") ||
          req.path.include?("wp-login") ||
          /\S+\.php/.match?(req.path)
      end
    end
  
    ### Configure Cache ###
  
    # If you don't want to use Rails.cache (Rack::Attack's default), then
    # configure it here.
    #
    # Note: The store is only used for throttling (not block-listing and
    # safe-listing). It must implement .increment and .write like
    # ActiveSupport::Cache::Store
  
    # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  
    ### Throttle Spam Clients ###
  
    # If any single client IP is making tons of requests, then they're
    # probably malicious or a poorly-configured scraper. Either way, they
    # don't deserve to hog all of the app server's CPU. Cut them off!
    #
    # Note: If you're serving assets through rack, those requests may be
    # counted by rack-attack and this throttle may be activated too
    # quickly. If so, enable the condition to exclude them from tracking.
  
    # Throttle all requests by IP (60rpm)
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:req/ip:#{req.ip}"
    throttle("req/ip", limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?("/packs")
    end
  
    ### Prevent Brute-Force Login Attacks ###
  
    # The most common brute-force login attack is a brute-force password
    # attack where an attacker simply tries a large number of emails and
    # passwords to see if any credentials match.
    #
    # Another common method of attack is to use a swarm of computers with
    # different IPs to try brute-forcing a password for a specific account.
  
    # Throttle POST requests to sign_in paths by IP address
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:logins/ip:#{req.ip}"
    throttle("logins/ip", limit: 10, period: 30.seconds) do |req|
      req.ip if req.sign_in_attempt?
    end
  
    # Throttle POST requests to /login by email param
    #
    # Key: "rack::attack:#{Time.now.to_i/:period}:logins/email:#{req.email}"
    #
    # Note: This creates a problem where a malicious user could intentionally
    # throttle logins for another user and force their login requests to be
    # denied, but that's not very common and shouldn't happen to you. (Knock
    # on wood!)
    throttle("logins/email", limit: 10, period: 30.seconds) do |req|
      if req.sign_in_attempt?
        # return the email if present, nil otherwise
        req.sign_in_params["email"].presence
      end
    end
  
    ### Custom Throttle Response ###
  
    # By default, Rack::Attack returns an HTTP 429 for throttled responses,
    # which is just fine.
    #
    # If you want to return 503 so that the attacker might be fooled into
    # believing that they've successfully broken your app (or you just want to
    # customize the response), then uncomment these lines.
    # self.throttled_response = lambda do |env|
    #  [ 503,  # status
    #    {},   # headers
    #    ['']] # body
    # end
  end