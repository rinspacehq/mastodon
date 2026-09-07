# frozen_string_literal: true

class Api::Rinspace::V1::ComposerController < Api::Rinspace::V1::BaseController
  include FormattingHelper

  POLL_DURATIONS = [5.minutes, 30.minutes, 1.hour, 12.hours, 1.day, 3.days, 7.days].map(&:to_i).freeze
  STATUS_PAGE_SIZE = 20

  rescue_from ActiveRecord::RecordNotFound do
    render_error('social.identity_unbound', :not_found, false)
  end

  rescue_from ActiveRecord::RecordInvalid, Mastodon::ValidationError, PostStatusService::UnexpectedMentionsError do
    render_error('social.moderation_rejected', :unprocessable_content, false)
  end

  def show_config
    binding = verified_binding!(params.require(:subject))
    render json: {
      maxCharacters: StatusLengthValidator::MAX_CHARS,
      maxMediaAttachments: Status::MEDIA_ATTACHMENTS_LIMIT,
      maxMediaBytes: MediaAttachment::VIDEO_LIMIT,
      acceptedMediaTypes: MediaAttachment.supported_mime_types,
      pollMinOptions: 2,
      pollMaxOptions: PollOptionsValidator::MAX_OPTIONS,
      pollMaxOptionCharacters: PollOptionsValidator::MAX_OPTION_CHARS,
      pollDurations: POLL_DURATIONS,
      languages: composer_languages,
      defaultLanguage: binding.account.user&.locale.presence || I18n.default_locale.to_s,
      defaultVisibility: 'public',
    }
  end

  def emojis
    verified_binding!(params.require(:subject))
    values = CustomEmoji.listed.includes(:category).filter_map do |emoji|
      serialized = REST::CustomEmojiSerializer.new(emoji).serializable_hash
      next if serialized[:url].blank? || serialized[:static_url].blank?

      {
        shortcode: serialized[:shortcode],
        url: serialized[:url],
        staticUrl: serialized[:static_url],
        category: serialized[:category],
      }.compact
    end
    render json: values
  end

  def suggestions
    binding = verified_binding!(params.require(:subject))
    query = params.require(:q).to_s.strip.first(64)
    return render(json: []) if query.length < 2

    values = if params[:type] == 'account'
               AccountSearchService.new.call(query, binding.account, limit: 8, resolve: false)
                 .select(&:local?)
                 .map do |account|
                   {
                     id: account.id.to_s,
                     kind: 'account',
                     label: account.display_name.presence || account.username,
                     value: "@#{account.username}",
                   }
                 end
             elsif params[:type] == 'hashtag'
               TagSearchService.new.call(query, limit: 8).map do |tag|
                 label = tag.display_name.presence || tag.name
                 { id: tag.id.to_s, kind: 'hashtag', label: label, value: "##{label}" }
               end
             else
               return render_error('composer.invalid_suggestion_type', :unprocessable_content, false)
             end
    render json: values
  end

  def create_media
    binding = verified_binding!(params.require(:subject))
    description = params[:description].to_s.strip.first(MediaAttachment::MAX_DESCRIPTION_LENGTH)
    review_text!(binding, 'media_description', request.request_id, description) if description.present?
    attachment = binding.account.media_attachments.create!(file: params.require(:file), description: description)
    render json: media_payload(attachment)
  rescue Paperclip::Error
    render_error('composer.media_upload_failed', :unprocessable_content, true)
  end

  def update_media
    binding = verified_binding!(params.require(:subject))
    description = params[:description].to_s.strip.first(MediaAttachment::MAX_DESCRIPTION_LENGTH)
    review_text!(binding, 'media_description', params[:id], description) if description.present?
    attachment = binding.account.media_attachments.where(status_id: nil).find(params[:id])
    attachment.update!(description: description)
    render json: media_payload(attachment)
  end

  def create_status
    binding = verified_binding!(params.require(:subject))
    input = status_params
    idempotency_key = request.headers['Idempotency-Key'].to_s.strip
    return render_error('composer.idempotency_required', :unprocessable_content, false) unless idempotency_key.length.between?(16, 255) && input[:idempotencyKey].to_s.strip == idempotency_key

    review_status!(binding, input)
    status = if input[:editStatusId].present?
               update_status(binding, input)
             else
               publish_status(binding, input)
             end
    status.update!(rinspace_review_state: 'approved') if ENV['RINSPACE_IDENTITY_STRICT'] == 'true'
    render json: {
      id: status.id.to_s,
      url: ActivityPub::TagManager.instance.url_for(status).to_s,
      createdAt: status.created_at.iso8601(3),
    }
  end

  def account_statuses
    binding = verified_binding!(params.require(:subject))
    statuses = binding.account.statuses.distributable_visibility.without_reblogs
    statuses = statuses.where(id: ...params[:max_id].to_i) if params[:max_id].present?
    statuses = statuses.limit(STATUS_PAGE_SIZE + 1).to_a
    has_more = statuses.length > STATUS_PAGE_SIZE
    statuses = statuses.first(STATUS_PAGE_SIZE)
    render json: {
      accountId: binding.account_id.to_s,
      items: statuses.map { |status| status_payload(status) },
      nextMaxId: has_more ? statuses.last&.id&.to_s : nil,
    }
  end

  private

  def verified_binding!(subject)
    RinspaceIdentityBinding.find_by!(subject: subject.to_s.strip, state: 'verified')
  end

  def composer_languages
    LanguagesHelper.sorted_locale_keys(LanguagesHelper::SUPPORTED_LOCALES.keys).map do |code|
      names = LanguagesHelper::SUPPORTED_LOCALES.fetch(code)
      { code: code.to_s, label: names[1].presence || names[0] }
    end
  end

  def status_params
    params.permit(
      :subject, :text, :sensitive, :spoilerText, :visibility, :language,
      :inReplyToId, :quotedStatusId, :editStatusId, :idempotencyKey, mediaIds: [], poll: [:multiple, :expiresIn, { options: [] }]
    )
  end

  def publish_status(binding, input)
    thread = Status.find(input[:inReplyToId]) if input[:inReplyToId].present?
    raise Mastodon::ValidationError if thread && !StatusPolicy.new(binding.account, thread).show?

    quoted_status = Status.find(input[:quotedStatusId])&.proper if input[:quotedStatusId].present?
    raise Mastodon::ValidationError if quoted_status && !StatusPolicy.new(binding.account, quoted_status).quote?

    PostStatusService.new.call(
      binding.account,
      text: input[:text].to_s,
      thread: thread,
      quoted_status: quoted_status,
      quote_approval_policy: %w(private direct).include?(normalized_visibility(input[:visibility])) ? 'nobody' : 'public',
      media_ids: Array(input[:mediaIds]),
      sensitive: ActiveModel::Type::Boolean.new.cast(input[:sensitive]),
      spoiler_text: input[:spoilerText].to_s,
      visibility: normalized_visibility(input[:visibility]),
      language: input[:language].presence,
      application: nil,
      poll: poll_attributes(input[:poll]),
      idempotency: input[:idempotencyKey].to_s,
      with_rate_limit: true
    )
  end

  def update_status(binding, input)
    status = binding.account.statuses.find(input[:editStatusId])
    UpdateStatusService.new.call(status, binding.account.id, {
      text: input[:text].to_s,
      media_ids: Array(input[:mediaIds]),
      sensitive: ActiveModel::Type::Boolean.new.cast(input[:sensitive]),
      spoiler_text: input[:spoilerText].to_s,
      language: input[:language].presence,
      poll: poll_attributes(input[:poll]),
    })
    status
  end

  def poll_attributes(value)
    return if value.blank?

    {
      options: Array(value[:options]).map(&:to_s),
      multiple: ActiveModel::Type::Boolean.new.cast(value[:multiple]),
      expires_in: value[:expiresIn].to_i,
    }
  end

  def normalized_visibility(value)
    visibility = value.to_s
    %w(public unlisted private direct).include?(visibility) ? visibility : 'public'
  end

  def review_status!(binding, input)
    return unless ENV['RINSPACE_IDENTITY_STRICT'] == 'true'

    text = [input[:spoilerText], input[:text], *Array(input.dig(:poll, :options))].compact.join("\n")
    review_text!(binding, input[:editStatusId].present? ? 'status_edit' : 'status', input[:editStatusId].presence || request.request_id, text)
  end

  def review_text!(binding, target_type, target_id, text)
    return unless ENV['RINSPACE_IDENTITY_STRICT'] == 'true'

    Rinspace::ModerationClient.new.review_text!(
      subject: binding.subject,
      target_type: target_type,
      target_id: target_id,
      title: '',
      text: text
    )
  end

  def media_payload(attachment)
    serialized = REST::MediaAttachmentSerializer.new(attachment).serializable_hash
    {
      id: attachment.id.to_s,
      type: attachment.type,
      url: serialized[:url].to_s,
      previewUrl: serialized[:preview_url].to_s,
    }
  end

  def status_payload(status)
    {
      id: status.id.to_s,
      url: ActivityPub::TagManager.instance.url_for(status).to_s,
      content: status_content_format(status),
      spoilerText: status.spoiler_text.to_s,
      visibility: status.visibility,
      language: status.language,
      createdAt: status.created_at.iso8601(3),
      repliesCount: status.replies_count,
      reblogsCount: status.reblogs_count,
      favouritesCount: status.favourites_count,
      media: status.ordered_media_attachments.map do |attachment|
        media_payload(attachment).merge(description: attachment.description.to_s)
      end,
    }
  end

  def render_error(code, status, retryable)
    render json: {
      error: {
        code: code,
        message: code,
        retryable: retryable,
        correlationId: request.request_id,
      },
    }, status: status
  end
end
