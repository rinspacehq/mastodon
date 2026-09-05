# frozen_string_literal: true

class CreateRinspaceIntegrationBindings < ActiveRecord::Migration[8.1]
  def change
    create_table :rinspace_identity_bindings do |table|
      table.string :subject, null: false
      table.references :account, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      table.string :current_handle, null: false
      table.bigint :profile_version, null: false, default: 0
      table.string :state, null: false, default: 'verified'
      table.timestamps
    end
    add_index :rinspace_identity_bindings, :subject, unique: true
    add_index :rinspace_identity_bindings, 'lower(current_handle)', unique: true, name: :index_rinspace_identities_on_lower_handle
    add_check_constraint :rinspace_identity_bindings, "state IN ('verified','disabled','deleted')", name: :rinspace_identity_state

    create_table :rinspace_tag_bindings do |table|
      table.bigint :rinspace_tag_id, null: false
      table.references :tag, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      table.string :canonical_name, null: false
      table.bigint :binding_version, null: false, default: 0
      table.string :state, null: false, default: 'verified'
      table.timestamps
    end
    add_index :rinspace_tag_bindings, :rinspace_tag_id, unique: true
    add_check_constraint :rinspace_tag_bindings, "state IN ('verified','unbound')", name: :rinspace_tag_binding_state

    create_table :rinspace_service_nonces do |table|
      table.string :service, null: false
      table.string :nonce, null: false
      table.datetime :expires_at, null: false
      table.timestamps
    end
    add_index :rinspace_service_nonces, [:service, :nonce], unique: true
    add_index :rinspace_service_nonces, :expires_at

    create_table :rinspace_integration_operations do |table|
      table.string :operation_type, null: false
      table.string :idempotency_key, null: false
      table.string :request_hash, null: false
      table.jsonb :result, null: false, default: {}
      table.timestamps
    end
    add_index :rinspace_integration_operations, [:operation_type, :idempotency_key], unique: true, name: :index_rinspace_operations_on_type_and_key
  end
end
