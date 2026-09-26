# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::SearchIndexEligibility do
  subject(:result) { described_class.call(status) }

  let(:account) { Fabricate(:account, indexable: false) }
  let(:status) { Fabricate(:status, account:, visibility: :public, rinspace_review_state: 'approved') }

  it 'accepts an approved local public original independently of Mastodon internal account.indexable' do
    expect(result).to be_eligible
    expect(result.reason).to eq(:eligible)
  end

  it 'accepts public replies' do
    status.update!(reply: true, in_reply_to_id: Fabricate(:status).id)

    expect(result).to be_eligible
  end

  {
    visibility: ->(status, _) { status.update!(visibility: :unlisted) },
    private_visibility: ->(status, _) { status.update!(visibility: :private) },
    moderation: ->(status, _) { status.update!(rinspace_review_state: 'rejected') },
    deleted: ->(status, _) { status.update_column(:deleted_at, Time.current) },
    suspended: ->(_, account) { account.update!(suspended_at: Time.current) },
    silenced: ->(_, account) { account.update!(silenced_at: Time.current) },
    author_noindex: ->(_, account) { account.user.settings.update('noindex' => true) },
  }.each do |name, mutation|
    it "rejects #{name}" do
      mutation.call(status, account)

      expect(result).not_to be_eligible
    end
  end

  it 'rejects remote statuses' do
    remote = Fabricate(:status, account: Fabricate(:account, domain: 'remote.example'), visibility: :public, rinspace_review_state: 'approved')

    expect(described_class.call(remote)).not_to be_eligible
  end

  it 'rejects boost wrappers' do
    boost = Fabricate(:status, account:, reblog: status, visibility: :public, rinspace_review_state: 'approved')

    expect(described_class.call(boost)).not_to be_eligible
  end
end
