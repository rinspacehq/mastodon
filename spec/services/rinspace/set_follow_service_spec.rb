# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::SetFollowService do
  it 'uses the Mastodon relationship engine and replays one idempotency key' do
    actor = Fabricate(:account)
    target = Fabricate(:account)

    first = described_class.new.call(actor_account_id: actor.id, target_account_id: target.id, active: true, idempotency_key: 'follow-1')
    second = described_class.new.call(actor_account_id: actor.id, target_account_id: target.id, active: true, idempotency_key: 'follow-1')

    expect(first).to eq(second)
    expect(actor.following?(target)).to be true
    expect(Follow.where(account: actor, target_account: target).count).to eq(1)
  end

  it 'rejects reuse of an idempotency key for a different command' do
    actor = Fabricate(:account)
    target = Fabricate(:account)
    described_class.new.call(actor_account_id: actor.id, target_account_id: target.id, active: true, idempotency_key: 'follow-2')

    expect do
      described_class.new.call(actor_account_id: actor.id, target_account_id: target.id, active: false, idempotency_key: 'follow-2')
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'preserves follow-request semantics for locked accounts' do
    actor = Fabricate(:account)
    target = Fabricate(:account, locked: true)

    result = described_class.new.call(actor_account_id: actor.id, target_account_id: target.id, active: true, idempotency_key: 'follow-request-1')

    expect(result).to include('active' => false, 'requested' => true)
    expect(FollowRequest.exists?(account: actor, target_account: target)).to be true
  end
end
