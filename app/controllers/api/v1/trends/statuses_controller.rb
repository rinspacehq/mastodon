# frozen_string_literal: true

class Api::V1::Trends::StatusesController < Api::BaseController
  vary_by 'Authorization, Accept-Language'

  before_action :set_statuses

  after_action :insert_pagination_headers

  def index
    cache_if_unauthenticated!
    render json: @statuses, each_serializer: REST::StatusSerializer
  end

  private

  def enabled?
    Setting.trends
  end

  def set_statuses
    @statuses = if enabled?
                  preload_collection(statuses_from_trends.offset(offset_param).limit(limit_param(DEFAULT_STATUSES_LIMIT)), Status)
                else
                  []
                end
    @statuses = recent_local_statuses if @statuses.empty? && Mastodon::RinspaceLocalOnly.enabled?
  end

  def statuses_from_trends
    scope = Trends.statuses.query.allowed.in_locale(content_locale)
    scope = scope.filtered_for(current_account) if user_signed_in?
    scope
  end

  def recent_local_statuses
    scope = Status.kept.local.where(visibility: :public, rinspace_review_state: 'approved')
      .joins(:account)
      .where(accounts: { suspended_at: nil, silenced_at: nil, discoverable: true })
      .order(id: :desc)
      .offset(offset_param)
      .limit(limit_param(DEFAULT_STATUSES_LIMIT) * 5)
    Status.permitted_statuses_from_ids(scope.pluck(:id), current_account, stable: true).first(limit_param(DEFAULT_STATUSES_LIMIT))
  end

  def next_path
    api_v1_trends_statuses_url pagination_params(offset: offset_param + limit_param(DEFAULT_STATUSES_LIMIT)) if records_continue?
  end

  def prev_path
    api_v1_trends_statuses_url pagination_params(offset: offset_param - limit_param(DEFAULT_STATUSES_LIMIT)) if offset_param > limit_param(DEFAULT_STATUSES_LIMIT)
  end

  def offset_param
    params[:offset].to_i
  end

  def records_continue?
    @statuses.size == limit_param(DEFAULT_STATUSES_LIMIT)
  end
end
