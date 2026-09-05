# frozen_string_literal: true

require 'net/http'
require 'json'
require 'cgi'
require 'openssl'

class Rinspace::GorseClient
  class UnavailableError < StandardError; end

  def recommend(user_id:, limit:, offset: 0)
    path = "/api/recommend/#{CGI.escapeURIComponent(user_id)}?#{URI.encode_www_form(n: limit, offset:, category: 'mastodon-status')}"
    response = request(Net::HTTP::Get.new(path))
    JSON.parse(response.body).filter_map do |value|
      match = /\Amastodon-status:(\d+)\z/.match(value.to_s)
      match[1].to_i if match
    end.uniq
  rescue JSON::ParserError
    raise UnavailableError
  end

  def upsert_status(status_id:, hidden:, timestamp: nil)
    payload = [{
      ItemId: "mastodon-status:#{status_id}",
      Categories: ['mastodon-status'],
      IsHidden: hidden,
      Timestamp: timestamp&.utc&.iso8601,
    }.compact]
    request(Net::HTTP::Post.new('/api/items'), payload)
    true
  end

  def feedback(subject:, status_id:, feedback_type:, value: 1)
    payload = [{ FeedbackType: feedback_type, UserId: subject, ItemId: "mastodon-status:#{status_id}", Value: value, Timestamp: Time.now.utc.iso8601 }]
    request(Net::HTTP::Post.new('/api/feedback'), payload)
    true
  end

  def delete_feedback(subject:, status_id:, feedback_type:)
    path = "/api/feedback/#{CGI.escapeURIComponent(feedback_type)}/#{CGI.escapeURIComponent(subject)}/mastodon-status%3A#{status_id}"
    request(Net::HTTP::Delete.new(path))
    true
  end

  def clear_user(subject:)
    request(Net::HTTP::Delete.new("/api/user/#{CGI.escapeURIComponent(subject)}"))
    true
  end

  private

  def request(message, payload = nil)
    endpoint = URI.parse(ENV.fetch('RINSPACE_GORSE_ENDPOINT', ''))
    api_key = ENV.fetch('RINSPACE_GORSE_API_KEY', '')
    raise UnavailableError unless %w[http https].include?(endpoint.scheme) && endpoint.host.present? && endpoint.userinfo.nil? && endpoint.fragment.nil? && ['', '/'].include?(endpoint.path) && api_key.present?

    message['Accept'] = 'application/json'
    message['X-API-Key'] = api_key
    if payload
      message['Content-Type'] = 'application/json'
      message.body = JSON.generate(payload)
    end
    response = Net::HTTP.start(endpoint.host, endpoint.port, use_ssl: endpoint.scheme == 'https', open_timeout: 2, read_timeout: 3) do |http|
      http.request(message)
    end
    raise UnavailableError unless response.is_a?(Net::HTTPSuccess)

    response
  rescue URI::InvalidURIError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
    raise UnavailableError
  end
end
