# frozen_string_literal: true

class CreateRinspaceSearchEventOutboxes < ActiveRecord::Migration[8.1]
  def change
    create_table :rinspace_search_event_outboxes, id: false do |table|
      table.string :event_id, null: false, primary_key: true
      table.bigint :status_id, null: false
      table.string :action, null: false
      table.string :canonical_url, null: false
      table.string :public_version, null: false
      table.datetime :occurred_at, null: false
      table.integer :attempt_count, null: false, default: 0
      table.datetime :next_attempt_at, null: false
      table.string :delivery_state, null: false, default: 'pending'
      table.string :lease_token, null: false, default: ''
      table.datetime :lease_until
      table.integer :last_status_code
      table.string :last_error_code, null: false, default: ''
      table.timestamps
    end
    add_index :rinspace_search_event_outboxes, %i[status_id action public_version], unique: true, name: :index_rinspace_search_outbox_idempotency
    add_index :rinspace_search_event_outboxes, %i[delivery_state next_attempt_at occurred_at], name: :index_rinspace_search_outbox_ready
    add_check_constraint :rinspace_search_event_outboxes, "action IN ('upsert','delete')", name: :rinspace_search_outbox_action
    add_check_constraint :rinspace_search_event_outboxes, "delivery_state IN ('pending','delivering','delivered','dead_letter')", name: :rinspace_search_outbox_state
    add_check_constraint :rinspace_search_event_outboxes, 'attempt_count >= 0', name: :rinspace_search_outbox_attempts
  end
end
