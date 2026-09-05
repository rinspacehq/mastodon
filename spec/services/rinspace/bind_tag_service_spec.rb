# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::BindTagService do
  it 'binds only an explicit stable tag ID and supports unbinding' do
    result = described_class.new.call(rinspace_tag_id: 42, name: 'Books', version: 1, active: true)
    expect(result.tag.name).to eq('books')
    expect(RinspaceTagBinding.find_by(rinspace_tag_id: 42)).to have_attributes(state: 'verified')

    described_class.new.call(rinspace_tag_id: 42, name: 'Books', version: 2, active: false)
    expect(RinspaceTagBinding.find_by(rinspace_tag_id: 42)).to have_attributes(state: 'unbound', binding_version: 2)
  end

  it 'ignores stale commands and rejects conflicting reuse of a version' do
    described_class.new.call(rinspace_tag_id: 43, name: 'Science', version: 3, active: true)
    stale = described_class.new.call(rinspace_tag_id: 43, name: 'OldScience', version: 2, active: false)
    expect(stale.tag.name).to eq('science')

    expect do
      described_class.new.call(rinspace_tag_id: 43, name: 'OtherScience', version: 3, active: true)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
