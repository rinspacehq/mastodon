# frozen_string_literal: true

class AddRinspaceParentToBrowserSessions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :session_activations, :rinspace_parent_issuer, :string
    add_column :session_activations, :rinspace_parent_uid, :string
    add_column :session_activations, :rinspace_parent_sid, :uuid
    add_column :session_activations, :rinspace_parent_version, :bigint
    add_column :session_activations, :rinspace_parent_auth_time, :datetime

    add_column :session_activations, :rinspace_binding_id, :uuid

    add_column :oauth_access_tokens, :rinspace_parent_issuer, :string
    add_column :oauth_access_tokens, :rinspace_parent_uid, :string
    add_column :oauth_access_tokens, :rinspace_parent_sid, :uuid
    add_column :oauth_access_tokens, :rinspace_parent_version, :bigint
    add_column :oauth_access_tokens, :rinspace_parent_auth_time, :datetime

    add_index :session_activations,
              [:rinspace_parent_issuer, :rinspace_parent_sid],
              unique: true,
              where: 'rinspace_parent_sid IS NOT NULL',
              algorithm: :concurrently,
              name: :index_session_activations_on_rinspace_parent
    add_index :session_activations,
              :rinspace_binding_id,
              unique: true,
              where: 'rinspace_binding_id IS NOT NULL',
              algorithm: :concurrently,
              name: :index_session_activations_on_rinspace_binding
    add_index :oauth_access_tokens,
              [:rinspace_parent_issuer, :rinspace_parent_sid],
              unique: true,
              where: 'rinspace_parent_sid IS NOT NULL',
              algorithm: :concurrently,
              name: :index_oauth_tokens_on_rinspace_parent

    add_check_constraint :session_activations,
                         '(rinspace_parent_issuer IS NULL AND rinspace_parent_uid IS NULL AND rinspace_parent_sid IS NULL AND rinspace_parent_version IS NULL AND rinspace_parent_auth_time IS NULL AND rinspace_binding_id IS NULL) OR ' \
                         '(rinspace_parent_issuer IS NOT NULL AND rinspace_parent_uid IS NOT NULL AND rinspace_parent_sid IS NOT NULL AND rinspace_parent_version >= 1 AND rinspace_parent_auth_time IS NOT NULL AND rinspace_binding_id IS NOT NULL)',
                         name: :session_activations_rinspace_parent_complete,
                         validate: false
    add_check_constraint :oauth_access_tokens,
                         '(rinspace_parent_issuer IS NULL AND rinspace_parent_uid IS NULL AND rinspace_parent_sid IS NULL AND rinspace_parent_version IS NULL AND rinspace_parent_auth_time IS NULL) OR ' \
                         '(rinspace_parent_issuer IS NOT NULL AND rinspace_parent_uid IS NOT NULL AND rinspace_parent_sid IS NOT NULL AND rinspace_parent_version >= 1 AND rinspace_parent_auth_time IS NOT NULL)',
                         name: :oauth_access_tokens_rinspace_parent_complete,
                         validate: false
  end
end
