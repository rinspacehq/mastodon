import { render, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { RINSPACE_LOGIN_REQUEST_EVENT } from 'mastodon/utils/rinspace_login';

import InteractionModal from './index';

const dispatch = vi.hoisted(() => vi.fn());

vi.mock('mastodon/initial_state', () => ({
  sso_redirect: '/auth/rinspace/recover',
}));

vi.mock('mastodon/store', () => ({
  useAppDispatch: () => dispatch,
}));

describe('InteractionModal', () => {
  beforeEach(() => {
    dispatch.mockClear();
  });

  it('hands every anonymous social action to the unified Rinspace login gate', async () => {
    const loginRequest = vi.fn((event: Event) => {
      event.preventDefault();
    });
    window.addEventListener(RINSPACE_LOGIN_REQUEST_EVENT, loginRequest);

    const { container } = render(<InteractionModal />);

    await waitFor(() => {
      expect(loginRequest).toHaveBeenCalledOnce();
      expect(dispatch).toHaveBeenCalledWith({
        type: 'MODAL_CLOSE',
        payload: {
          modalType: 'INTERACTION',
          ignoreFocus: true,
        },
      });
    });
    expect(container.innerHTML).toBe('');

    window.removeEventListener(RINSPACE_LOGIN_REQUEST_EVENT, loginRequest);
  });
});
