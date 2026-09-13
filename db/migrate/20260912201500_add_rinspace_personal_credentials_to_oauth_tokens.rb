# frozen_string_literal: true

class AddRinspacePersonalCredentialsToOAuthTokens < ActiveRecord::Migration[8.1]
	disable_ddl_transaction!

  def change
    add_column :oauth_access_tokens, :rinspace_credential_ref, :uuid
    add_column :oauth_access_tokens, :rinspace_credential_epoch, :bigint
    add_index :oauth_access_tokens, :rinspace_credential_ref, unique: true, where: 'rinspace_credential_ref IS NOT NULL', name: :index_oauth_tokens_on_rinspace_credential_ref, algorithm: :concurrently
    add_check_constraint :oauth_access_tokens,
                         '(rinspace_credential_ref IS NULL AND rinspace_credential_epoch IS NULL) OR (rinspace_credential_ref IS NOT NULL AND rinspace_credential_epoch >= 1)',
                         name: :oauth_access_tokens_rinspace_credential_complete,
						 validate: false
  end
end
