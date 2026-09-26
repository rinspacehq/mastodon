# frozen_string_literal: true

module Rinspace
  class SearchIndexEligibility
    Result = Data.define(:eligible, :reason) do
      alias eligible? eligible
    end
    SitemapEntry = Data.define(:status_id, :url, :last_modified_at)

    CANDIDATE_SCOPE = lambda do
      Status.unscoped
        .kept
        .local
        .public_visibility
        .without_reblogs
        .where(rinspace_review_state: 'approved')
        .includes(account: :user)
    end

    def self.call(status, attributes: {})
      new(status, attributes:).call
    end

    def self.eligible?(status)
      call(status).eligible?
    end

    def self.candidates
      CANDIDATE_SCOPE.call
    end

    def self.sitemap_entries(limit: 45_001, batch_size: 500)
      entries = []
      before_id = nil

      loop do
        scope = candidates.reorder(id: :desc)
        scope = scope.where(Status.arel_table[:id].lt(before_id)) if before_id
        batch = scope.limit(batch_size).to_a
        break if batch.empty?

        batch.each do |status|
          next unless eligible?(status)

          entries << SitemapEntry.new(
            status_id: status.id,
            url: Rails.application.routes.url_helpers.canonical_rinspace_status_url(
              status.id,
              Rinspace::StatusSlug.for(status),
              **ActionMailer::Base.default_url_options
            ),
            last_modified_at: status.edited_at || status.created_at
          )
          return entries if entries.length >= limit
        end
        before_id = batch.last.id
      end

      entries
    end

    def initialize(status, attributes: {})
      @status = status
      @attributes = attributes.stringify_keys
    end

    def call
      return Result.new(eligible: false, reason: :missing) if status.nil? || attribute('deleted_at').present?
      return Result.new(eligible: false, reason: :remote) if attribute('local') == false && attribute('uri').present?
      return Result.new(eligible: false, reason: :visibility) unless public_visibility?
      return Result.new(eligible: false, reason: :boost) if attribute('reblog_of_id').present?
      return Result.new(eligible: false, reason: :moderation) unless attribute('rinspace_review_state') == 'approved'
      return Result.new(eligible: false, reason: :account_unavailable) if account_unavailable?
      return Result.new(eligible: false, reason: :author_noindex) if status.account.user_prefers_noindex?

      Result.new(eligible: true, reason: :eligible)
    end

    private

    attr_reader :status, :attributes

    def attribute(name)
      attributes.key?(name) ? attributes[name] : status.public_send(name)
    end

    def public_visibility?
      visibility = attribute('visibility')
      visibility = Status.visibilities.key(visibility) if visibility.is_a?(Integer)
      visibility.to_s == 'public'
    end

    def account_unavailable?
      account = status.account
      account.nil? || account.unavailable? || account.silenced? || account.requested_deletion_at.present?
    end
  end
end
