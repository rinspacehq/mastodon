# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::OmniauthCallbacksController do
  subject(:parent) { controller.send(:managed_parent_from, auth) }

  let(:sid) { SecureRandom.uuid }
  let(:auth) do
    OmniAuth::AuthHash.new(
      uid: 'uid-7',
      extra: { raw_info: { sid:, rin_session_version: 4, auth_time: 1_789_200_000 } }
    )
  end

  around do |example|
    ClimateControl.modify(OIDC_ISSUER: 'https://rinspace.example') { example.run }
  end

  it 'requires the signed OIDC parent fields used by the runtime binding' do
    expect(parent).to include(issuer: 'https://rinspace.example', uid: 'uid-7', sid:, version: 4)
    expect(parent[:auth_time]).to eq(Time.zone.at(1_789_200_000))
  end

  it 'rejects a callback without a valid sid and positive parent version' do
    auth.extra.raw_info.sid = 'not-a-session'
    auth.extra.raw_info.rin_session_version = 0

    expect { parent }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
