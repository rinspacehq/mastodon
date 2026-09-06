# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mastodon::RinspaceLocalOnly do
  around do |example|
    original = Rails.configuration.x.mastodon.rinspace_local_only
    Rails.configuration.x.mastodon.rinspace_local_only = true
    described_class.instance_variable_set(:@local_hosts, nil)
    described_class.instance_variable_set(:@profile_media_hosts, nil)
    example.run
  ensure
    Rails.configuration.x.mastodon.rinspace_local_only = original
    described_class.instance_variable_set(:@local_hosts, nil)
    described_class.instance_variable_set(:@profile_media_hosts, nil)
  end

  it 'blocks federation discovery and protocol namespaces' do
    expect(described_class.blocked_inbound_path?('/.well-known/webfinger')).to be true
    expect(described_class.blocked_inbound_path?('/users/alice/inbox')).to be true
    expect(described_class.blocked_inbound_path?('/@alice@example.org')).to be true
    expect(described_class.blocked_inbound_path?('/api/v1/admin/domain_allows')).to be true
    expect(described_class.blocked_inbound_path?('/api/v1/timelines/home')).to be false
  end

  it 'recognizes ActivityStreams content negotiation on otherwise valid local pages' do
    env = { 'PATH_INFO' => '/@alice', 'HTTP_ACCEPT' => 'application/activity+json' }

    expect(described_class.blocked_inbound_request?(env)).to be true
  end

  it 'distinguishes local and remote handles' do
    expect(described_class.remote_account_reference?('@alice')).to be false
    expect(described_class.remote_account_reference?("@alice@#{Rails.configuration.x.local_domain}")).to be false
    expect(described_class.remote_account_reference?('@alice@example.org')).to be true
  end

  it 'allows only local HTTP destinations' do
    expect(described_class.allowed_outbound_url?("https://#{Rails.configuration.x.local_domain}/api/v1/instance")).to be true
    expect(described_class.allowed_outbound_url?('https://example.org/@alice')).to be false
  end

  it 'allows HTTPS profile media only from an explicit exact-host allowlist' do
    ClimateControl.modify RINSPACE_PROFILE_MEDIA_HOSTS: 'assets.example.org,cdn.example.org' do
      described_class.instance_variable_set(:@profile_media_hosts, nil)

      expect(described_class.allowed_profile_media_url?('https://assets.example.org/avatar/alice.png')).to be true
      expect(described_class.allowed_outbound_url?('https://cdn.example.org/avatar/alice.png')).to be true
      expect(described_class.allowed_profile_media_url?('http://assets.example.org/avatar/alice.png')).to be false
      expect(described_class.allowed_profile_media_url?('https://assets.example.org.evil.test/avatar.png')).to be false
      expect(described_class.allowed_profile_media_url?('https://user@assets.example.org/avatar.png')).to be false
    end
  end

  it 'blocks all FASP workers and known federation workers' do
    expect(described_class.blocked_worker?('Fasp::BackfillWorker')).to be true
    expect(described_class.blocked_worker?('ActivityPub::DeliveryWorker')).to be true
    expect(described_class.blocked_worker?('Webhooks::DeliveryWorker')).to be false
  end
end
