# frozen_string_literal: true

class ExpandRinspaceTagBindingStates < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :rinspace_tag_bindings, name: :rinspace_tag_binding_state
    add_check_constraint :rinspace_tag_bindings,
                         "state IN ('verified','unbound','pending','retired','conflicting')",
                         name: :rinspace_tag_binding_state
  end

  def down
    execute "UPDATE rinspace_tag_bindings SET state = 'unbound' WHERE state IN ('pending','retired','conflicting')"
    remove_check_constraint :rinspace_tag_bindings, name: :rinspace_tag_binding_state
    add_check_constraint :rinspace_tag_bindings,
                         "state IN ('verified','unbound')",
                         name: :rinspace_tag_binding_state
  end
end
