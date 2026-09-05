# frozen_string_literal: true

class Api::Rinspace::V1::TagBindingsController < Api::Rinspace::V1::BaseController
  def create
    result = Rinspace::BindTagService.new.call(
      rinspace_tag_id: params.require(:rinspaceTagId), name: params.require(:name),
      version: params.require(:version), active: ActiveModel::Type::Boolean.new.cast(params[:active])
    )
    render json: { tagId: result.tag.id, name: result.tag.name, version: result.version }
  rescue ArgumentError, ActionController::ParameterMissing
    render json: { error: 'invalid_request' }, status: :unprocessable_content
  end
end
