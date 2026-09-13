# frozen_string_literal: true

class CreateRinspaceLogoutEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :rinspace_logout_events, id: false do |table|
      table.string :jti, primary_key: true
      table.string :issuer, null: false
      table.uuid :sid, null: false
      table.bigint :version, null: false
      table.datetime :expires_at, null: false
      table.timestamps
    end

    add_check_constraint :rinspace_logout_events, 'version >= 1', name: :rinspace_logout_events_positive_version
    add_index :rinspace_logout_events, :expires_at
  end
end
