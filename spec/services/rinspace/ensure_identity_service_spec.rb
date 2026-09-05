# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::EnsureIdentityService do
  subject(:service) { described_class.new }

  it 'pre-creates one stable OIDC identity and replays idempotently' do
    first = service.call(subject: 'uid-1', handle: 'alice', display_name: 'Alice', avatar_url: '', bio: 'Writer', version: 1)
    second = service.call(subject: 'uid-1', handle: 'alice', display_name: 'Alice', avatar_url: '', bio: 'Writer', version: 1)

    expect(second.account.id).to eq(first.account.id)
    expect(Identity.find_by(provider: 'openid_connect', uid: 'uid-1').user.account_id).to eq(first.account.id)
    expect(RinspaceIdentityBinding.where(subject: 'uid-1').count).to eq(1)
    expect(first.account.discoverable).to be true
  end

  it 'initializes legacy nil discoverability without overriding an explicit opt-out' do
    result = service.call(subject: 'uid-discoverable', handle: 'discoverable', display_name: '', avatar_url: '', bio: '', version: 1)
    result.account.update_column(:discoverable, false)

    replayed = service.call(subject: 'uid-discoverable', handle: 'discoverable', display_name: '', avatar_url: '', bio: '', version: 1)

    expect(replayed.account.discoverable).to be false
  end

  it 'rejects profile media outside the explicit trust boundary' do
    expect do
      service.call(subject: 'uid-avatar', handle: 'avatar', display_name: '', avatar_url: 'https://example.org/avatar.png', bio: '', version: 1)
    end.to raise_error(ArgumentError, 'avatar URL is outside the local trust boundary')
  end

  it 'renames the same account and leaves the old handle reusable' do
    original = service.call(subject: 'uid-2', handle: 'before', display_name: 'Before', avatar_url: '', bio: '', version: 1)
    renamed = service.call(subject: 'uid-2', handle: 'after', display_name: 'After', avatar_url: '', bio: '', version: 2)

    expect(renamed.account.id).to eq(original.account.id)
    expect(renamed.account.username).to eq('after')
    expect(Account.local.exists?(username: 'before')).to be false
  end

  it 'fails closed when a handle belongs to another identity' do
    service.call(subject: 'uid-3', handle: 'taken', display_name: '', avatar_url: '', bio: '', version: 1)

    expect do
      service.call(subject: 'uid-4', handle: 'taken', display_name: '', avatar_url: '', bio: '', version: 1)
    end.to raise_error(ActiveRecord::RecordNotUnique)
    expect(Identity.find_by(provider: 'openid_connect', uid: 'uid-4')).to be_nil
  end

  it 'disables a bound user without deleting identity evidence' do
    service.call(subject: 'uid-5', handle: 'disabled_user', display_name: '', avatar_url: '', bio: '', version: 1)
    result = service.call(subject: 'uid-5', handle: 'disabled_user', display_name: '', avatar_url: '', bio: '', version: 2, state: 'disabled')

    expect(result.account.user).to be_disabled
    expect(RinspaceIdentityBinding.find_by(subject: 'uid-5')).to have_attributes(state: 'disabled')
  end

  it 'ignores stale events and treats deletion as a terminal identity state' do
    service.call(subject: 'uid-6', handle: 'stable', display_name: 'Current', avatar_url: '', bio: '', version: 3, state: 'deleted')

    stale = service.call(subject: 'uid-6', handle: 'stale', display_name: 'Stale', avatar_url: '', bio: '', version: 2, state: 'active')
    expect(stale.account.username).to eq('stable')
    expect(stale.account.user).to be_disabled

    expect do
      service.call(subject: 'uid-6', handle: 'stable', display_name: 'Current', avatar_url: '', bio: '', version: 4, state: 'active')
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'rejects conflicting payloads that reuse one version' do
    service.call(subject: 'uid-7', handle: 'versioned', display_name: '', avatar_url: '', bio: '', version: 1)

    expect do
      service.call(subject: 'uid-7', handle: 'different', display_name: '', avatar_url: '', bio: '', version: 1)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
