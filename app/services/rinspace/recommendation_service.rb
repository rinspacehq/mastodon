# frozen_string_literal: true

class Rinspace::RecommendationService
  CANDIDATE_MULTIPLIER = 5

  def call(account:, subject:, limit:, max_id: nil, personalized: true)
    limit = limit.to_i.clamp(1, 40)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ids = if personalized
            Rinspace::GorseClient.new.recommend(user_id: subject, limit: limit * CANDIDATE_MULTIPLIER, offset: 0)
          else
            []
          end
    ids.select! { |id| id < max_id.to_i } if max_id.present?
    ranked = eligible_statuses(ids, account).first(limit)
    fallback = fallback_statuses(account, limit - ranked.length, max_id, exclude_ids: ranked.map(&:id))
    result = ranked + fallback
    log_result(candidate_count: ids.length, ranked_count: ranked.length, fallback_count: fallback.length, result_count: result.length, personalized: personalized, started_at: started_at)

    result
  rescue Rinspace::GorseClient::UnavailableError
    result = fallback_statuses(account, limit, max_id)
    log_result(candidate_count: 0, ranked_count: 0, fallback_count: result.length, result_count: result.length, personalized: personalized, started_at: started_at, fallback_reason: 'gorse_unavailable')
    result
  end

  private

  def eligible_statuses(ids, account)
    return [] if ids.empty?

    Status.permitted_statuses_from_ids(ids, account, stable: true).select { |status| eligible?(status) }
  end

  def fallback_statuses(account, limit, max_id, exclude_ids: [])
    return [] if limit <= 0

    scope = recommendation_scope
    scope = scope.where(id: ...max_id.to_i) if max_id.present?
    scope = scope.where.not(id: exclude_ids) if exclude_ids.any?
    ids = scope.limit(limit * CANDIDATE_MULTIPLIER).pluck(:id)
    Status.permitted_statuses_from_ids(ids, account, stable: true).select { |status| eligible?(status) }.first(limit)
  end

  def log_result(candidate_count:, ranked_count:, fallback_count:, result_count:, personalized:, started_at:, fallback_reason: nil)
    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(1)
    Rails.logger.info(
      event: 'rinspace_recommendation_result',
      personalized: personalized,
      candidate_count: candidate_count,
      ranked_count: ranked_count,
      fallback_count: fallback_count,
      fallback_reason: fallback_reason || (fallback_count.positive? ? 'insufficient_ranked_results' : 'none'),
      result_count: result_count,
      duration_ms: duration_ms
    )
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
