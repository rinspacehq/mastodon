import axios from 'axios';
import { length } from 'stringz';

import api from '@/mastodon/api';
import { apiGetSearch } from '@/mastodon/api/search';
import type { ApiCustomEmojiJSON } from '@/mastodon/api_types/custom_emoji';
import type { ApiInstanceJSON } from '@/mastodon/api_types/instance';
import type { ApiMediaAttachmentJSON } from '@/mastodon/api_types/media_attachments';
import type { ApiStatusJSON } from '@/mastodon/api_types/statuses';
import { languages } from '@/mastodon/initial_state';
import { TweetComposerError } from '@/rinspace_shared/RinspaceTweetComposer';
import type {
  TweetComposerAdapter,
  TweetComposerConfig,
  TweetComposerPublishInput,
  TweetComposerUploadedMedia,
} from '@/rinspace_shared/RinspaceTweetComposer';

import { countableText } from '../util/counter';

interface MastodonTweetComposerAdapterOptions {
  configuration?: ApiInstanceJSON['configuration'];
  defaultLanguage: string;
  defaultVisibility: TweetComposerConfig['defaultVisibility'];
  onStatus(status: ApiStatusJSON, input: TweetComposerPublishInput): void;
}

interface MastodonErrorBody {
  error?: string | { code?: string; retryable?: boolean };
}

const POLL_DURATIONS = [300, 1_800, 3_600, 43_200, 86_400, 259_200, 604_800];

function composerError(error: unknown, fallback: string): TweetComposerError {
  if (error instanceof TweetComposerError) return error;
  if (!axios.isAxiosError<MastodonErrorBody>(error)) {
    return new TweetComposerError(fallback, fallback, true);
  }

  const bodyError = error.response?.data.error;
  const code =
    typeof bodyError === 'object' && bodyError.code
      ? bodyError.code
      : error.response?.status === 401
        ? 'authentication.required'
        : error.response?.status === 413
          ? 'composer.media_too_large'
          : fallback;
  const message = typeof bodyError === 'string' ? bodyError : code;
  const retryable =
    typeof bodyError === 'object'
      ? bodyError.retryable === true
      : !error.response || error.response.status >= 500;
  return new TweetComposerError(code, message, retryable);
}

function mediaResult(
  media: ApiMediaAttachmentJSON,
): TweetComposerUploadedMedia {
  return {
    id: media.id,
    type: media.type,
    url: media.url,
    previewUrl: media.preview_url,
  };
}

async function waitForMedia(
  mediaId: string,
  signal: AbortSignal,
): Promise<ApiMediaAttachmentJSON> {
  for (let attempt = 1; attempt <= 8; attempt += 1) {
    const response = await api().get<ApiMediaAttachmentJSON>(
      `/api/v1/media/${mediaId}`,
      { signal },
    );
    if (response.status === 200) return response.data;
    if (response.status !== 206)
      throw new TweetComposerError(
        'composer.media_upload_failed',
        'composer.media_upload_failed',
        true,
      );
    await new Promise<void>((resolve, reject) => {
      const timer = window.setTimeout(
        resolve,
        Math.min(4_000, Math.max(500, attempt * 500)),
      );
      signal.addEventListener(
        'abort',
        () => {
          window.clearTimeout(timer);
          reject(new DOMException('Aborted', 'AbortError'));
        },
        { once: true },
      );
    });
  }
  throw new TweetComposerError(
    'composer.media_upload_failed',
    'composer.media_upload_failed',
    true,
  );
}

function buildConfig(
  options: MastodonTweetComposerAdapterOptions,
): TweetComposerConfig {
  const configuration = options.configuration;
  const minPollDuration = configuration?.polls.min_expiration ?? 300;
  const maxPollDuration = configuration?.polls.max_expiration ?? 604_800;
  const pollDurations = POLL_DURATIONS.filter(
    (duration) => duration >= minPollDuration && duration <= maxPollDuration,
  );
  const imageLimit =
    configuration?.media_attachments.image_size_limit ?? 10 * 1024 * 1024;
  const videoLimit =
    configuration?.media_attachments.video_size_limit ?? 40 * 1024 * 1024;

  return {
    maxCharacters: configuration?.statuses.max_characters ?? 500,
    maxMediaAttachments: configuration?.statuses.max_media_attachments ?? 4,
    maxMediaBytes: Math.max(imageLimit, videoLimit),
    acceptedMediaTypes: configuration?.media_attachments
      .supported_mime_types ?? ['image/*', 'video/*', 'audio/*'],
    pollMinOptions: 2,
    pollMaxOptions: configuration?.polls.max_options ?? 4,
    pollMaxOptionCharacters:
      configuration?.polls.max_characters_per_option ?? 50,
    pollDurations: pollDurations.length > 0 ? pollDurations : [minPollDuration],
    languages: (languages ?? []).map(([code, name]) => ({ code, label: name })),
    defaultLanguage: options.defaultLanguage,
    defaultVisibility: options.defaultVisibility,
  };
}

export function createMastodonTweetComposerAdapter(
  options: MastodonTweetComposerAdapterOptions,
): TweetComposerAdapter {
  const adapter: TweetComposerAdapter = {
    countCharacters(value: string) {
      return length(countableText(value) as string);
    },
    loadConfig() {
      return Promise.resolve(buildConfig(options));
    },
    async loadEmojis(signal: AbortSignal) {
      try {
        const response = await api().get<ApiCustomEmojiJSON[]>(
          '/api/v1/custom_emojis',
          { signal },
        );
        return response.data
          .filter((emoji) => emoji.visible_in_picker)
          .map((emoji) => ({
            shortcode: emoji.shortcode,
            url: emoji.url,
            staticUrl: emoji.static_url,
            category: emoji.category,
          }));
      } catch (error) {
        throw composerError(error, 'composer.config_failed');
      }
    },
    async searchSuggestions(query, kind, signal) {
      try {
        const result = await apiGetSearch(
          {
            q: query,
            resolve: false,
            type: kind === 'account' ? 'accounts' : 'hashtags',
            limit: 8,
          },
          { signal },
        );
        if (kind === 'account') {
          return result.accounts.map((account) => ({
            id: account.id,
            kind,
            label: account.display_name || account.username,
            value: `@${account.acct}`,
            avatarUrl: account.avatar_static,
          }));
        }
        return result.hashtags.map((tag) => ({
          id: tag.name,
          kind,
          label: tag.name,
          value: `#${tag.name}`,
        }));
      } catch (error) {
        throw composerError(error, 'composer.suggestions_failed');
      }
    },
    async uploadMedia(input) {
      const { file, description, signal } = input;
      const data = new FormData();
      data.append('file', file);
      if (description) data.append('description', description);
      try {
        const response = await api().post<ApiMediaAttachmentJSON>(
          '/api/v2/media',
          data,
          {
            signal,
            onUploadProgress(progress) {
              const total = progress.total ?? file.size;
              input.onProgress(total > 0 ? (progress.loaded / total) * 100 : 0);
            },
          },
        );
        const media =
          response.status === 202
            ? await waitForMedia(response.data.id, signal)
            : response.data;
        input.onProgress(100);
        return mediaResult(media);
      } catch (error) {
        throw composerError(error, 'composer.media_upload_failed');
      }
    },
    async updateMediaDescription(mediaId, description, signal) {
      try {
        await api().put(
          `/api/v1/media/${mediaId}`,
          { description },
          { signal },
        );
      } catch (error) {
        throw composerError(error, 'composer.media_upload_failed');
      }
    },
    async publish(input, signal) {
      const data = {
        status: input.text,
        spoiler_text: input.spoilerText,
        in_reply_to_id: input.inReplyToId,
        quoted_status_id: input.quotedStatusId,
        media_ids: input.mediaIds,
        media_attributes: input.editStatusId
          ? input.mediaIds.map((id) => ({ id }))
          : undefined,
        sensitive: input.sensitive,
        visibility: input.visibility,
        poll: input.poll
          ? {
              options: input.poll.options,
              multiple: input.poll.multiple,
              expires_in: input.poll.expiresIn,
            }
          : null,
        language: input.language,
        quote_approval_policy:
          input.visibility === 'private' || input.visibility === 'direct'
            ? 'nobody'
            : 'public',
      };
      try {
        const response = await api().request<ApiStatusJSON>({
          url: input.editStatusId
            ? `/api/v1/statuses/${input.editStatusId}`
            : '/api/v1/statuses',
          method: input.editStatusId ? 'put' : 'post',
          data,
          headers: { 'Idempotency-Key': input.idempotencyKey },
          signal,
        });
        options.onStatus(response.data, input);
        return {
          id: response.data.id,
          url: response.data.url,
          createdAt: response.data.created_at,
        };
      } catch (error) {
        throw composerError(error, 'composer.publish_failed');
      }
    },
  };
  return Object.freeze(adapter);
}
