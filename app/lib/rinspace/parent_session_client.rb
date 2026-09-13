# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'securerandom'
require 'cgi'

class Rinspace::ParentSessionClient
  class InactiveError < StandardError; end
  class UnavailableError < StandardError; end

  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3
  SESSION_LIFETIME_SECONDS = 12.hours.to_i
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  def initialize(http_request: nil, clock: Time, nonce: SecureRandom)
    @http_request = http_request || method(:perform_request)
    @clock = clock
    @nonce = nonce
  end

  def assert_active!(issuer:, uid:, sid:, version:, runtime: 'mastodon')
    validate_parent!(issuer:, uid:, sid:, version:)
    raise InactiveError unless %w[mastodon mastodon-api mastodon-streaming mastodon-push].include?(runtime)
    result = request_json(
      "/internal/v1/identity/sessions/#{sid}/status",
      sid:, uid:, issuedVersion: version, audience:
    )
    raise InactiveError unless result['active'] == true && result['currentVersion'].to_i >= version.to_i

    true
  end

  def create_binding!(issuer:, uid:, sid:, version:)
    validate_parent!(issuer:, uid:, sid:, version:)
    result = request_json(
      '/internal/v1/identity/runtime-bindings',
      operation: 'create', uid:, sid:, runtime: 'mastodon', lifetimeSeconds: SESSION_LIFETIME_SECONDS, audience:
    )
    raise InactiveError unless result['id'].present? && result['sid'] == sid && result['runtime'] == 'mastodon' && result['issuedVersion'].to_i >= version.to_i

    result
  end

  def activate_binding!(uid:, binding_id:, runtime_ref:, issued_version:)
    request_json(
      '/internal/v1/identity/runtime-bindings',
      operation: 'activate', uid:, runtime: 'mastodon', bindingId: binding_id, runtimeRef: runtime_ref.to_s,
      issuedVersion: issued_version, audience:, expected_status: Net::HTTPNoContent
    )
    true
  end

  def fail_binding!(uid:, binding_id:)
    request_json(
      '/internal/v1/identity/runtime-bindings',
      operation: 'fail', uid:, runtime: 'mastodon', bindingId: binding_id, audience:, expected_status: Net::HTTPNoContent
    )
    true
  end

  def revoke_parent!(uid:, sid:, binding_id:)
    request_json(
      '/internal/v1/identity/runtime-bindings',
      operation: 'revoke', uid:, sid:, runtime: 'mastodon', bindingId: binding_id, audience:, expected_status: Net::HTTPNoContent
    )
    true
  end

  def account_status!(uid:)
	result = request_json(
	  "/internal/v1/identity/accounts/#{CGI.escapeURIComponent(uid.to_s)}/status",
	  uid:, audience:
	)
	raise InactiveError unless result['uid'] == uid && result['status'] == 'active' && result['credentialEpoch'].to_i.positive?

	result
  end

  private

  def validate_parent!(issuer:, uid:, sid:, version:)
    expected_issuer = ENV.fetch('OIDC_ISSUER', '').delete_suffix('/')
    valid = expected_issuer.present? && issuer.to_s.delete_suffix('/') == expected_issuer && uid.present? && UUID_PATTERN.match?(sid.to_s) && version.to_i.positive?
    raise InactiveError unless valid
  end

  def request_json(path, body)
    expected_status = body.delete(:expected_status) || Net::HTTPOK
    endpoint, key, service_id, key_id = configuration(path)
    encoded = JSON.generate(body)
    request = Net::HTTP::Post.new(endpoint.request_uri, 'Content-Type' => 'application/json')
    request.body = encoded
    sign!(request, endpoint, key, service_id, key_id, encoded)
    response = @http_request.call(endpoint, request)
    raise InactiveError if response.is_a?(Net::HTTPUnauthorized) || response.is_a?(Net::HTTPForbidden) || response.is_a?(Net::HTTPConflict)
    raise UnavailableError unless response.is_a?(expected_status)
    return {} if expected_status == Net::HTTPNoContent

    JSON.parse(response.body)
  rescue URI::InvalidURIError, JSON::ParserError, KeyError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise UnavailableError
  end

  def configuration(path)
    base = URI.parse(ENV.fetch('RINSPACE_IDENTITY_INTERNAL_URL', ''))
    key = ENV.fetch('RINSPACE_IDENTITY_SERVICE_SECRET', '')
    service_id = ENV.fetch('RINSPACE_IDENTITY_SERVICE_ID', '')
    key_id = ENV.fetch('RINSPACE_IDENTITY_SERVICE_KEY_ID', '')
    valid = %w[http https].include?(base.scheme) && base.host.present? && base.userinfo.nil? && base.fragment.nil? &&
      base.query.nil? && key.bytesize >= 32 && service_id.present? && key_id.match?(/\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/) && audience.present?
    raise UnavailableError unless valid

    endpoint = base.dup
    endpoint.path = "#{base.path.to_s.delete_suffix('/')}#{path}"
    [endpoint, key, service_id, key_id]
  end

  def audience
    ENV.fetch('RINSPACE_IDENTITY_AUDIENCE', '')
  end

  def sign!(request, endpoint, key, service_id, key_id, body)
    timestamp = @clock.now.to_i.to_s
    request_nonce = @nonce.urlsafe_base64(18, false)
    body_hash = OpenSSL::Digest::SHA256.hexdigest(body)
    canonical = ['POST', endpoint.request_uri, timestamp, request_nonce, body_hash, key_id].join("\n")
    request['X-Rin-Service'] = service_id
    request['X-Rin-Key-ID'] = key_id
    request['X-Rin-Timestamp'] = timestamp
    request['X-Rin-Nonce'] = request_nonce
    request['X-Rin-Signature'] = OpenSSL::HMAC.hexdigest('SHA256', key, canonical)
  end

  def perform_request(endpoint, request)
    Net::HTTP.start(
      endpoint.host,
      endpoint.port,
      use_ssl: endpoint.scheme == 'https',
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    ) { |http| http.request(request) }
  end
end
