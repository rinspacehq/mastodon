# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'securerandom'

module Rinspace
  class SearchEventClient
    Result = Data.define(:status_code, :error_code) do
      def success?
        status_code&.between?(200, 299)
      end

      def permanent_failure?
        status_code&.between?(400, 499)
      end
    end

    def deliver(event)
      endpoint = URI.parse(ENV.fetch('RINSPACE_SEARCH_EVENT_ENDPOINT', ''))
      key = ENV.fetch('RINSPACE_SEARCH_EVENT_HMAC_KEY', '')
      validate!(endpoint, key)
      body = JSON.generate(
        eventId: event.event_id, objectKind: 'tweet', objectId: event.status_id.to_s,
        action: event.action, canonicalUrl: event.canonical_url,
        publicVersion: event.public_version, occurredAt: event.occurred_at.utc.iso8601(6)
      )
      request = Net::HTTP::Post.new(endpoint.request_uri, 'Content-Type' => 'application/json', 'Idempotency-Key' => event.event_id)
      request.body = body
      sign!(request, endpoint, key, body)
      response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: endpoint.scheme == 'https', open_timeout: 2, read_timeout: 8) { |http| http.request(request) }
      Result.new(status_code: response.code.to_i, error_code: response.is_a?(Net::HTTPSuccess) ? '' : 'upstream_status')
    rescue URI::InvalidURIError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      Result.new(status_code: nil, error_code: 'transport_error')
    end

    private

    def validate!(endpoint, key)
      valid = %w[http https].include?(endpoint.scheme) && endpoint.host.present? && endpoint.userinfo.nil? && endpoint.fragment.nil? &&
        endpoint.path == '/internal/v1/search/events' && key.bytesize >= 32
      raise URI::InvalidURIError unless valid
    end

    def sign!(request, endpoint, key, body)
      timestamp = Time.now.to_i.to_s
      nonce = SecureRandom.urlsafe_base64(18, false)
      body_hash = OpenSSL::Digest::SHA256.hexdigest(body)
      canonical = ['POST', endpoint.request_uri, timestamp, nonce, body_hash].join("\n")
      request['X-Rin-Service'] = 'rinspace-mastodon'
      request['X-Rin-Timestamp'] = timestamp
      request['X-Rin-Nonce'] = nonce
      request['X-Rin-Signature'] = OpenSSL::HMAC.hexdigest('SHA256', key, canonical)
    end
  end
end
