# frozen_string_literal: true

class RinspaceSearchEventOutbox < ApplicationRecord
  self.primary_key = :event_id

  scope :ready, -> { where(delivery_state: 'pending', next_attempt_at: ..Time.current).or(where(delivery_state: 'delivering', lease_until: ..Time.current)).order(:occurred_at, :event_id) }

  validates :event_id, :status_id, :action, :canonical_url, :public_version, :occurred_at, :next_attempt_at, presence: true
  validates :action, inclusion: { in: %w[upsert delete] }
  validates :delivery_state, inclusion: { in: %w[pending delivering delivered dead_letter] }
end
