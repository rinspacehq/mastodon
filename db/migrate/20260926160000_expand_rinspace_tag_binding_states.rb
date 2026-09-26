# frozen_string_literal: true

class ExpandRinspaceTagBindingStates < ActiveRecord::Migration[8.1]
  def up
    add_check_constraint :rinspace_tag_bindings,
                         "state IN ('verified','unbound','pending','retired','conflicting')",
                         name: :rinspace_tag_binding_state_expanded,
                         validate: false
  end

  def down
    remove_check_constraint :rinspace_tag_bindings, name: :rinspace_tag_binding_state_expanded
  end
end
