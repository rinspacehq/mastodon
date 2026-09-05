# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mastodon::RinspaceLocalOnlySidekiqMiddleware do
  around do |example|
    original = Rails.configuration.x.mastodon.rinspace_local_only
    Rails.configuration.x.mastodon.rinspace_local_only = true
    example.run
  ensure
    Rails.configuration.x.mastodon.rinspace_local_only = original
  end

  it 'discards a federation delivery job' do
    expect { |block| subject.call('ActivityPub::DeliveryWorker', { 'class' => 'ActivityPub::DeliveryWorker' }, 'push', &block) }.not_to yield_control
  end

  it 'discards every FASP job' do
    expect { |block| subject.call('Fasp::BackfillWorker', { 'class' => 'Fasp::BackfillWorker' }, 'default', &block) }.not_to yield_control
  end

  it 'allows an unrelated local job' do
    expect { |block| subject.call('MailDeliveryJob', { 'class' => 'MailDeliveryJob' }, 'mailers', &block) }.to yield_control
  end
end
