import type React from 'react';
import { useCallback, useMemo } from 'react';

import { useIntl } from 'react-intl';

import type { List as ImmutableList, Map as ImmutableMap } from 'immutable';

import { quoteComposeCancel } from '@/mastodon/actions/compose_typed';
import { openModal } from '@/mastodon/actions/modal';
import '@/rinspace_shared/rinspace-tweet-composer.css';
import type { ApiMediaAttachmentJSON } from '@/mastodon/api_types/media_attachments';
import type {
  ApiStatusJSON,
  StatusVisibility,
} from '@/mastodon/api_types/statuses';
import type { AccountStatusShape } from '@/mastodon/models/status';
import {
  COMPOSER_TEXTAREA_ID,
  minimizeComposerToggle,
  resetComposer,
} from '@/mastodon/reducers/slices/composer';
import { selectPlainAccount } from '@/mastodon/selectors/accounts';
import { selectAccountStatus } from '@/mastodon/selectors/statuses';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';
import { unescapeHTML } from '@/mastodon/utils/html';
import {
  RinspaceTweetComposer,
  resolveTweetComposerMessages,
  useTweetComposerController,
} from '@/rinspace_shared/RinspaceTweetComposer';
import type { TweetComposerDraft } from '@/rinspace_shared/RinspaceTweetComposer';

import { createMastodonTweetComposerAdapter } from './rinspace_adapter';
import { completeSharedComposerPublish } from './rinspace_lifecycle';
import classes from './rinspace_shared.module.scss';

interface RedesignComposeFormProps {
  autoFocus?: boolean;
  className?: string;
  hidden?: boolean;
  noMinimize?: boolean;
  redirectOnSuccess?: boolean;
  role?: React.AriaRole;
  style?: React.CSSProperties;
}

type StoredMediaAttachment = ApiMediaAttachmentJSON & {
  unattached?: boolean;
};

function statusContext(status: AccountStatusShape | null) {
  if (!status) return undefined;
  return {
    displayName: status.account.display_name || status.account.username,
    avatarUrl: status.account.avatar_static || null,
    content: unescapeHTML(
      status.translation?.contentHtml ?? status.contentHtml,
    ),
  };
}

export const RedesignComposeForm: React.FC<RedesignComposeFormProps> = ({
  autoFocus,
  className = '',
  hidden,
  noMinimize,
  redirectOnSuccess = false,
  role = 'dialog',
  style,
}) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const messages = useMemo(
    () => resolveTweetComposerMessages(intl.locale),
    [intl.locale],
  );
  const compose = useAppSelector((state) => state.compose);
  const configuration = useAppSelector(
    (state) => state.server.server.item?.configuration,
  );
  const accountId = useAppSelector(
    (state) => state.meta.get('me') as string | null,
  );
  const account = useAppSelector((state) =>
    selectPlainAccount(state, accountId),
  );
  const replyId = compose.get('in_reply_to') as string | null;
  const quotedStatusId = compose.get('quoted_status_id') as string | null;
  const replyStatus = useAppSelector((state) =>
    selectAccountStatus(state, replyId),
  );
  const quoteStatus = useAppSelector((state) =>
    selectAccountStatus(state, quotedStatusId),
  );
  const editing = Boolean(compose.get('id'));

  const publishStatus = useCallback(
    (status: ApiStatusJSON) => {
      dispatch(
        completeSharedComposerPublish({
          status,
          editing,
          redirectOnSuccess,
          publishedMessage: messages.published,
          savedMessage: messages.save,
          openMessage: intl.locale.toLowerCase().startsWith('zh')
            ? '打开'
            : 'Open',
        }),
      );
    },
    [
      dispatch,
      editing,
      intl.locale,
      messages.published,
      messages.save,
      redirectOnSuccess,
    ],
  );

  const defaultVisibility = (compose.get('privacy') ??
    compose.get('default_privacy') ??
    'public') as StatusVisibility;
  const defaultLanguage = (compose.get('language') ??
    compose.get('default_language') ??
    'en') as string;
  const adapter = useMemo(
    () =>
      createMastodonTweetComposerAdapter({
        configuration,
        defaultLanguage,
        defaultVisibility,
        onStatus(status) {
          window.setTimeout(() => {
            publishStatus(status);
          }, 0);
        },
      }),
    [configuration, defaultLanguage, defaultVisibility, publishStatus],
  );

  const initialDraft = useMemo<Partial<TweetComposerDraft>>(() => {
    const storedMedia = compose.get('media_attachments') as ImmutableList<
      ImmutableMap<string, unknown>
    >;
    const storedPoll = compose.get('poll') as ImmutableMap<
      string,
      unknown
    > | null;
    return {
      text: compose.get('text') as string,
      sensitive: Boolean(compose.get('spoiler')),
      spoilerText: compose.get('spoiler_text') as string,
      visibility: defaultVisibility,
      language: defaultLanguage,
      media: storedMedia.toArray().map((entry) => {
        const media = entry.toJS() as unknown as StoredMediaAttachment;
        return {
          localId: media.id,
          id: media.id,
          type: media.type,
          url: media.url,
          previewUrl: media.preview_url,
          description: media.description ?? '',
          fileName: '',
          progress: 100,
          state: 'ready' as const,
        };
      }),
      poll: storedPoll
        ? {
            options: (
              storedPoll.get('options') as ImmutableList<string>
            ).toArray(),
            multiple: Boolean(storedPoll.get('multiple')),
            expiresIn: Number(storedPoll.get('expires_in')),
          }
        : null,
      inReplyToId: replyId ?? undefined,
      quotedStatusId: quotedStatusId ?? undefined,
      editStatusId: (compose.get('id') as string | null) ?? undefined,
    };
  }, [compose, defaultLanguage, defaultVisibility, quotedStatusId, replyId]);
  const controller = useTweetComposerController({
    adapter,
    initialDraft,
    messages,
  });

  const requestClose = useCallback(() => {
    if (controller.dirty) {
      dispatch(
        openModal({ modalType: 'COMPOSER_DRAFT_DELETE', modalProps: {} }),
      );
    } else {
      dispatch(resetComposer());
    }
  }, [controller.dirty, dispatch]);
  const removeQuote = useCallback(() => {
    controller.removeQuote();
    dispatch(quoteComposeCancel());
  }, [controller, dispatch]);
  const requestMinimize = useCallback(() => {
    dispatch(minimizeComposerToggle());
  }, [dispatch]);

  return (
    <RinspaceTweetComposer
      {...controller.composerProps}
      account={{
        displayName: account?.display_name.trim()
          ? account.display_name
          : (account?.username ?? 'Rinspace'),
        avatarUrl: account?.avatar_static ?? null,
      }}
      // eslint-disable-next-line jsx-a11y/no-autofocus -- opening the composer is an explicit user action
      autoFocus={autoFocus}
      className={`${className} ${classes.root}`.trim()}
      hidden={hidden}
      messages={messages}
      quoteContext={statusContext(quoteStatus)}
      replyContext={statusContext(replyStatus)}
      role={role}
      style={style}
      textareaId={COMPOSER_TEXTAREA_ID}
      onRemoveQuote={quotedStatusId ? removeQuote : undefined}
      onRequestClose={requestClose}
      onRequestMinimize={noMinimize ? undefined : requestMinimize}
    />
  );
};
