import { useCallback, useEffect } from 'react';

import { FormattedMessage } from 'react-intl';

import { fetchServer } from '@/mastodon/actions/server';
import { Button } from '@/mastodon/components/button/redesign';
import { Skeleton } from '@/mastodon/components/skeleton';
import { sso_redirect } from '@/mastodon/initial_state';
import { useAppDispatch, useAppSelector } from '@/mastodon/store';
import {
  handleRinspaceLoginClick,
  rinspaceLoginHref,
  rinspaceLoginMethod,
} from '@/mastodon/utils/rinspace_login';

import classes from './logged_out_info.module.scss';

export const LoggedOutInfo: React.FC = () => {
  const dispatch = useAppDispatch();
  const { item: serverItem, isLoading } = useAppSelector(
    (state) => state.server.server,
  );

  useEffect(() => {
    void dispatch(fetchServer());
  }, [dispatch]);
  const openRinspaceLogin = useCallback(
    (event: React.MouseEvent<HTMLAnchorElement>) => {
      handleRinspaceLoginClick(event, sso_redirect);
    },
    [],
  );

  return (
    <>
      <p className={classes.description}>
        {isLoading ? (
          <>
            <Skeleton width='100%' />
            <br />
            <Skeleton width='100%' />
            <br />
            <Skeleton width='70%' />
          </>
        ) : (
          serverItem?.description
        )}
      </p>
      <div className={classes.buttons}>
        <Button
          as='a'
          href={
            sso_redirect ? rinspaceLoginHref(sso_redirect) : '/auth/sign_up'
          }
          data-method={rinspaceLoginMethod(sso_redirect)}
          onClick={openRinspaceLogin}
          variant='solid'
        >
          <FormattedMessage
            id='server_banner.create_account'
            defaultMessage='Create an account'
          />
        </Button>
        <Button
          as='a'
          href={rinspaceLoginHref(sso_redirect)}
          data-method={rinspaceLoginMethod(sso_redirect)}
          onClick={openRinspaceLogin}
        >
          <FormattedMessage id='server_banner.log_in' defaultMessage='Log in' />
        </Button>
      </div>
    </>
  );
};
