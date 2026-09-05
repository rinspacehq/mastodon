# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id         :bigint(8)        not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint(8)        not null
#  status_id  :bigint(8)        not null
#

class Bookmark < ApplicationRecord
  include Paginable

  update_index('statuses', :status) if Chewy.enabled?

  belongs_to :account, inverse_of: :bookmarks
  belongs_to :status,  inverse_of: :bookmarks

  validates :status_id, uniqueness: { scope: :account_id }

  before_validation do
    self.status = status.reblog if status&.reblog?
  end

  after_destroy :invalidate_cleanup_info
  after_create_commit -> { sync_rinspace_feedback(true) }
  after_destroy_commit -> { sync_rinspace_feedback(false) }

  private

  def sync_rinspace_feedback(active)
    Rinspace::RecommendationFeedbackWorker.perform_async('bookmark', account_id, status_id, active) if ENV['RINSPACE_LOCAL_ONLY'] == 'true'
  end

  def invalidate_cleanup_info
    return unless status&.account_id == account_id && account.local?

    account.statuses_cleanup_policy&.invalidate_last_inspected(status, :unbookmark)
  end
end
