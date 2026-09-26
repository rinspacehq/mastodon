# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::KnowledgeTagLinks do
  let(:status) { Fabricate(:status) }
  let(:tag) { Fabricate(:tag, name: 'oldname') }

  before do
    status.tags << tag
  end

  it 'returns only active audited bindings and follows canonical renames' do
    binding = RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'new-name', binding_version: 2, state: 'verified')

    expect(described_class.for(status)).to contain_exactly(
      have_attributes(id: '42', name: 'new-name', url: 'https://rinspace.com/tags/42/new-name')
    )

    binding.update!(state: 'retired')
    expect(described_class.for(status)).to be_empty
  end

  %w[unbound pending retired conflicting].each do |state|
    it "ignores #{state} bindings" do
      RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'tag', binding_version: 1, state:)

      expect(described_class.for(status)).to be_empty
    end
  end

  it 'does not infer an outer Tag from an unbound hashtag string' do
    expect(described_class.for(status)).to be_empty
  end
end
