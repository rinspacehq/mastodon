# frozen_string_literal: true

require 'addressable/uri'
require 'set'

module Mastodon
  module RinspaceLocalOnly
    class OutboundRequestBlocked < StandardError; end

    INBOUND_PATHS = %r{\A(?:
      /\.well-known/(?:host-meta|nodeinfo|webfinger)|
      /nodeinfo(?:/|\z)|
      /(?:actor|inbox)(?:/|\z)|
      /(?:ap|collections|contexts|users)(?:/|\z)|
      /@[^/]*@[^/]+(?:/|\z)|
      /(?:authorize_follow|authorize_interaction|remote_interaction_helper)(?:/|\z)|
      /api/v1/instance/peers(?:/|\z)|
      /api/v1/admin/(?:domain_allows|domain_blocks)(?:/|\z)|
      /admin/(?:domain_allows|domain_blocks|fasp|instances|relays)(?:/|\z)
    )}x

    BLOCKED_WORKERS = %w[
      ActivityPub::DeliveryWorker
      ActivityPub::LowPriorityDeliveryWorker
      ActivityPub::MigratedFollowDeliveryWorker
      Fasp::AccountSearchWorker
      Fasp::FollowRecommendationWorker
      FetchReplyWorker
      MentionResolveWorker
      RemoteAccountRefreshWorker
      ResolveAccountWorker
      TaggedCollectionResolveWorker
      ThreadResolveWorker
    ].to_set.freeze

    BLOCKED_WORKER_PREFIXES = %w[
      Fasp::
    ].freeze

    module_function

    def enabled?
      Rails.configuration.x.mastodon.rinspace_local_only == true
    end

    def blocked_inbound_path?(path)
      enabled? && INBOUND_PATHS.match?(path.to_s)
    end

    def blocked_inbound_request?(env)
      return false unless enabled?

      blocked_inbound_path?(env['PATH_INFO']) || activitypub_request?(env)
    end

    def activitypub_request?(env)
      media_types = [env['HTTP_ACCEPT'], env['CONTENT_TYPE']].compact.join(',')
      media_types.include?('application/activity+json') ||
        (media_types.include?('application/ld+json') && media_types.include?('activitystreams'))
    end

    def remote_account_reference?(value)
      return false unless enabled?

      account = value.respond_to?(:domain) ? value : nil
      return account.domain.present? if account

      domain = value.to_s.delete_prefix('@').split('@', 2).second
      domain.present? && !TagManager.instance.local_domain?(domain)
    end

    def allowed_outbound_url?(value)
      return true unless enabled?

      uri = Addressable::URI.parse(value.to_s)
      return false unless %w[http https].include?(uri.scheme)
      return false if uri.userinfo.present? || uri.fragment.present?
      return false if blocked_inbound_path?(uri.path)

      local_hosts.include?(uri.normalized_host) || allowed_profile_media_uri?(uri)
    rescue Addressable::URI::InvalidURIError
      false
    end

    def allowed_profile_media_url?(value)
      uri = Addressable::URI.parse(value.to_s)
      allowed_profile_media_uri?(uri)
    rescue Addressable::URI::InvalidURIError
      false
    end

    def assert_outbound_allowed!(value, source:)
      return if allowed_outbound_url?(value)

      instrument(:outbound, source:, target: safe_target(value))
      raise OutboundRequestBlocked, "Rinspace local-only mode blocked outbound request from #{source}"
    end

    def blocked_worker?(worker_class)
      name = worker_class.to_s
      enabled? && (BLOCKED_WORKERS.include?(name) || BLOCKED_WORKER_PREFIXES.any? { |prefix| name.start_with?(prefix) })
    end

    def block_remote_operation(source:, target: nil, layer: :application)
      return false unless enabled?

      instrument(layer, source:, target: safe_target(target))
      true
    end

    def instrument(layer, source:, target: nil)
      payload = { layer:, source:, target: }.compact
      ActiveSupport::Notifications.instrument('rinspace.local_only.blocked', payload)
      Rails.logger.warn({ event: 'rinspace.local_only.blocked', **payload }.to_json)
    end

    def local_hosts
      @local_hosts ||= [
        ENV.fetch('LOCAL_DOMAIN', nil),
        ENV.fetch('WEB_DOMAIN', nil),
        'localhost',
        '127.0.0.1',
        '::1',
      ].compact.filter_map do |value|
        Addressable::URI.parse(value.to_s.include?('://') ? value : "https://#{value}").normalized_host
      rescue Addressable::URI::InvalidURIError
        nil
      end.to_set.freeze
    end

    def profile_media_hosts
      @profile_media_hosts ||= ENV.fetch('RINSPACE_PROFILE_MEDIA_HOSTS', '').split(',').filter_map do |value|
        Addressable::URI.parse("https://#{value.strip}").normalized_host if value.present?
      rescue Addressable::URI::InvalidURIError
        nil
      end.to_set.freeze
    end

    def allowed_profile_media_uri?(uri)
      uri.scheme == 'https' && uri.userinfo.blank? && uri.fragment.blank? && !blocked_inbound_path?(uri.path) && profile_media_hosts.include?(uri.normalized_host)
    end

    def safe_target(value)
      return if value.nil?

      uri = Addressable::URI.parse(value.to_s)
      if uri.host.present?
        "#{uri.scheme}://#{uri.normalized_host}#{uri.path}"
      else
        value.to_s.split('?').first
      end
    rescue Addressable::URI::InvalidURIError
      'invalid-uri'
    end
  end
end
