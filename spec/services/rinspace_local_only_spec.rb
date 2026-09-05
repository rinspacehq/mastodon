# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace local-only service boundary' do
  around do |example|
    original = Rails.configuration.x.mastodon.rinspace_local_only
    Rails.configuration.x.mastodon.rinspace_local_only = true
    Mastodon::RinspaceLocalOnly.instance_variable_set(:@local_hosts, nil)
    example.run
  ensure
    Rails.configuration.x.mastodon.rinspace_local_only = original
    Mastodon::RinspaceLocalOnly.instance_variable_set(:@local_hosts, nil)
  end

  it 'does not resolve a remote account, including one already cached' do
    Fabricate(:account, username: 'alice', domain: 'example.org')

    expect(ResolveAccountService.new.call('alice@example.org', skip_webfinger: true)).to be_nil
    expect(a_request(:get, %r{example\.org})).not_to have_been_made
  end

  it 'does not resolve or fetch a remote URL' do
    expect(ResolveURLService.new.call('https://example.org/@alice/1')).to be_nil
    expect(FetchRemoteStatusService.new.call('https://example.org/@alice/1')).to be_nil
    expect(a_request(:get, %r{example\.org})).not_to have_been_made
  end

  it 'returns only local statuses from the public feed and empties remote-only mode' do
    local_status = Fabricate(:status, account: Fabricate(:account, domain: nil))
    remote_status = Fabricate(:status, account: Fabricate(:account, domain: 'example.org'))

    expect(PublicFeed.new(nil).get(20)).to include(local_status)
    expect(PublicFeed.new(nil).get(20)).not_to include(remote_status)
    expect(PublicFeed.new(nil, remote: true).get(20)).to be_empty
  end

  it 'blocks a direct public HTTP request before a socket is opened' do
    expect { Request.new(:get, 'https://example.org/data') }
      .to raise_error(Mastodon::RinspaceLocalOnly::OutboundRequestBlocked)
    expect(a_request(:get, %r{example\.org})).not_to have_been_made
  end

  it 'cannot follow a cached remote account' do
    source = Fabricate(:account)
    target = Fabricate(:account, domain: 'example.org')

    expect { FollowService.new.call(source, target) }.to raise_error(Mastodon::NotPermittedError)
    expect(source.following?(target)).to be false
  end

  it 'filters remote statuses before home streaming fan-out' do
    remote_status = Fabricate(:status, account: Fabricate(:account, domain: 'example.org'))
    receiver = Fabricate(:account)

    expect(FeedManager.instance.filter(:home, remote_status, receiver)).to eq :filter
  end
end
