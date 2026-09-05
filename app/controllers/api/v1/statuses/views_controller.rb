# frozen_string_literal: true

class Api::V1::Statuses::ViewsController < Api::BaseController
  include Authorization
  include Redisable

  before_action -> { doorkeeper_authorize! :write, :'write:statuses' }
  before_action :require_user!
  before_action :require_rinspace_views!

  def create
    return render_empty if automated_request?

    status = Status.find(params[:status_id])
    raise ActiveRecord::RecordNotFound unless status.local?
    authorize status, :show?
    return render json: { counted: false } if status.direct_visibility?
    session_id = params.require(:sessionId).to_s
    raise Mastodon::ValidationError if session_id.length < 16 || session_id.length > 128

    binding = RinspaceIdentityBinding.find_by!(account_id: current_account.id, state: 'verified')
    dedupe_key = view_dedupe_key(binding.subject, status.id, session_id)
    accepted = redis.set(dedupe_key, '1', nx: true, ex: 5.minutes.to_i)
    if accepted
      Rinspace::StatusViewIncrementWorker.perform_async(status.id)
      if current_user.settings['rinspace.personalized_recommendations'] && ActiveModel::Type::Boolean.new.cast(params[:recommendationSignal])
        Rinspace::RecommendationFeedbackWorker.perform_async('read', current_account.id, status.id, true)
      end
    end
    render json: { counted: !!accepted }
  rescue ActionController::ParameterMissing
    render json: { error: 'invalid_request' }, status: :unprocessable_content
  end

  private

  def require_rinspace_views!
    render json: { error: 'Rinspace view counting is not enabled for this rollout stage' }, status: :not_found unless Rails.configuration.x.mastodon.rinspace_views_enabled
  end

  def view_dedupe_key(subject, status_id, session_id)
    key = ENV.fetch('RINSPACE_VIEW_DEDUPE_HMAC_KEY', '')
    raise Rinspace::ModerationUnavailableError if key.bytesize < 32

    digest = OpenSSL::HMAC.hexdigest('SHA256', key, [subject, status_id, session_id].join(':'))
    "rinspace:status-view:#{digest}"
  end

  def automated_request?
    purpose = "#{request.headers['Purpose']} #{request.headers['Sec-Purpose']}"
    purpose.match?(/prefetch|preview/i) || request.user_agent.to_s.match?(/bot|crawler|spider|preview|headless|curl|wget/i)
  end
end
