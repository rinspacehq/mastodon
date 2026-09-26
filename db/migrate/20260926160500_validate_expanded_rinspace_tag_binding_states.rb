# frozen_string_literal: true

class ValidateExpandedRinspaceTagBindingStates < ActiveRecord::Migration[8.1]
  def up
    validate_check_constraint :rinspace_tag_bindings, name: :rinspace_tag_binding_state_expanded
  end

  def down
    validate_check_constraint :rinspace_tag_bindings, name: :rinspace_tag_binding_state
  end
end
