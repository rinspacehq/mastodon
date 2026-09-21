import { useCallback } from 'react';

import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import { domain, sso_redirect } from 'mastodon/initial_state';
import {
  handleRinspaceLoginClick,
  rinspaceLoginHref,
  rinspaceLoginMethod,
} from 'mastodon/utils/rinspace_login';

import classes from '../styles.module.scss';

export const Header = () => {
  const openRinspaceLogin = useCallback(
    (event: React.MouseEvent<HTMLAnchorElement>) => {
      handleRinspaceLoginClick(event, sso_redirect);
    },
    [],
  );

  return (
    <div className={classes.minimalHeader}>
      <div className={classes.leftSide}>
        <Link to='/overview'>{domain}</Link>
      </div>

      <div className={classes.rightSide}>
        <a
          href={rinspaceLoginHref(sso_redirect)}
          data-method={rinspaceLoginMethod(sso_redirect)}
          onClick={openRinspaceLogin}
          className='button button-secondary'
        >
          <FormattedMessage
            id='sign_in_banner.sign_in'
            defaultMessage='Login'
          />
        </a>
      </div>
    </div>
  );
};
