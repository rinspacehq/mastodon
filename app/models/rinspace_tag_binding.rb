# frozen_string_literal: true

class RinspaceTagBinding < ApplicationRecord
  belongs_to :tag

  validates :rinspace_tag_id, :tag_id, uniqueness: true
  validates :canonical_name, presence: true
  validates :binding_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :state, inclusion: { in: %w[verified unbound] }
end
