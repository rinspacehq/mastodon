# frozen_string_literal: true

require 'securerandom'

class Rinspace::SearchEventDeliveryWorker
  include Sidekiq::Worker

  sidekiq_options retry: 0

  BATCH_SIZE = 100
  MAX_ATTEMPTS = 8
  LEASE = 2.minutes

  def perform
    return unless ENV['RINSPACE_SEARCH_EVENTS_ENABLED'] == 'true'

    token = SecureRandom.uuid
    events = claim(token)
    events.each { |event| deliver(event, token) }
  end

  private

  def claim(token)
    RinspaceSearchEventOutbox.transaction do
      events = RinspaceSearchEventOutbox.ready.lock('FOR UPDATE SKIP LOCKED').limit(BATCH_SIZE).to_a
      RinspaceSearchEventOutbox.where(event_id: events.map(&:event_id)).update_all(delivery_state: 'delivering', lease_token: token, lease_until: LEASE.from_now, updated_at: Time.current)
      events.each { |event| event.assign_attributes(delivery_state: 'delivering', lease_token: token, lease_until: LEASE.from_now) }
      events
    end
  end

  def deliver(event, token)
    result = Rinspace::SearchEventClient.new.deliver(event)
    scope = RinspaceSearchEventOutbox.where(event_id: event.event_id, delivery_state: 'delivering', lease_token: token)
    if result.success?
      scope.update_all(delivery_state: 'delivered', lease_token: '', lease_until: nil, last_status_code: result.status_code, last_error_code: '', updated_at: Time.current)
      return
    end

    attempts = event.attempt_count + 1
    terminal = result.permanent_failure? || attempts >= MAX_ATTEMPTS
    delay = [2**attempts, 30.minutes.to_i].min
    scope.update_all(
      delivery_state: terminal ? 'dead_letter' : 'pending', lease_token: '', lease_until: nil,
      attempt_count: attempts, next_attempt_at: Time.current + delay,
      last_status_code: result.status_code, last_error_code: result.error_code, updated_at: Time.current
    )
    self.class.perform_in(delay) unless terminal
  end
end
