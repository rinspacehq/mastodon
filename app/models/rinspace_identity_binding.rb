# frozen_string_literal: true

class RinspaceIdentityBinding < ApplicationRecord
  belongs_to :account

  validates :subject, :current_handle, presence: true, uniqueness: true
  validates :account_id, uniqueness: true
  validates :profile_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :state, inclusion: { in: %w[verified disabled deleted] }
end
