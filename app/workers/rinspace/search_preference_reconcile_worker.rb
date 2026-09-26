# frozen_string_literal: true

class Rinspace::SearchPreferenceReconcileWorker
  include Sidekiq::Worker

  sidekiq_options retry: 5

  BATCH_SIZE = 200

  def perform(account_id, after_id = 0)
    statuses = Status.unscoped.kept.local.public_visibility.without_reblogs
      .where(account_id:, rinspace_review_state: 'approved')
      .where(Status.arel_table[:id].gt(after_id))
      .order(id: :asc)
      .limit(BATCH_SIZE)
      .includes(account: :user)
      .to_a
    recorded = statuses.map { |status| Rinspace::SearchEventRecorder.reconcile(status).present? }.any?
    Rinspace::SearchEventDeliveryWorker.perform_async if recorded
    self.class.perform_async(account_id, statuses.last.id) if statuses.length == BATCH_SIZE
  end
end
