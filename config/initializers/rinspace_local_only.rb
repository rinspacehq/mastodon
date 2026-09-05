# frozen_string_literal: true

# This notification is the stable monitoring boundary. Log collectors should
# count it by `layer` and page immediately because the production baseline is zero.
ActiveSupport::Notifications.subscribe('rinspace.local_only.blocked') do |_name, _started, _finished, _id, payload|
  Rails.logger.error({
    event: 'rinspace.local_only.blocked.metric',
    metric: 'rinspace_local_only_blocked_total',
    layer: payload[:layer],
    source: payload[:source],
  }.to_json)
end
