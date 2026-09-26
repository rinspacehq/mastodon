# frozen_string_literal: true

require 'digest'

module Rinspace
  class SearchEventRecorder
    SEMANTIC_ATTRIBUTES = %w[text spoiler_text sensitive visibility edited_at deleted_at reblog_of_id rinspace_review_state].freeze

    class << self
      def status_created(status)
        return unless enabled?

        record(status, action: 'upsert') if SearchIndexEligibility.eligible?(status)
      end

      def status_changing(status)
        return unless enabled?

        changed = status.changes_to_save.slice(*SEMANTIC_ATTRIBUTES)
        return if changed.empty?

        previous = changed.transform_values(&:first)
        was_eligible = SearchIndexEligibility.call(status, attributes: previous).eligible?
        is_eligible = SearchIndexEligibility.eligible?(status)
        if is_eligible
          record(status, action: 'upsert', version_time: changed.key?('edited_at') ? nil : Time.current)
        elsif was_eligible
          record(status, action: 'delete', attributes: previous)
        end
      end

      def status_deleted(status)
        return unless enabled?

        record(status, action: 'delete') if SearchIndexEligibility.eligible?(status)
      end

      def reconcile(status)
        return unless enabled?

        action = SearchIndexEligibility.eligible?(status) ? 'upsert' : 'delete'
        record(status, action:, version_time: Time.current)
      end

      def record(status, action:, attributes: {}, version_time: nil)
        return unless eligible_public_candidate?(status, attributes)

        occurred_at = Time.current
        canonical_url = canonical_url(status, attributes)
        public_version = public_version(status, action, attributes, occurred_at, version_time)
        event_id = Digest::SHA256.hexdigest("tweet\n#{status.id}\n#{action}\n#{public_version}")
        RinspaceSearchEventOutbox.create_or_find_by!(event_id:) do |event|
          event.status_id = status.id
          event.action = action
          event.canonical_url = canonical_url
          event.public_version = public_version
          event.occurred_at = occurred_at
          event.next_attempt_at = occurred_at
        end
      end

      private

      def enabled?
        ENV['RINSPACE_SEARCH_EVENTS_ENABLED'] == 'true'
      end

      def eligible_public_candidate?(status, attributes)
        visibility = attribute(status, attributes, 'visibility')
        visibility = Status.visibilities.key(visibility) if visibility.is_a?(Integer)
        local = attribute(status, attributes, 'local')
        uri = attribute(status, attributes, 'uri')
        review = attribute(status, attributes, 'rinspace_review_state')
        reblog_id = attribute(status, attributes, 'reblog_of_id')
        (local != false || uri.blank?) && visibility.to_s == 'public' && review == 'approved' && reblog_id.nil?
      end

      def canonical_url(status, attributes)
        text = attribute(status, attributes, 'text')
        visibility = attribute(status, attributes, 'visibility')
        visibility = Status.visibilities.key(visibility) if visibility.is_a?(Integer)
        sensitive = attribute(status, attributes, 'sensitive')
        slug = StatusSlug.call(text:, visibility:, sensitive:)
        Rails.application.routes.url_helpers.canonical_rinspace_status_url(
          status.id,
          slug,
          **ActionMailer::Base.default_url_options
        )
      end

      def public_version(status, action, attributes, occurred_at, version_time)
        return "deleted:#{status.id}:#{occurred_at.utc.iso8601(6)}" if action == 'delete'

        timestamp = version_time || attribute(status, attributes, 'edited_at') || attribute(status, attributes, 'created_at') || occurred_at
        "status:#{status.id}:#{timestamp.utc.iso8601(6)}"
      end

      def attribute(status, overrides, name)
        overrides.key?(name) ? overrides[name] : status.public_send(name)
      end
    end
  end
end
