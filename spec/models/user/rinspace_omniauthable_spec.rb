# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User::Omniauthable do
  around do |example|
    ClimateControl.modify RINSPACE_IDENTITY_STRICT: 'true' do
      example.run
    end
  end

  it 'logs in only a pre-provisioned stable subject' do
    result = Rinspace::EnsureIdentityService.new.call(subject: 'oidc-1', handle: 'alice', display_name: 'Alice', avatar_url: '', bio: '', version: 1)
    auth = OmniAuth::AuthHash.new(provider: 'openid_connect', uid: 'oidc-1', info: { nickname: 'alice' })

    expect(User.find_for_omniauth(auth)).to eq(result.account.user)
  end

  it 'does not auto-create or suffix an unknown or conflicting subject' do
    Fabricate(:account, username: 'alice')
    auth = OmniAuth::AuthHash.new(provider: 'openid_connect', uid: 'unknown', info: { nickname: 'alice' })

    expect { User.find_for_omniauth(auth) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(Identity.find_by(provider: 'openid_connect', uid: 'unknown')).to be_nil
    expect(Account.local.where('username LIKE ?', 'alice%').count).to eq(1)
  end
end
