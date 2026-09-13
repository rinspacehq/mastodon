# frozen_string_literal: true

class RinspaceLogoutEvent < ApplicationRecord
  self.primary_key = :jti

  validates :jti, :issuer, :sid, :version, :expires_at, presence: true
end
