# frozen_string_literal: true

class ValidateRinspaceStatusConstraints < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :statuses, name: :statuses_rinspace_review_state
    validate_check_constraint :status_stats, name: :status_stats_views_count_nonnegative
  end
end
