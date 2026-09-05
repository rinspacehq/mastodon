# frozen_string_literal: true

return if Rails.env.test? || ENV['RINSPACE_ASSETS_PRECOMPILE'] == 'true'

if ENV['RINSPACE_IDENTITY_STRICT'] != 'true'
  abort 'RINSPACE_IDENTITY_STRICT=true is mandatory for the Rinspace Mastodon runtime'
end

community_write = Rails.configuration.x.mastodon.rinspace_community_write_enabled
recommendations = Rails.configuration.x.mastodon.rinspace_recommendations_enabled
views = Rails.configuration.x.mastodon.rinspace_views_enabled
abort 'Recommendations and views require the governed community-write stage' if (recommendations || views) && !community_write

required = %w[OIDC_ENABLED OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET OIDC_REDIRECT_URI RINSPACE_CONTROL_PLANE_HMAC_KEY]
required.concat(%w[RINSPACE_MODERATION_ENDPOINT RINSPACE_MODERATION_HMAC_KEY]) if community_write
required.concat(%w[RINSPACE_GORSE_ENDPOINT RINSPACE_GORSE_API_KEY]) if recommendations
required << 'RINSPACE_VIEW_DEDUPE_HMAC_KEY' if views
missing = required.select { |name| ENV[name].to_s.blank? }
abort "Missing mandatory Rinspace identity settings: #{missing.join(', ')}" if missing.any?
abort 'Rinspace control-plane HMAC key must contain at least 32 bytes' if ENV['RINSPACE_CONTROL_PLANE_HMAC_KEY'].bytesize < 32

required_true = %w[OIDC_ENABLED OIDC_DISCOVERY OIDC_USE_PKCE OIDC_SEND_NONCE OMNIAUTH_ONLY ONE_CLICK_SSO_LOGIN]
not_enabled = required_true.reject { |name| ENV[name] == 'true' }
abort "Strict Rinspace OIDC settings must be true: #{not_enabled.join(', ')}" if not_enabled.any?
abort 'OIDC and control-plane credentials must be purpose-specific' if ENV['OIDC_CLIENT_SECRET'] == ENV['RINSPACE_CONTROL_PLANE_HMAC_KEY']
if community_write
  abort 'Rinspace moderation HMAC key must contain at least 32 bytes' if ENV['RINSPACE_MODERATION_HMAC_KEY'].bytesize < 32
  abort 'Rinspace service credentials must be purpose-specific' if [ENV['OIDC_CLIENT_SECRET'], ENV['RINSPACE_CONTROL_PLANE_HMAC_KEY']].include?(ENV['RINSPACE_MODERATION_HMAC_KEY'])
end
if recommendations
  abort 'Gorse and identity/moderation credentials must be purpose-specific' if [ENV['OIDC_CLIENT_SECRET'], ENV['RINSPACE_CONTROL_PLANE_HMAC_KEY'], ENV['RINSPACE_MODERATION_HMAC_KEY']].compact.include?(ENV['RINSPACE_GORSE_API_KEY'])
end
if views
  abort 'View dedupe HMAC key must contain at least 32 bytes' if ENV['RINSPACE_VIEW_DEDUPE_HMAC_KEY'].bytesize < 32
  abort 'View dedupe key must be purpose-specific' if [ENV['OIDC_CLIENT_SECRET'], ENV['RINSPACE_CONTROL_PLANE_HMAC_KEY'], ENV['RINSPACE_MODERATION_HMAC_KEY'], ENV['RINSPACE_GORSE_API_KEY']].compact.include?(ENV['RINSPACE_VIEW_DEDUPE_HMAC_KEY'])
end
