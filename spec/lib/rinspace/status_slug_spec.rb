# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::StatusSlug do
  fixture = Rails.root.join('spec/fixtures/rinspace/status-slug-v1.json')
  cases = JSON.parse(File.read(fixture)).fetch('cases')

  cases.each do |test_case|
    it "matches the shared fixture #{test_case.fetch('name')}" do
      expect(described_class.call(
        text: test_case.fetch('text'),
        visibility: test_case.fetch('visibility'),
        sensitive: test_case.fetch('sensitive')
      )).to eq test_case.fetch('expected')
    end
  end
end
