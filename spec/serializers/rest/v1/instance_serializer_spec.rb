# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::V1::InstanceSerializer do
  let(:serialization) { serialized_record_json(InstancePresenter.new, described_class) }

  before do
    allow(Mastodon::RinspaceLocalOnly).to receive(:enabled?).and_return(true)
  end

  it 'uses the Rinspace product description and preview asset' do
    expect(serialization['description']).to include('Rinspace').and include('inner world')
    expect(serialization['thumbnail']).to include('rinspace-mark-128')
    expect(serialization['thumbnail']).not_to include('preview')
  end
end
