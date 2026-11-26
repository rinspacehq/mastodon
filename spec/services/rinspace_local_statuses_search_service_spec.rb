# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RinspaceLocalStatusesSearchService do
  let(:viewer) { Fabricate(:account) }
  let(:author) { Fabricate(:account, indexable: true) }
  let(:query) { '自然语言' }

  before do
    allow(Mastodon::RinspaceLocalOnly).to receive(:enabled?).and_return(true)
    allow(Chewy).to receive(:enabled?).and_return(false)
  end

  it 'finds public opt-in and authored posts in the native search response' do
    public_status = Fabricate(:status, account: author, text: "学习#{query}处理")
    own_status = Fabricate(:status, account: viewer, visibility: :private, text: "我的#{query}笔记")
    Fabricate(:status, account: author, visibility: :unlisted, text: query)
    Fabricate(:status, account: author, visibility: :private, text: query)
    Fabricate(:status, account: Fabricate(:account, indexable: false), text: query)

    expect(SearchService.new.call(query, viewer, 20, type: 'statuses')[:statuses]).to eq([own_status, public_status])
    expect(SearchService.new.call(query, nil, 20, type: 'statuses')[:statuses]).to be_empty
  end

  it 'finds interacted-with posts and respects the current visibility policy' do
    status = Fabricate(:status, account: Fabricate(:account, indexable: false), text: query)
    Fabricate(:bookmark, account: viewer, status: status)

    expect(subject.call(query, viewer, limit: 20, offset: 0)).to eq([status])

    status.account.block!(viewer)

    expect(subject.call(query, viewer, limit: 20, offset: 0)).to be_empty
  end

  it 'treats SQL wildcard characters literally and reflects edits immediately' do
    status = Fabricate(:status, account: author, text: '100% complete')
    Fabricate(:status, account: author, text: '1000 complete')

    expect(subject.call('100%', viewer, limit: 20, offset: 0)).to eq([status])

    status.update!(text: 'Finished')

    expect(subject.call('100%', viewer, limit: 20, offset: 0)).to be_empty
  end

  it 'preserves author and pagination filters' do
    older = Fabricate(:status, account: author, text: query)
    newer = Fabricate(:status, account: author, text: query)
    Fabricate(:status, account: viewer, text: query)

    expect(subject.call(query, viewer, limit: 1, offset: 1, account_id: author.id)).to eq([older])
    expect(subject.call(query, viewer, limit: 1, offset: 0, max_id: newer.id)).to eq([older])
  end
end
