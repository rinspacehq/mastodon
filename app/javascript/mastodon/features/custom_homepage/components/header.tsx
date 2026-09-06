import { FormattedMessage } from 'react-intl';

import { Link } from 'react-router-dom';

import { domain, sso_redirect } from 'mastodon/initial_state';
import {
  rinspaceLoginHref,
  rinspaceLoginMethod,
} from 'mastodon/utils/rinspace_login';

import classes from '../styles.module.scss';

export const Header = () => (
  <div className={classes.minimalHeader}>
    <div className={classes.leftSide}>
      <Link to='/overview'>{domain}</Link>
    </div>

    <div className={classes.rightSide}>
      <a
        href={rinspaceLoginHref(sso_redirect)}
        data-method={rinspaceLoginMethod(sso_redirect)}
        className='button button-secondary'
      >
        <FormattedMessage id='sign_in_banner.sign_in' defaultMessage='Login' />
      </a>
    </div>
  </div>
);
