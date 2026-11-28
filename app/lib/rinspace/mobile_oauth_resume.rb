# frozen_string_literal: true

module Rinspace
  # Carry a single, short-lived OAuth intent through the existing product login.
  # The browser can return a nonce; only the server supplies the OAuth location.
  module MobileOAuthResume
    REDIRECT_URI = 'com.rinspace.app://oauth'
    SCOPES = %w(read:accounts read:statuses write:media write:statuses).freeze
    PARAMETERS = %w(client_id redirect_uri response_type scope state code_challenge code_challenge_method).freeze
    SESSION_KEY = 'rinspace_mobile_oauth'
    MARKER = 'rinspace_mobile_oauth'

    module_function

    def stage(session, query)
      params = query.slice(*PARAMETERS)
      return unless params.size == PARAMETERS.size && params.values.all?(String)
      return unless valid_request?(params)

      application = Doorkeeper::Application.find_by(uid: params['client_id'])
      return unless application&.redirect_uri == REDIRECT_URI && application.scopes.to_a.sort == SCOPES

      nonce = SecureRandom.hex(24)
      session[SESSION_KEY] = {
        'nonce' => nonce,
        'path' => "/oauth/authorize?#{params.to_query}",
        'expires_at' => 5.minutes.from_now.to_i,
      }
      "/?world=inner&#{MARKER}=#{nonce}"
    end

    def take(session, nonce)
      return unless nonce.is_a?(String) && nonce.match?(/\A[0-9a-f]{48}\z/)

      pending = session[SESSION_KEY]
      return if pending.nil? || pending.fetch('expires_at') <= Time.current.to_i
      return unless ActiveSupport::SecurityUtils.secure_compare(pending.fetch('nonce'), nonce)

      session.delete(SESSION_KEY).fetch('path')
    end

    def valid_request?(params)
      params['client_id'].match?(/\A[A-Za-z0-9_-]{16,128}\z/) &&
        params['redirect_uri'] == REDIRECT_URI &&
        params['response_type'] == 'code' &&
        params['scope'].bytesize <= 128 && params['scope'].split.sort == SCOPES &&
        params['state'].match?(/\A[A-Za-z0-9_-]{16,128}\z/) &&
        params['code_challenge_method'] == 'S256' &&
        params['code_challenge'].match?(/\A[A-Za-z0-9_-]{43}\z/)
    end
    private_class_method :valid_request?
  end
end
