# frozen_string_literal: true

# Saves a narrowly validated inner-world product URL before handing the request
# to Devise/OmniAuth. The temporary redirect deliberately preserves POST, so
# OmniAuth still owns request validation, state, nonce and PKCE generation.
class Auth::RinspaceSsoController < ApplicationController
  PRODUCT_PATH = %r{\A/(?:\z|home(?:/|\z)|timelines(?:/|\z)|deck(?:/|\z)|getting-started(?:/|\z)|conversations(?:/|\z)|public(?:/|\z)|tags(?:/|\z)|lists(?:/|\z)|notifications(?:/|\z)|favourites(?:/|\z)|bookmarks(?:/|\z)|pinned(?:/|\z)|directory(?:/|\z)|explore(?:/|\z)|publish(?:/|\z)|profile(?:/|\z)|@[A-Za-z0-9_@.-]+(?:/|\z)|accounts(?:/|\z)|collections(?:/|\z)|statuses(?:/|\z)|follow_requests(?:/|\z)|blocks(?:/|\z)|domain_blocks(?:/|\z)|followed_tags(?:/|\z)|mutes(?:/|\z)|settings(?:/|\z)|search(?:/|\z)|web(?:/|\z)|media(?:/|\z)|polls(?:/|\z)|links(?:/|\z)|keyboard-shortcuts(?:/|\z)|overview(?:/|\z)|relationships(?:/|\z)|severed_relationships(?:/|\z)|statuses_cleanup(?:/|\z)|filters(?:/|\z)|invites(?:/|\z)|admin(?:/|\z)|about(?:/|\z)|privacy-policy(?:/|\z)|terms(?:/|\z)|terms-of-service(?:/|\z)|start(?:/|\z)|p/[0-9]+(?:/|\z))}.freeze
  RESERVED_PREFIXES = %w[/api /auth /oauth /system /packs /assets /streaming /.well-known].freeze

  def create
    return_to = safe_return_to(params[:return_to])
    return render json: { error: 'invalid_return_to' }, status: :bad_request if return_to.nil?

    provider = Devise.omniauth_providers.first
    return render json: { error: 'rinspace_sso_unavailable' }, status: :service_unavailable if provider.nil?

    store_location_for(:user, return_to)
    # Devise only defines the provider-specific route helper when the provider
    # was enabled while routes were drawn.  The generic helper is available in
    # views, but not in every controller context.  Devise's stable endpoint is
    # safe to build here because +provider+ comes exclusively from its own
    # configured allowlist.
    redirect_to "/auth/auth/#{provider}", status: :temporary_redirect
  end

  def recover
    return_to = safe_return_to(session['user_return_to'])
    uri = Addressable::URI.parse('/?world=inner')
    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    query['rinspace_login'] = '1'
    query['rinspace_return_to'] = return_to if return_to
    uri.query = Rack::Utils.build_nested_query(query)
    redirect_to uri.to_s
  end

  private

  def safe_return_to(value)
    return unless value.is_a?(String) && value.bytesize <= 2048
    return if value.match?(/[\u0000-\u001F\u007F\\]/)

    uri = Addressable::URI.parse(value)
    return unless uri.scheme.nil? && uri.host.nil? && uri.user.nil?
    return unless uri.path&.start_with?('/') && !uri.path.start_with?('//')
    return if RESERVED_PREFIXES.any? { |prefix| uri.path == prefix || uri.path.start_with?("#{prefix}/") }
    return unless uri.path.match?(PRODUCT_PATH)

    query = Rack::Utils.parse_nested_query(uri.query.to_s)
    return unless uri.path.match?(%r{\A/p/[0-9]+(?:/|\z)}) || query['world'] == 'inner'

    Rails.application.routes.recognize_path(uri.path, method: :get)
    uri.to_s
  rescue Addressable::URI::InvalidURIError, ActionController::RoutingError, TypeError
    nil
  end
end
