# frozen_string_literal: true

class Api::V1::RinspacePreferencesController < Api::BaseController
  before_action -> { doorkeeper_authorize! :read, :'read:accounts' }, only: :show
  before_action -> { doorkeeper_authorize! :write, :'write:accounts' }, only: [:update, :destroy, :destroy_interest]
  before_action :require_user!

  def show
    render json: preference_payload
  end

  def update
    enabled = ActiveModel::Type::Boolean.new.cast(params.require(:personalizedRecommendations))
    requested_feed = params[:homeFeed].to_s
    requested_feed = 'following' unless enabled
    requested_feed = 'recommended' unless %w[recommended following].include?(requested_feed)
    current_user.settings['rinspace.personalized_recommendations'] = enabled
    current_user.settings['rinspace.home_feed'] = requested_feed
    current_user.settings['rinspace.recommendation_interests_json'] = JSON.generate(normalized_interests(params[:interests])) if params.key?(:interests)
    current_user.save!
    render json: preference_payload
  rescue ActionController::ParameterMissing, ArgumentError
    render json: { error: 'invalid_request' }, status: :unprocessable_content
  end

  def destroy_interest
    interests = stored_interests
    interests.delete(params[:interest].to_s)
    current_user.settings['rinspace.recommendation_interests_json'] = JSON.generate(interests)
    current_user.save!
    render json: preference_payload
  end

  def destroy
    binding = RinspaceIdentityBinding.find_by!(account_id: current_account.id, state: 'verified')
    Rinspace::GorseClient.new.clear_user(subject: binding.subject)
    current_user.settings['rinspace.personalized_recommendations'] = false
    current_user.settings['rinspace.home_feed'] = 'following'
    current_user.save!
    render json: preference_payload.merge(profileCleared: true)
  rescue Rinspace::GorseClient::UnavailableError
    render json: { error: 'recommendation_service_unavailable' }, status: :service_unavailable
  end

  private

  def preference_payload
    {
      personalizedRecommendations: current_user.settings['rinspace.personalized_recommendations'],
      homeFeed: current_user.settings['rinspace.home_feed'],
      interests: stored_interests,
      explanation: 'Recommendations are ranked from minimized local interaction signals after visibility and safety filtering.',
    }
  end

  def stored_interests
    normalized_interests(JSON.parse(current_user.settings['rinspace.recommendation_interests_json']))
  rescue JSON::ParserError
    []
  end

  def normalized_interests(values)
    Array(values).filter_map do |value|
      value = value.to_s.unicode_normalize(:nfkc).strip.delete_prefix('#')
      value if value.match?(/\A[\p{L}\p{M}\p{N}_-]{1,64}\z/u)
    end.uniq.first(20)
  end
end
