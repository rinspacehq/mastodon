# frozen_string_literal: true

class RinspaceAuthorizationEvent < ApplicationRecord
  self.primary_key = :event_id

  validates :event_id, :aggregate_type, :aggregate_id, :event_type, :version, :payload, :applied_at, presence: true
  validates :aggregate_type, inclusion: { in: %w(session account) }
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
end
