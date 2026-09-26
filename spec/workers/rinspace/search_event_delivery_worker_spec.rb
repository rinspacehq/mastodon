# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::SearchEventDeliveryWorker do
  around do |example|
    ClimateControl.modify RINSPACE_SEARCH_EVENTS_ENABLED: 'true' do
      example.run
    end
  end

  def event(id)
    RinspaceSearchEventOutbox.create!(
      event_id: id, status_id: 91, action: 'upsert', canonical_url: 'https://rinspace.com/p/91/tweet',
      public_version: 'status:91:v1', occurred_at: Time.current, next_attempt_at: 1.minute.ago
    )
  end

  it 'marks an acknowledged delivery as delivered' do
    item = event('a' * 64)
    allow_any_instance_of(Rinspace::SearchEventClient).to receive(:deliver).and_return(
      Rinspace::SearchEventClient::Result.new(status_code: 202, error_code: '')
    )

    described_class.new.perform

    expect(item.reload).to have_attributes(delivery_state: 'delivered', attempt_count: 0, last_status_code: 202, lease_token: '')
  end

  it 'returns a transient failure to the bounded retry queue' do
    item = event('b' * 64)
    allow_any_instance_of(Rinspace::SearchEventClient).to receive(:deliver).and_return(
      Rinspace::SearchEventClient::Result.new(status_code: 503, error_code: 'upstream_status')
    )
    allow(described_class).to receive(:perform_in)

    described_class.new.perform

    expect(item.reload).to have_attributes(delivery_state: 'pending', attempt_count: 1, last_status_code: 503, last_error_code: 'upstream_status', lease_token: '')
    expect(described_class).to have_received(:perform_in)
  end

  it 'dead-letters a permanent rejection' do
    item = event('c' * 64)
    allow_any_instance_of(Rinspace::SearchEventClient).to receive(:deliver).and_return(
      Rinspace::SearchEventClient::Result.new(status_code: 400, error_code: 'upstream_status')
    )

    described_class.new.perform

    expect(item.reload).to have_attributes(delivery_state: 'dead_letter', attempt_count: 1, last_status_code: 400)
  end
end
