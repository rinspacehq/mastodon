# frozen_string_literal: true

class CreateRinspaceAuthorizationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :rinspace_authorization_events, id: false do |table|
      table.uuid :event_id, primary_key: true
      table.string :aggregate_type, null: false
      table.string :aggregate_id, null: false
      table.string :event_type, null: false
      table.bigint :version, null: false
      table.jsonb :payload, null: false, default: {}
      table.datetime :applied_at, null: false
      table.timestamps
    end

    add_check_constraint :rinspace_authorization_events, "aggregate_type IN ('session','account')", name: :rinspace_authorization_events_aggregate_type
    add_check_constraint :rinspace_authorization_events, 'version >= 1', name: :rinspace_authorization_events_positive_version
    add_index :rinspace_authorization_events, %i[aggregate_type aggregate_id version], name: :index_rinspace_authorization_events_on_aggregate
  end
end
