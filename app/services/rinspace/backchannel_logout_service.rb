# frozen_string_literal: true

class Rinspace::BackchannelLogoutService < BaseService
  class InvalidTokenError < StandardError; end
  class UnavailableError < StandardError; end

  EVENT_URI = 'http://schemas.openid.net/event/backchannel-logout'
  MAX_TOKEN_BYTES = 8.kilobytes
  MAX_CLOCK_SKEW = 60.seconds
  MAX_EVENT_AGE = 5.minutes
  UUID_PATTERN = Rinspace::ParentSessionClient::UUID_PATTERN

  def initialize(decoder: Rinspace::BackchannelJwtDecoder.new, clock: Time)
    super()
    @decoder = decoder
    @clock = clock
  end

  def call(token)
    raise InvalidTokenError unless token.is_a?(String) && token.bytesize.between?(1, MAX_TOKEN_BYTES) && token.count('.') == 2

    claims = @decoder.decode(token)
    event = validate_claims!(claims)
    RinspaceLogoutEvent.transaction do
      RinspaceLogoutEvent.create!(event)
      SessionActivation.deactivate_rinspace_parent(issuer: event[:issuer], sid: event[:sid], version: event[:version])
    end
  rescue ActiveRecord::RecordNotUnique
    raise InvalidTokenError
  end

  private

  def validate_claims!(claims)
    now = @clock.now.utc
    issuer = ENV.fetch('OIDC_ISSUER', '').delete_suffix('/')
    audience = ENV.fetch('OIDC_CLIENT_ID', '')
    issued_at = Time.zone.at(Integer(claims['iat'], exception: true)).utc
    expires_at = Time.zone.at(Integer(claims['exp'], exception: true)).utc
    sid = claims['sid'].to_s
    version = Integer(claims['rin_session_version'], exception: true)
    events = claims['events']
    valid = issuer.present? && audience.present? && claims['iss'].to_s.delete_suffix('/') == issuer && claims['aud'] == audience &&
      claims['sub'].present? && claims['jti'].to_s.bytesize.between?(16, 200) && UUID_PATTERN.match?(sid) && version.positive? &&
      events == { EVENT_URI => {} } && !claims.key?('nonce') && issued_at <= now + MAX_CLOCK_SKEW && issued_at >= now - MAX_EVENT_AGE &&
      expires_at > now && expires_at <= now + MAX_EVENT_AGE + MAX_CLOCK_SKEW
    raise InvalidTokenError unless valid

    { jti: claims['jti'], issuer:, sid:, version:, expires_at: }
  rescue ArgumentError, TypeError
    raise InvalidTokenError
  end
end
