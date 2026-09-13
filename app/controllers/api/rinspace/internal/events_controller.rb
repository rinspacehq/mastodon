# frozen_string_literal: true

class Api::Rinspace::Internal::EventsController < ActionController::API
  before_action :authenticate_adapter!

  EVENT_ID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  TOP_LEVEL_KEYS = %w(eventId aggregateType aggregateId eventType version payload).freeze
  ACCOUNT_PAYLOAD_KEYS = %w(uid status role version credentialEpoch).freeze
  SESSION_PAYLOAD_KEYS = %w(uid sid version).freeze

  def create
    event = parse_event!
    apply_once!(event)
    head :no_content
  rescue JSON::ParserError, ActionController::BadRequest, ActiveRecord::RecordInvalid
    render json: { error: 'invalid revocation event' }, status: :bad_request
  rescue RinspaceEventConflict
    render json: { error: 'revocation event conflicts with its receipt' }, status: :conflict
  end

  private

  RinspaceEventConflict = Class.new(StandardError)

  def authenticate_adapter!
    expected = ENV.fetch('RINSPACE_CREDENTIAL_ADAPTER_TOKEN', '')
    actual = request.authorization.to_s.delete_prefix('Bearer ')
    head :forbidden unless expected.bytesize >= 32 && actual.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(actual, expected)
  end

  def parse_event!
    raise ActionController::BadRequest if request.content_length.to_i > 16.kilobytes

    event = JSON.parse(request.raw_post)
    raise ActionController::BadRequest unless event.is_a?(Hash) && event.keys.sort == TOP_LEVEL_KEYS.sort
    raise ActionController::BadRequest unless event['eventId'].is_a?(String) && EVENT_ID.match?(event['eventId'])
    raise ActionController::BadRequest unless event['aggregateId'].is_a?(String) && event['aggregateId'].present? && event['aggregateId'].bytesize <= 200
    raise ActionController::BadRequest unless event['version'].is_a?(Integer) && event['version'].positive?
    raise ActionController::BadRequest unless event['payload'].is_a?(Hash)

    validate_payload!(event)
    event
  end

  def validate_payload!(event)
    payload = event['payload']
    case [event['aggregateType'], event['eventType']]
    when %w(account account.authorization_changed)
      raise ActionController::BadRequest unless payload.keys.sort == ACCOUNT_PAYLOAD_KEYS.sort
      raise ActionController::BadRequest unless payload['uid'] == event['aggregateId'] && payload['version'] == event['version']
      raise ActionController::BadRequest unless %w(active disabled suspended deleted).include?(payload['status'])
    when %w(session session.revoked)
      raise ActionController::BadRequest unless payload.keys.sort == SESSION_PAYLOAD_KEYS.sort
      raise ActionController::BadRequest unless payload['sid'] == event['aggregateId'] && payload['version'] == event['version']
    else
      raise ActionController::BadRequest
    end
  end

  def apply_once!(event)
    RinspaceAuthorizationEvent.transaction do
      receipt = RinspaceAuthorizationEvent.lock.find_by(event_id: event['eventId'])
      if receipt
        raise RinspaceEventConflict unless same_event?(receipt, event)

        true
      else
        apply_event!(event)
        RinspaceAuthorizationEvent.create!(
          event_id: event['eventId'], aggregate_type: event['aggregateType'], aggregate_id: event['aggregateId'],
          event_type: event['eventType'], version: event['version'], payload: event['payload'], applied_at: Time.current
        )
      end
    end
  rescue ActiveRecord::RecordNotUnique
    receipt = RinspaceAuthorizationEvent.find_by(event_id: event['eventId'])
    raise RinspaceEventConflict unless receipt && same_event?(receipt, event)
  end

  def apply_event!(event)
    if event['aggregateType'] == 'session'
      SessionActivation.where(rinspace_parent_sid: event['aggregateId'], rinspace_parent_version: ..event['version']).destroy_all
    elsif event.dig('payload', 'status') != 'active'
      SessionActivation.where(rinspace_parent_uid: event['aggregateId']).destroy_all
    end
  end

  def same_event?(receipt, event)
    receipt.aggregate_type == event['aggregateType'] && receipt.aggregate_id == event['aggregateId'] &&
      receipt.event_type == event['eventType'] && receipt.version == event['version'] && receipt.payload == event['payload']
  end
end
