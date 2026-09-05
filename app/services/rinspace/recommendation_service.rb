# frozen_string_literal: true

class Rinspace::RecommendationService
  CANDIDATE_MULTIPLIER = 5

  def call(account:, subject:, limit:, max_id: nil, personalized: true)
    limit = limit.to_i.clamp(1, 40)
    ids = if personalized
            Rinspace::GorseClient.new.recommend(user_id: subject, limit: limit * CANDIDATE_MULTIPLIER, offset: 0)
          else
            []
          end
    ids.select! { |id| id < max_id.to_i } if max_id.present?
    statuses = eligible_statuses(ids, account)
    return statuses.first(limit) if statuses.any?

    fallback_statuses(account, limit, max_id)
  rescue Rinspace::GorseClient::UnavailableError
    fallback_statuses(account, limit, max_id)
  end

  private

  def eligible_statuses(ids, account)
    return [] if ids.empty?

    Status.permitted_statuses_from_ids(ids, account, stable: true).select { |status| eligible?(status) }
  end

  def fallback_statuses(account, limit, max_id)
    scope = recommendation_scope
    scope = scope.where(id: ...max_id.to_i) if max_id.present?
    ids = scope.limit(limit * CANDIDATE_MULTIPLIER).pluck(:id)
    Status.permitted_statuses_from_ids(ids, account, stable: true).select { |status| eligible?(status) }.first(limit)
  end

  def recommendation_scope
    Status.kept.local.where(visibility: :public, rinspace_review_state: 'approved')
      .joins(:account)
      .where(accounts: { suspended_at: nil, silenced_at: nil, discoverable: true })
      .order(id: :desc)
  end

  def eligible?(status)
    status.local? && status.public_visibility? && status.rinspace_review_state == 'approved' && status.account.discoverable? && !status.account.unavailable?
  end
end
