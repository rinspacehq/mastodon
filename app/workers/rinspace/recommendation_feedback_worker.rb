# frozen_string_literal: true

class Rinspace::RecommendationFeedbackWorker
  include Sidekiq::Worker

  sidekiq_options retry: 5

  ALLOWED_TYPES = %w[like repost reply bookmark follow read].freeze

  def perform(feedback_type, account_id, status_id = nil, active = true, target_account_id = nil)
    return unless ALLOWED_TYPES.include?(feedback_type)

    account = Account.local.find_by(id: account_id)
    user = account&.user
    binding = RinspaceIdentityBinding.find_by(account_id:, state: 'verified')
    return unless user && binding && user.settings['rinspace.personalized_recommendations']

    status = if status_id.present?
               Status.find_by(id: status_id)
             elsif target_account_id.present?
               Status.kept.local.where(account_id: target_account_id, visibility: :public, rinspace_review_state: 'approved').order(id: :desc).first
             end
    return unless status&.local? && status.rinspace_review_state == 'approved' && !status.direct_visibility?

    client = Rinspace::GorseClient.new
    if active
      client.feedback(subject: binding.subject, status_id: status.id, feedback_type:)
    else
      client.delete_feedback(subject: binding.subject, status_id: status.id, feedback_type:)
    end
  rescue Rinspace::GorseClient::UnavailableError
    raise if ENV['RINSPACE_LOCAL_ONLY'] == 'true'
  end
end
