# frozen_string_literal: true

class Rinspace::RecommendationSyncWorker
  include Sidekiq::Worker

  sidekiq_options retry: 8

  def perform(status_id)
    status = Status.includes(:account).find_by(id: status_id)
    eligible = status&.local? && status&.public_visibility? && !status.discarded? && status.rinspace_review_state == 'approved' && status.account.discoverable? && !status.account.unavailable?
    Rinspace::GorseClient.new.upsert_status(status_id:, hidden: !eligible, timestamp: status&.created_at)
  rescue Rinspace::GorseClient::UnavailableError => error
    raise error if ENV['RINSPACE_LOCAL_ONLY'] == 'true'
  end
end
