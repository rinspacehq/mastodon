# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::StatusViewIncrementWorker do
  it 'atomically increments one aggregate without storing viewer events' do
    status = Fabricate(:status)
    2.times { described_class.new.perform(status.id) }

    expect(status.reload.views_count).to eq(2)
    expect(StatusStat.where(status:).count).to eq(1)
  end
end
