import { useEffect } from 'react';

import { closeModal } from 'mastodon/actions/modal';
import { sso_redirect } from 'mastodon/initial_state';
import { useAppDispatch } from 'mastodon/store';
import {
  requestRinspaceLogin,
  usesRinspaceLogin,
} from 'mastodon/utils/rinspace_login';

const RINSPACE_RECOVERY_PATH = '/auth/rinspace/recover';

/**
 * Rinspace is permanently local-only. Anonymous replies, likes, reposts,
 * quotes, bookmarks, follows and polls therefore share the same Rinspace
 * identity gate instead of Mastodon's remote-server interaction form.
 *
 * The original write is intentionally not replayed after authentication: the
 * visitor returns to the same page and confirms the social action again.
 */
const InteractionModal: React.FC = () => {
  const dispatch = useAppDispatch();

  useEffect(() => {
    dispatch(
      closeModal({
        modalType: 'INTERACTION',
        ignoreFocus: true,
      }),
    );

    requestRinspaceLogin(
      usesRinspaceLogin(sso_redirect) ? sso_redirect : RINSPACE_RECOVERY_PATH,
    );
  }, [dispatch]);

  return null;
};

// eslint-disable-next-line import/no-default-export
export default InteractionModal;
