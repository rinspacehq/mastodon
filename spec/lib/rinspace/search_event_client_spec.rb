# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::SearchEventClient do
  it 'sends a signed idempotent event without Tweet body data' do
    event = RinspaceSearchEventOutbox.new(
      event_id: 'event-1', status_id: 42, action: 'upsert', canonical_url: 'https://rinspace.com/p/42/tweet',
      public_version: 'status:42:v1', occurred_at: Time.utc(2026, 9, 26), next_attempt_at: Time.current
    )
    request = stub_request(:post, 'https://rinspace.test/internal/v1/search/events').to_return(status: 202)

    ClimateControl.modify RINSPACE_SEARCH_EVENT_ENDPOINT: 'https://rinspace.test/internal/v1/search/events', RINSPACE_SEARCH_EVENT_HMAC_KEY: 'k' * 32 do
      result = described_class.new.deliver(event)
      expect(result).to be_success
    end

    expect(request.with { |submitted|
      payload = JSON.parse(submitted.body)
      payload == {
        'eventId' => 'event-1', 'objectKind' => 'tweet', 'objectId' => '42', 'action' => 'upsert',
        'canonicalUrl' => 'https://rinspace.com/p/42/tweet', 'publicVersion' => 'status:42:v1', 'occurredAt' => '2026-09-26T00:00:00.000000Z'
      } && submitted.headers['Idempotency-Key'] == 'event-1' && submitted.headers['X-Rin-Signature'].match?(/\A[0-9a-f]{64}\z/)
    }).to have_been_requested
  end
end
