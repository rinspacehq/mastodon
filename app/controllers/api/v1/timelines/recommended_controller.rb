# frozen_string_literal: true

class Api::V1::Timelines::RecommendedController < Api::V1::Timelines::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:statuses' }
  before_action :require_user!
  before_action :require_rinspace_recommendations!

  PERMITTED_PARAMS = %i(limit max_id).freeze

  def show
    binding = RinspaceIdentityBinding.find_by!(account_id: current_account.id, state: 'verified')
    @statuses = Rinspace::RecommendationService.new.call(
      account: current_account,
      subject: binding.subject,
      limit: limit_param(DEFAULT_STATUSES_LIMIT),
      max_id: params[:max_id],
      personalized: current_user.settings['rinspace.personalized_recommendations']
    )
    @relationships = StatusRelationshipsPresenter.new(@statuses, current_account.id)
    response.headers['X-Rin-Recommendation-Mode'] = current_user.settings['rinspace.personalized_recommendations'] ? 'personalized' : 'non-personalized'
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: @relationships
  end

  private

  def require_rinspace_recommendations!
    render json: { error: 'Rinspace recommendations are not enabled for this rollout stage' }, status: :not_found unless Rails.configuration.x.mastodon.rinspace_recommendations_enabled
  end

  def next_path
    api_v1_timelines_recommended_url(limit: limit_param(DEFAULT_STATUSES_LIMIT), max_id: @statuses.last&.id)
  end

  def prev_path
    api_v1_timelines_recommended_url(limit: limit_param(DEFAULT_STATUSES_LIMIT))
  end
end
