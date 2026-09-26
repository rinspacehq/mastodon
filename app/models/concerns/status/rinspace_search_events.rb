# frozen_string_literal: true

module Status::RinspaceSearchEvents
  extend ActiveSupport::Concern

  included do
    after_create :record_rinspace_search_creation
    before_update :record_rinspace_search_change
    before_destroy :record_rinspace_search_deletion
    after_commit :enqueue_rinspace_search_delivery, on: %i[create update destroy]
  end

  private

  def record_rinspace_search_creation
    @rinspace_search_event_recorded = Rinspace::SearchEventRecorder.status_created(self).present?
  end

  def record_rinspace_search_change
    @rinspace_search_event_recorded = Rinspace::SearchEventRecorder.status_changing(self).present?
  end

  def record_rinspace_search_deletion
    @rinspace_search_event_recorded = Rinspace::SearchEventRecorder.status_deleted(self).present?
  end

  def enqueue_rinspace_search_delivery
    return unless @rinspace_search_event_recorded

    @rinspace_search_event_recorded = false
    Rinspace::SearchEventDeliveryWorker.perform_async
  end
end
