import type { List as ImmutableList, Map as ImmutableMap } from 'immutable';

import { showAlert } from '@/mastodon/actions/alerts';
import { submitComposeSuccess } from '@/mastodon/actions/compose';
import { importFetchedStatus } from '@/mastodon/actions/importer';
import { updateTimeline } from '@/mastodon/actions/timelines';
import { insertStatusIntoAccountTimelines } from '@/mastodon/actions/timelines_typed';
import type { ApiStatusJSON } from '@/mastodon/api_types/statuses';
import { browserHistory } from '@/mastodon/components/router';
import { resetComposer } from '@/mastodon/reducers/slices/composer';
import { createAppThunk } from '@/mastodon/store/typed_functions';

interface CompleteSharedComposerPublishInput {
  status: ApiStatusJSON;
  editing: boolean;
  redirectOnSuccess: boolean;
  publishedMessage: string;
  savedMessage: string;
  openMessage: string;
}

export const completeSharedComposerPublish = createAppThunk(
  (input: CompleteSharedComposerPublishInput, { dispatch, getState }) => {
    const { status } = input;
    dispatch(importFetchedStatus(status));

    const insertIfOnline = (timelineId: string) => {
      const timelines = getState().timelines as ImmutableMap<
        string,
        ImmutableMap<string, unknown>
      >;
      const timeline = timelines.get(timelineId);
      const items = timeline?.get('items') as
        | ImmutableList<unknown>
        | undefined;
      if (
        timeline &&
        items &&
        items.size > 0 &&
        items.first() !== null &&
        timeline.get('online') === true
      ) {
        dispatch(updateTimeline(timelineId, status));
      }
    };

    if (!input.editing && status.visibility !== 'direct')
      insertIfOnline('home');
    if (
      !input.editing &&
      !status.in_reply_to_id &&
      status.visibility === 'public'
    ) {
      insertIfOnline('community');
      insertIfOnline('public');
      insertIfOnline(`account:${status.account.id}`);
    }
    dispatch(insertStatusIntoAccountTimelines(status));
    dispatch(submitComposeSuccess(status));
    dispatch(resetComposer());

    if (input.redirectOnSuccess) {
      window.location.assign(status.url);
      return;
    }

    dispatch(
      showAlert({
        message: input.editing ? input.savedMessage : input.publishedMessage,
        action: input.openMessage,
        onClick: () => {
          browserHistory.push(`/p/${status.id}`, {
            focusTarget: 'detailed-status',
          });
        },
      }),
    );
  },
);
