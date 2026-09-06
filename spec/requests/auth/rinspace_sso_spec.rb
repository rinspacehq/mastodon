# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace SSO preparation' do
  before do
    allow(Devise).to receive(:omniauth_providers).and_return([:openid_connect])
  end

  it 'stores an exact inner product URL and preserves POST into OmniAuth' do
    return_to = '/search?q=reverse%20engineering&world=inner#results'

    post '/auth/rinspace', params: { return_to: return_to }

    expect(response).to have_http_status(307)
    expect(response).to redirect_to('/auth/auth/openid_connect')
    expect(session['user_return_to']).to eq(return_to)
  end

  it 'accepts the stable status permalink without a world query' do
    post '/auth/rinspace', params: { return_to: '/p/123/example' }

    expect(response).to have_http_status(307)
    expect(session['user_return_to']).to eq('/p/123/example')
  end

  it 'accepts classified settings and relationship pages without losing inner identity' do
    ['/settings/preferences/appearance?world=inner', '/relationships?world=inner', '/terms-of-service?world=inner'].each do |return_to|
      post '/auth/rinspace', params: { return_to: return_to }

      expect(response).to have_http_status(307), return_to
      expect(session['user_return_to']).to eq(return_to)
    end
  end

  it 'recovers an expired outer session in the public shell with the exact target preserved' do
    post '/auth/rinspace', params: { return_to: '/search?q=reverse%20engineering&world=inner#results' }

    get '/auth/rinspace/recover'

    expect(response).to redirect_to('/?world=inner&rinspace_login=1&rinspace_return_to=%2Fsearch%3Fq%3Dreverse%2520engineering%26world%3Dinner%23results')
  end

  it 'recovers safely to the inner home when no return target exists' do
    get '/auth/rinspace/recover'

    expect(response).to redirect_to('/?world=inner&rinspace_login=1')
  end

  it 'preserves the current product route from non-topbar login entry points' do
    get '/auth/rinspace/recover', params: { return_to: '/explore?world=inner#links' }

    expect(response).to redirect_to('/?world=inner&rinspace_login=1&rinspace_return_to=%2Fexplore%3Fworld%3Dinner%23links')
  end

  it 'replaces the Mastodon password page with the inline inner-world login' do
    ClimateControl.modify RINSPACE_CLOUDBASE_ENV_ID: 'rin-test' do
      get '/?world=inner'
      expect(response.headers['Content-Security-Policy']).to include("form-action 'self'")

      get '/settings/preferences/appearance?world=inner'
      expect(response).to redirect_to('/auth/sign_in')

      get '/auth/sign_in'
      expect(response).to redirect_to('/auth/rinspace/recover')

      post '/auth/sign_in', params: { user: { email: 'legacy@example.com', password: 'unused' } }
      expect(response).to redirect_to('/auth/rinspace/recover')

      get '/auth/rinspace/recover'
      expect(response).to redirect_to('/?world=inner&rinspace_login=1&rinspace_return_to=%2Fsettings%2Fpreferences%2Fappearance%3Fworld%3Dinner')

      get response.location
      expect(response).to have_http_status(:ok)
    end
  end

  it 'replaces the Mastodon registration page with the same inline Rinspace login' do
    ClimateControl.modify RINSPACE_CLOUDBASE_ENV_ID: 'rin-test' do
      get '/auth/sign_up'
      expect(response).to redirect_to('/auth/rinspace/recover')

      post '/auth/sign_up', params: { user: { email: 'legacy@example.com', password: 'unused' } }
      expect(response).to redirect_to('/auth/rinspace/recover')

      get '/auth/rinspace/recover'
      expect(response).to redirect_to('/?world=inner&rinspace_login=1')
    end
  end

  it 'rejects external, protocol and unclassified targets' do
    [
      'https://example.com/explore?world=inner',
      '//example.com/explore?world=inner',
      '/auth/sign_in?world=inner',
      '/api/v1/accounts?world=inner',
      '/unknown-probe?world=inner',
      '/explore',
    ].each do |return_to|
      post '/auth/rinspace', params: { return_to: return_to }

      expect(response).to have_http_status(:bad_request), return_to
      expect(session['user_return_to']).to be_nil
    end
  end
end
