# frozen_string_literal: true

require 'openssl'

module Rinspace
  module ServiceRequest
    MAX_SKEW = 2.minutes
    NONCE_TTL = 5.minutes

    module_function

    def verify!(request)
      service = request.headers['X-Rin-Service'].to_s
      timestamp = Integer(request.headers['X-Rin-Timestamp'], exception: false)
      nonce = request.headers['X-Rin-Nonce'].to_s
      provided = request.headers['X-Rin-Signature'].to_s
      key = ENV.fetch('RINSPACE_CONTROL_PLANE_HMAC_KEY', '')
      raise Mastodon::NotPermittedError unless service == 'rin-control-plane' && key.bytesize >= 32
      raise Mastodon::NotPermittedError unless timestamp && (Time.now.to_i - timestamp).abs <= MAX_SKEW.to_i
      raise Mastodon::NotPermittedError unless nonce.length.between?(16, 128) && provided.match?(/\A[0-9a-f]{64}\z/i)

      body_hash = OpenSSL::Digest::SHA256.hexdigest(request.raw_post)
      canonical = [request.request_method, request.fullpath, timestamp, nonce, body_hash]
      key_id = request.headers['X-Rin-Key-ID'].to_s
      canonical << key_id if key_id.present?
      expected = OpenSSL::HMAC.hexdigest('SHA256', key, canonical.join("\n"))
      raise Mastodon::NotPermittedError unless ActiveSupport::SecurityUtils.secure_compare(provided.downcase, expected)

      RinspaceServiceNonce.where(expires_at: ...Time.current).delete_all
      used = RinspaceServiceNonce.create(service:, nonce:, expires_at: NONCE_TTL.from_now)
      raise Mastodon::NotPermittedError unless used.persisted?

      service
    rescue ActiveRecord::RecordNotUnique
      raise Mastodon::NotPermittedError
    end
  end
end
