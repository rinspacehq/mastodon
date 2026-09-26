# frozen_string_literal: true

class Api::Rinspace::V1::SearchTagStatusesController < Api::Rinspace::V1::BaseController
  LIMIT = 6

  def index
    binding = RinspaceTagBinding.find_by!(rinspace_tag_id: params[:rinspace_tag_id], state: 'verified')
    items = Rinspace::SearchIndexEligibility.candidates
      .tagged_with([binding.tag_id])
      .reorder(id: :desc)
      .limit(LIMIT * 2)
      .filter { |status| Rinspace::SearchIndexEligibility.eligible?(status) }
      .first(LIMIT)
      .map do |status|
        {
          id: status.id.to_s,
          title: ActionController::Base.helpers.strip_tags(status.text).squish.truncate(120),
          canonicalUrl: canonical_rinspace_status_url(status.id, Rinspace::StatusSlug.for(status)),
          publicModifiedAt: (status.edited_at || status.created_at).utc.iso8601,
        }
      end
    render json: { tagId: binding.rinspace_tag_id.to_s, bindingVersion: binding.binding_version, items: }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'verified tag binding not found' }, status: :not_found
  end
end
