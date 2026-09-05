# frozen_string_literal: true

class AddRinspaceReviewStateToStatuses < ActiveRecord::Migration[8.1]
	disable_ddl_transaction!

  def change
    add_column :statuses, :rinspace_review_state, :string, null: false, default: 'unreviewed'
    add_check_constraint :statuses, "rinspace_review_state IN ('unreviewed','approved','rejected','removed')", name: :statuses_rinspace_review_state, validate: false
    add_index :statuses, [:rinspace_review_state, :visibility, :id], name: :index_statuses_on_rinspace_recommendation, where: "deleted_at IS NULL AND local = TRUE", algorithm: :concurrently
  end
end
