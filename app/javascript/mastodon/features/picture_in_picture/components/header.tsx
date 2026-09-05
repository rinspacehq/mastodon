import { defineMessages, useIntl } from 'react-intl';

import { Link } from 'react-router-dom';

import CloseIcon from '@/material-icons/400-24px/close.svg?react';
import { Avatar } from 'mastodon/components/avatar';
import { DisplayName } from 'mastodon/components/display_name';
import { IconButton } from 'mastodon/components/icon_button';
import { useAppSelector } from 'mastodon/store';
import { statusPathFromUrl } from 'mastodon/utils/status_path';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
});

interface Props {
  accountId: string;
  statusId: string;
  onClose: () => void;
}

export const Header: React.FC<Props> = ({ accountId, statusId, onClose }) => {
  const account = useAppSelector((state) => state.accounts.get(accountId));
  const status = useAppSelector((state) => state.statuses.get(statusId));

  const intl = useIntl();

  if (!account) return null;

  return (
    <div className='picture-in-picture__header'>
      <Link
        to={statusPathFromUrl(statusId, status?.get('url') as string | null)}
        className='picture-in-picture__header__account'
      >
        <Avatar account={account} size={36} />
        <DisplayName account={account} />
      </Link>

      <IconButton
        icon='times'
        iconComponent={CloseIcon}
        onClick={onClose}
        title={intl.formatMessage(messages.close)}
      />
    </div>
  );
};
