# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RinspaceAuthorizationEvent do
  subject(:event) do
    described_class.new(
      event_id: SecureRandom.uuid, aggregate_type: 'account', aggregate_id: 'uid-1',
      event_type: 'account.authorization_changed', version: 2,
      payload: { uid: 'uid-1', status: 'disabled', role: 'author', version: 2, credentialEpoch: 3 }, applied_at: Time.current
    )
  end

  it { is_expected.to be_valid }

  it 'rejects non-positive versions' do
    event.version = 0
    expect(event).to_not be_valid
  end
end
