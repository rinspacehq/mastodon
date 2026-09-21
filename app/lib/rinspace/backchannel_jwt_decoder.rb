# frozen_string_literal: true

require 'json'
require 'jwt'
require 'net/http'
require 'openssl'

class Rinspace::BackchannelJwtDecoder
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  def decode(token)
    claims, = JWT.decode(
      token,
      nil,
      true,
      algorithms: ['RS256'],
      jwks: jwks,
      verify_expiration: false,
      verify_iat: false,
      verify_aud: false,
      verify_iss: false
    )
    claims
  rescue JWT::DecodeError, JSON::ParserError
    raise Rinspace::BackchannelLogoutService::InvalidTokenError
  end

  private

  def jwks
    Rails.cache.fetch('rinspace/backchannel-jwks-v1', expires_in: 5.minutes) do
      endpoint = URI.parse(ENV.fetch('OIDC_JWKS_URI', ''))
      raise Rinspace::BackchannelLogoutService::UnavailableError unless endpoint.is_a?(URI::HTTPS) && endpoint.host.present? && endpoint.userinfo.nil?

      response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(endpoint.request_uri, 'Accept' => 'application/json'))
      end
      raise Rinspace::BackchannelLogoutService::UnavailableError unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  rescue URI::InvalidURIError, KeyError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise Rinspace::BackchannelLogoutService::UnavailableError
  end
end
