# frozen_string_literal: true

class RinspaceServiceNonce < ApplicationRecord
  validates :service, :nonce, :expires_at, presence: true
end
