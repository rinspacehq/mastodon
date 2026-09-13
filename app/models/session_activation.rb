# frozen_string_literal: true

# == Schema Information
#
# Table name: session_activations
#
#  id                       :bigint(8)        not null, primary key
#  ip                       :inet
#  user_agent               :string           default(""), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  access_token_id          :bigint(8)
#  session_id               :string           not null
#  user_id                  :bigint(8)        not null
#  web_push_subscription_id :bigint(8)
#

class SessionActivation < ApplicationRecord
  include BrowserDetection

  belongs_to :user, inverse_of: :session_activations
  belongs_to :access_token, class_name: 'Doorkeeper::AccessToken', dependent: :destroy, optional: true
  belongs_to :web_push_subscription, class_name: 'Web::PushSubscription', dependent: :destroy, optional: true

  delegate :token,
           to: :access_token,
           allow_nil: true

  before_create :assign_access_token

  validates :rinspace_parent_issuer, :rinspace_parent_uid, :rinspace_parent_sid, :rinspace_parent_version, :rinspace_parent_auth_time, :rinspace_binding_id, presence: true, if: :rinspace_managed?
  validates :rinspace_parent_version, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validate :rinspace_parent_is_all_or_nothing

  DEFAULT_SCOPES = %w(read write follow).freeze

  scope :latest, -> { order(id: :desc) }

  class << self
    def active?(id)
      id && exists?(session_id: id)
    end

    def activate(**attributes)
      create!(**attributes).tap do |activation|
        purge_old unless activation.rinspace_managed?
      end
    end

    def deactivate(id)
      return unless id

      where(session_id: id).destroy_all
    end

    def deactivate_rinspace_parent(issuer:, sid:, version:)
      where(
        rinspace_parent_issuer: issuer,
        rinspace_parent_sid: sid,
        rinspace_parent_version: ..version
      ).destroy_all
    end

    def purge_old
      latest.offset(Rails.configuration.x.max_session_activations).destroy_all
    end

    def exclusive(id)
      where.not(session_id: id).destroy_all
    end
  end

  def rinspace_managed?
    [rinspace_parent_issuer, rinspace_parent_uid, rinspace_parent_sid, rinspace_parent_version, rinspace_parent_auth_time, rinspace_binding_id].any?(&:present?)
  end

  private

  def assign_access_token
    self.access_token = Doorkeeper::AccessToken.create!(access_token_attributes)
  end

  def access_token_attributes
    {
      application_id: Doorkeeper::Application.find_by(superapp: true)&.id,
      resource_owner_id: user_id,
      scopes: DEFAULT_SCOPES.join(' '),
      expires_in: Doorkeeper.configuration.access_token_expires_in,
      use_refresh_token: Doorkeeper.configuration.refresh_token_enabled?,
      rinspace_parent_issuer:,
      rinspace_parent_uid:,
      rinspace_parent_sid:,
      rinspace_parent_version:,
      rinspace_parent_auth_time:,
    }
  end

  def rinspace_parent_is_all_or_nothing
    values = [rinspace_parent_issuer, rinspace_parent_uid, rinspace_parent_sid, rinspace_parent_version, rinspace_parent_auth_time, rinspace_binding_id]
    return if values.all?(&:blank?) || values.none?(&:blank?)

    errors.add(:rinspace_parent_sid, 'must be supplied with issuer and version')
  end
end
