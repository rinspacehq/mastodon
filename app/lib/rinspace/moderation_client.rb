# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'securerandom'
require 'json'

class Rinspace::ModerationClient
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 8

  def review_text!(subject:, target_type:, target_id:, title:, text:)
    endpoint = URI.parse(ENV.fetch('RINSPACE_MODERATION_ENDPOINT', ''))
    key = ENV.fetch('RINSPACE_MODERATION_HMAC_KEY', '')
    validate_configuration!(endpoint, key)

    body = JSON.generate(subject:, targetType: target_type, targetId: target_id, title:, text:)
    request = Net::HTTP::Post.new(endpoint.request_uri, 'Content-Type' => 'application/json')
    request.body = body
    sign!(request, endpoint, key, body)
    response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: endpoint.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end
    raise Rinspace::ModerationUnavailableError unless response.is_a?(Net::HTTPSuccess)

    decision = JSON.parse(response.body).fetch('decision', 'disabled')
    return true if decision == 'pass'
    raise Rinspace::ModerationRejectedError if %w[review block].include?(decision)

    raise Rinspace::ModerationUnavailableError
  rescue URI::InvalidURIError, JSON::ParserError, KeyError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise Rinspace::ModerationUnavailableError
  end

  private

  def validate_configuration!(endpoint, key)
    valid = %w[http https].include?(endpoint.scheme) && endpoint.host.present? && endpoint.userinfo.nil? && endpoint.fragment.nil? &&
      endpoint.path.end_with?('/internal/v1/mastodon/moderation/text') && key.bytesize >= 32
    raise Rinspace::ModerationUnavailableError unless valid
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
