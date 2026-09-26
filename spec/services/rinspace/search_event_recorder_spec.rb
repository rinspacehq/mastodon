# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::SearchEventRecorder do
  let(:account) { Fabricate(:account) }

  before do
    RinspaceSearchEventOutbox.delete_all
  end

  around do |example|
    ClimateControl.modify RINSPACE_SEARCH_EVENTS_ENABLED: 'true' do
      example.run
    end
  end

  it 'writes a body-free upsert transactionally for an eligible create' do
    status = Fabricate(:status, account:, text: 'Public body must not enter the outbox', visibility: :public, rinspace_review_state: 'approved')

    event = RinspaceSearchEventOutbox.find_by!(status_id: status.id, action: 'upsert')
    expect(event.canonical_url).to end_with("/p/#{status.id}/public-body-must-not-enter-the-outbox")
    expect(event.attributes.values.join(' ')).not_to include(status.text)
    expect(event.public_version).to start_with("status:#{status.id}:")
  end

  it 'writes delete with the last public canonical URL when eligibility is removed' do
    status = Fabricate(:status, account:, text: 'Last public slug', visibility: :public, rinspace_review_state: 'approved')

    status.update!(visibility: :private)

    event = RinspaceSearchEventOutbox.find_by!(status_id: status.id, action: 'delete')
    expect(event.canonical_url).to end_with("/p/#{status.id}/last-public-slug")
  end

  it 'writes a new upsert with the edited public slug and version' do
    status = Fabricate(:status, account:, text: 'Original public text', visibility: :public, rinspace_review_state: 'approved')
    original = RinspaceSearchEventOutbox.find_by!(status_id: status.id, action: 'upsert')

    status.update!(text: 'Edited public text', edited_at: 1.minute.from_now)

    edited = RinspaceSearchEventOutbox.where(status_id: status.id, action: 'upsert').order(occurred_at: :desc).first!
    expect(edited.event_id).not_to eq(original.event_id)
    expect(edited.public_version).not_to eq(original.public_version)
    expect(edited.canonical_url).to end_with("/p/#{status.id}/edited-public-text")
  end

  it 'writes delete with the last public canonical URL before destruction' do
    status = Fabricate(:status, account:, text: 'Deleted public text', visibility: :public, rinspace_review_state: 'approved')
    status_id = status.id

    status.destroy!

    event = RinspaceSearchEventOutbox.find_by!(status_id:, action: 'delete')
    expect(event.canonical_url).to end_with("/p/#{status_id}/deleted-public-text")
    expect(event.public_version).to start_with("deleted:#{status_id}:")
  end

  it 'does not write private or unlisted content to the outbox' do
    private_status = Fabricate(:status, account:, visibility: :private, rinspace_review_state: 'approved')
    unlisted_status = Fabricate(:status, account:, visibility: :unlisted, rinspace_review_state: 'approved')

    expect(RinspaceSearchEventOutbox.where(status_id: [private_status.id, unlisted_status.id])).to be_empty
  end

  it 'ignores interaction-only status updates' do
    status = Fabricate(:status, account:, visibility: :public, rinspace_review_state: 'approved')
    count = RinspaceSearchEventOutbox.count

    status.touch

    expect(RinspaceSearchEventOutbox.count).to eq(count)
  end

  it 'reconciles bounded public statuses when external indexing changes' do
    status = Fabricate(:status, account:, visibility: :public, rinspace_review_state: 'approved')
    account.user.settings.update('noindex' => true)
    account.user.save!

    Rinspace::SearchPreferenceReconcileWorker.new.perform(account.id)

    expect(RinspaceSearchEventOutbox.where(status_id: status.id, action: 'delete')).to exist
  end
end
