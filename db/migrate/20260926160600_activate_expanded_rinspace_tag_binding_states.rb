# frozen_string_literal: true

class ActivateExpandedRinspaceTagBindingStates < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :rinspace_tag_bindings, name: :rinspace_tag_binding_state
    rename_constraint :rinspace_tag_binding_state_expanded, :rinspace_tag_binding_state
  end

  def down
    safety_assured do
      execute "UPDATE rinspace_tag_bindings SET state = 'unbound' WHERE state IN ('pending','retired','conflicting')"
    end
    rename_constraint :rinspace_tag_binding_state, :rinspace_tag_binding_state_expanded
    add_check_constraint :rinspace_tag_bindings,
                         "state IN ('verified','unbound')",
                         name: :rinspace_tag_binding_state,
                         validate: false
  end

  private

  def rename_constraint(from, to)
    safety_assured do
      execute <<~SQL.squish
        ALTER TABLE rinspace_tag_bindings
        RENAME CONSTRAINT #{connection.quote_column_name(from)}
        TO #{connection.quote_column_name(to)}
      SQL
    end
  end
end
