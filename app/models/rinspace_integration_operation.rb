# frozen_string_literal: true

class RinspaceIntegrationOperation < ApplicationRecord
  validates :operation_type, :idempotency_key, :request_hash, presence: true
end
