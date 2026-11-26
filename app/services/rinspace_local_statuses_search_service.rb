# frozen_string_literal: true

# The local-only instance can search its existing database without a separate
# search cluster. Match the native public and personal index eligibility.
class RinspaceLocalStatusesSearchService < BaseService
  MAX_QUERY_LENGTH = 500

  def call(query, account, limit:, offset:, account_id: nil, min_id: nil, max_id: nil)
    return [] if !Mastodon::RinspaceLocalOnly.enabled? || !account&.local? || query.blank? || query.length > MAX_QUERY_LENGTH

    scope = Status.local.without_reblogs
    statuses = eligible_statuses(scope, account.id)
    phrase = query.match?(/\A".*"\z/) ? query[1...-1] : query
    return [] if phrase.blank?

    statuses = statuses.where('statuses.text ILIKE :pattern OR statuses.spoiler_text ILIKE :pattern', pattern: "%#{Status.sanitize_sql_like(phrase)}%")
    statuses = statuses.where(account_id: Account.find(account_id).id) if account_id.present?
    statuses = statuses.where(id: (min_id.to_i + 1)..) if min_id.present?
    statuses = statuses.where(id: ...max_id.to_i) if max_id.present?

    results = statuses.limit(limit).offset(offset).includes(:account).to_a
    account.preload_relations!(results.map(&:account_id), results.map(&:account_domain))
    results.reject { |status| StatusFilter.new(status, account).filtered? }
  end

  private

  def eligible_statuses(scope, account_id)
    scope.where(account_id: account_id)
         .or(scope.where(id: Status.indexable.unscope(:order).select(:id)))
         .or(scope.where(id: Mention.active.where(account_id: account_id).select(:status_id)))
         .or(scope.where(id: Favourite.where(account_id: account_id).select(:status_id)))
         .or(scope.where(id: Bookmark.where(account_id: account_id).select(:status_id)))
         .or(scope.where(id: Status.only_reblogs.where(account_id: account_id).unscope(:order).select(:reblog_of_id)))
         .or(scope.where(poll_id: PollVote.where(account_id: account_id).select(:poll_id)))
  end
end
