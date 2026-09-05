# frozen_string_literal: true

class Rinspace::BindTagService
  Result = Data.define(:tag, :version)

  def call(rinspace_tag_id:, name:, version:, active:)
    rinspace_tag_id = Integer(rinspace_tag_id)
    version = Integer(version)
    normalized_name = HashtagNormalizer.new.normalize(name.to_s)
    raise ArgumentError, 'invalid tag binding' if rinspace_tag_id <= 0 || normalized_name.blank? || version.negative?

    desired_state = active ? 'verified' : 'unbound'
    RinspaceTagBinding.transaction do
      binding = RinspaceTagBinding.lock.find_by(rinspace_tag_id:)
      return Result.new(tag: binding.tag, version: binding.binding_version) if binding && version < binding.binding_version
      if binding && version == binding.binding_version && (binding.canonical_name != normalized_name || binding.state != desired_state)
        raise ActiveRecord::RecordInvalid, binding
      end

      tag = Tag.find_or_create_by_names(normalized_name).first
      raise ActiveRecord::RecordInvalid, tag unless tag

      attributes = { tag:, canonical_name: tag.name, binding_version: version, state: desired_state }
      binding ? binding.update!(attributes) : binding = RinspaceTagBinding.create!(rinspace_tag_id:, **attributes)
      Result.new(tag: binding.tag, version: binding.binding_version)
    end
  end
end
