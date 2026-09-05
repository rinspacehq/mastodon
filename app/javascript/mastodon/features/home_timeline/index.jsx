import PropTypes from 'prop-types';
import { PureComponent } from 'react';

import { defineMessages, FormattedMessage } from 'react-intl';

import classNames from 'classnames';
import { Helmet } from '@unhead/react/helmet';

import { connect } from 'react-redux';

import api from 'mastodon/api';

import CampaignIcon from '@/material-icons/400-24px/campaign.svg?react';
import HomeIcon from '@/material-icons/400-24px/home-fill.svg?react';
import { Column } from '@/mastodon/components/column';
import { ColumnHeader as LegacyColumnHeader } from '@/mastodon/components/column/header';
import { injectIntl } from '@/mastodon/components/intl';
import { SymbolLogo } from 'mastodon/components/logo';
import { fetchAnnouncements, toggleShowAnnouncements } from 'mastodon/actions/announcements';
import { IconWithBadge } from 'mastodon/components/icon_with_badge';
import { NotSignedInIndicator } from 'mastodon/components/not_signed_in_indicator';
import { identityContextPropShape, withIdentity } from 'mastodon/identity_context';
import { withBreakpoint } from 'mastodon/features/ui/hooks/useBreakpoint';

import { addColumn, removeColumn, moveColumn } from '../../actions/columns';
import { expandHomeTimeline, expandRecommendedTimeline } from '../../actions/timelines';
import StatusListContainer from '../ui/containers/status_list_container';

import { ColumnSettings } from './components/column_settings';
import { CriticalUpdateBanner } from './components/critical_update_banner';
import { Announcements } from './components/announcements';
import { AnnualReportTimeline } from '../annual_report/timeline';
import { isRedesignEnabled } from '@/mastodon/utils/environment';
import { ColumnHeader } from '@/mastodon/components/column_header';
import { HomeColumnSettings } from './components/column_settings_redesign';
import { MultiColumnMenuItems } from '@/mastodon/components/column_header/multicolumn_settings';

const messages = defineMessages({
  title: { id: 'column.home', defaultMessage: 'Home' },
  following: { id: 'column.following', defaultMessage: 'Following' },
  show_announcements: { id: 'home.show_announcements', defaultMessage: 'Show announcements' },
  hide_announcements: { id: 'home.hide_announcements', defaultMessage: 'Hide announcements' },
  recommended: { id: 'rinspace.home.recommended', defaultMessage: 'Recommended' },
  disable_personalization: { id: 'rinspace.home.disable_personalization', defaultMessage: 'Turn off personalization' },
  recommendation_settings: { id: 'rinspace.home.recommendation_settings', defaultMessage: 'Recommendation settings' },
  recommendation_interests_empty: { id: 'rinspace.home.recommendation_interests_empty', defaultMessage: 'No explicit interest tags are stored.' },
  clear_recommendation_profile: { id: 'rinspace.home.clear_recommendation_profile', defaultMessage: 'Clear recommendation profile' },
  recommendation_explanation: { id: 'rinspace.home.recommendation_explanation', defaultMessage: 'Ranked from minimized local interactions after visibility and safety checks.' },
});

const mapStateToProps = state => ({
  hasUnread: state.getIn(['timelines', 'home', 'unread']) > 0,
  isPartial: state.getIn(['timelines', 'home', 'isPartial']),
  hasAnnouncements: !state.getIn(['announcements', 'items']).isEmpty(),
  unreadAnnouncements: state.getIn(['announcements', 'items']).count(item => !item.get('read')),
  showAnnouncements: state.getIn(['announcements', 'show']),
});

class HomeTimeline extends PureComponent {
	state = {
	  activeFeed: localStorage.getItem('rinspace.homeFeed') || 'recommended',
	  personalized: true,
	  interests: [],
	};

  static propTypes = {
    identity: identityContextPropShape,
    dispatch: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
    hasUnread: PropTypes.bool,
    isPartial: PropTypes.bool,
    columnId: PropTypes.string,
    multiColumn: PropTypes.bool,
    hasAnnouncements: PropTypes.bool,
    unreadAnnouncements: PropTypes.number,
    showAnnouncements: PropTypes.bool,
    matchesBreakpoint: PropTypes.bool,
  };

  handlePin = () => {
    const { columnId, dispatch } = this.props;

    if (columnId) {
      dispatch(removeColumn(columnId));
    } else {
      dispatch(addColumn('HOME', {}));
    }
  };

  handleMove = (dir) => {
    const { columnId, dispatch } = this.props;
    dispatch(moveColumn(columnId, dir));
  };

  handleLoadMore = maxId => {
	this.props.dispatch(this.state.activeFeed === 'recommended' ? expandRecommendedTimeline({ maxId }) : expandHomeTimeline({ maxId }));
  };

  componentDidMount () {
    setTimeout(() => this.props.dispatch(fetchAnnouncements()), 700);
	this.loadRinspacePreferences();
    this._checkIfReloadNeeded(false, this.props.isPartial);
  }

	loadRinspacePreferences = async () => {
	  try {
	    const response = await api().get('/api/v1/rinspace_preferences');
	    const personalized = response.data.personalizedRecommendations;
	    const activeFeed = personalized ? response.data.homeFeed : 'following';
	    localStorage.setItem('rinspace.homeFeed', activeFeed);
	    this.setState({ personalized, activeFeed, interests: response.data.interests || [] });
	    this.props.dispatch(activeFeed === 'recommended' ? expandRecommendedTimeline() : expandHomeTimeline());
	  } catch {
	    localStorage.setItem('rinspace.homeFeed', 'following');
	    this.setState({ personalized: false, activeFeed: 'following', interests: [] });
	    this.props.dispatch(expandHomeTimeline());
	  }
	};

	selectFeed = async activeFeed => {
	  if (activeFeed === 'recommended' && !this.state.personalized) return;
	  localStorage.setItem('rinspace.homeFeed', activeFeed);
	  this.setState({ activeFeed });
	  this.props.dispatch(activeFeed === 'recommended' ? expandRecommendedTimeline() : expandHomeTimeline());
	  try {
	    await api().put('/api/v1/rinspace_preferences', { personalizedRecommendations: this.state.personalized, homeFeed: activeFeed });
	  } catch {
	    // The local selection remains usable; the server will retry on the next explicit change.
	  }
	};

	disablePersonalization = async () => {
	  try {
	    await api().put('/api/v1/rinspace_preferences', { personalizedRecommendations: false, homeFeed: 'following' });
	    localStorage.setItem('rinspace.homeFeed', 'following');
	    this.setState({ personalized: false, activeFeed: 'following' });
	    this.props.dispatch(expandHomeTimeline());
	  } catch {
	    // Fail closed: do not claim personalization is disabled until the server confirms it.
	  }
	};

	clearRecommendationProfile = async () => {
	  try {
	    await api().delete('/api/v1/rinspace_preferences');
	    localStorage.setItem('rinspace.homeFeed', 'following');
	    this.setState({ personalized: false, activeFeed: 'following', interests: [] });
	    this.props.dispatch(expandHomeTimeline());
	  } catch {
	    // Keep the current state until deletion is confirmed by the server.
	  }
	};

	removeInterest = async interest => {
	  try {
	    const response = await api().delete(`/api/v1/rinspace_preferences/interests/${encodeURIComponent(interest)}`);
	    this.setState({ interests: response.data.interests || [] });
	  } catch {
	    // Keep the visible profile unchanged until the server confirms deletion.
	  }
	};

  componentDidUpdate (prevProps) {
    this._checkIfReloadNeeded(prevProps.isPartial, this.props.isPartial);
  }

  componentWillUnmount () {
    this._stopPolling();
  }

  _checkIfReloadNeeded (wasPartial, isPartial) {
    const { dispatch } = this.props;

    if (wasPartial === isPartial) {
      return;
    } else if (!wasPartial && isPartial) {
      this.polling = setInterval(() => {
        dispatch(expandHomeTimeline());
      }, 3000);
    } else if (wasPartial && !isPartial) {
      this._stopPolling();
    }
  }

  _stopPolling () {
    if (this.polling) {
      clearInterval(this.polling);
      this.polling = null;
    }
  }

  handleToggleAnnouncementsClick = (e) => {
    e.stopPropagation();
    this.props.dispatch(toggleShowAnnouncements());
  };

  render () {
    const { intl, hasUnread, columnId, multiColumn, hasAnnouncements, unreadAnnouncements, showAnnouncements, matchesBreakpoint } = this.props;
    const pinned = !!columnId;
    const { signedIn } = this.props.identity;
	const { activeFeed, personalized, interests } = this.state;
    const banners = [
      <CriticalUpdateBanner key='critical-update-banner' />,
      <AnnualReportTimeline key='annual-report' />
    ];

    let announcementsButton;

    if (hasAnnouncements) {
      announcementsButton = (
        <button
          type='button'
          className={classNames('column-header__button', { 'active': showAnnouncements })}
          title={intl.formatMessage(showAnnouncements ? messages.hide_announcements : messages.show_announcements)}
          aria-label={intl.formatMessage(showAnnouncements ? messages.hide_announcements : messages.show_announcements)}
          onClick={this.handleToggleAnnouncementsClick}
        >
          <IconWithBadge id='bullhorn' icon={CampaignIcon} count={unreadAnnouncements} />
        </button>
      );
    }

    return (
      <Column bindToDocument={!multiColumn} label={intl.formatMessage(messages.title)}>
        {isRedesignEnabled() ? (
          <ColumnHeader
			title={intl.formatMessage(activeFeed === 'recommended' ? messages.recommended : messages.following)}
            withUnreadMarker={hasUnread}
            extraButtons={
              <HomeColumnSettings>
                {multiColumn &&
                  <MultiColumnMenuItems
                    withDivider
                    onPin={this.handlePin}
                    onMove={this.handleMove}
                    pinned={pinned}
                  />
                }
              </HomeColumnSettings>
            }
          />
        ) : (
          <LegacyColumnHeader
            icon='home'
            iconComponent={matchesBreakpoint ? SymbolLogo : HomeIcon}
            active={hasUnread}
            title={intl.formatMessage(messages.title)}
            onPin={this.handlePin}
            onMove={this.handleMove}
            pinned={pinned}
            multiColumn={multiColumn}
            extraButton={announcementsButton}
            appendContent={hasAnnouncements && showAnnouncements && <Announcements />}
            scrollTopOnClick
          >
            <ColumnSettings />
          </LegacyColumnHeader>
        )}

        {signedIn ? (
		  <>
			<div className='rinspace-feed-tabs' role='tablist' aria-label={intl.formatMessage(messages.title)}>
			  <button type='button' role='tab' aria-selected={activeFeed === 'recommended'} disabled={!personalized} onClick={() => this.selectFeed('recommended')}>
				{intl.formatMessage(messages.recommended)}
			  </button>
			  <button type='button' role='tab' aria-selected={activeFeed === 'following'} onClick={() => this.selectFeed('following')}>
				{intl.formatMessage(messages.following)}
			  </button>
			  {personalized && <button type='button' className='rinspace-feed-tabs__privacy' onClick={this.disablePersonalization}>{intl.formatMessage(messages.disable_personalization)}</button>}
			</div>
			<details className='rinspace-recommendation-controls'>
			  <summary>{intl.formatMessage(messages.recommendation_settings)}</summary>
			  {interests.length > 0 ? (
				<ul>{interests.map(interest => <li key={interest}>#{interest} <button type='button' onClick={() => this.removeInterest(interest)}>×</button></li>)}</ul>
			  ) : <p>{intl.formatMessage(messages.recommendation_interests_empty)}</p>}
			  <button type='button' onClick={this.clearRecommendationProfile}>{intl.formatMessage(messages.clear_recommendation_profile)}</button>
			</details>
			{activeFeed === 'recommended' && <p className='rinspace-feed-explanation'>{intl.formatMessage(messages.recommendation_explanation)}</p>}
			<StatusListContainer
            prepend={banners}
            alwaysPrepend
            trackScroll={!pinned}
            scrollKey={`home_timeline-${columnId}`}
            onLoadMore={this.handleLoadMore}
			timelineId={activeFeed === 'recommended' ? 'recommended' : 'home'}
            emptyMessage={<FormattedMessage id='empty_column.home' defaultMessage='Your home timeline is empty! Follow more people to fill it up.' />}
            bindToDocument={!multiColumn}
			/>
		  </>
        ) : <NotSignedInIndicator />}

        <Helmet>
          <title>{intl.formatMessage(messages.title)}</title>
          <meta name='robots' content='noindex' />
        </Helmet>
      </Column>
    );
  }

}

export default connect(mapStateToProps)(withBreakpoint(withIdentity(injectIntl(HomeTimeline))));
