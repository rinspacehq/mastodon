# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController do
  controller do
    def success
      response.headers['X-Protected-Action'] = 'executed'
      head :ok
    end
  end

  let(:user) { Fabricate(:user) }
  let(:parent_client) { instance_double(Rinspace::ParentSessionClient, assert_active!: true) }
  let(:activation) do
    instance_double(
      SessionActivation,
      updated_at: Time.current,
      rinspace_managed?: true,
      rinspace_parent_issuer: 'https://example.com/rinspace/auth',
      rinspace_parent_uid: 'recovery-spec',
      rinspace_parent_sid: '00000000-0000-4000-8000-000000000001',
      rinspace_parent_version: 1
    )
  end

  before do
    routes.draw do
      get 'success' => 'anonymous#success'
      post 'success' => 'anonymous#success'
    end
    sign_in(user)
    session[:recovery_marker] = 'local-only'
    cookies['__Host-rin_access'] = 'main-site-cookie-marker'
    cookies['remember_user_token'] = 'expired-local-remember-cookie'
    allow(controller).to receive(:current_session).and_return(activation)
    allow(Rinspace::ParentSessionClient).to receive(:new).and_return(parent_client)
  end

  context 'when the parent is inactive' do
    before do
      allow(parent_client).to receive(:assert_active!).and_raise(Rinspace::ParentSessionClient::InactiveError)
    end

    it 'clears only local login state without invoking central logout callbacks' do
      expect(warden).not_to receive(:logout)
      expect(parent_client).not_to receive(:revoke_parent!)

      get :success, params: { world: 'inner' }

      expect(response).to have_http_status(:see_other)
      expect(response.location).to end_with('/auth/rinspace/recover?return_to=%2Fsuccess%3Fworld%3Dinner')
      expect(response.headers['X-Protected-Action']).to be_nil
      expect(response.cache_control).to include(private: true, no_store: true)
      expect(cookies['_session_id']).to be_nil
      expect(cookies['remember_user_token']).to be_nil
      expect(cookies['__Host-rin_access']).to eq('main-site-cookie-marker')
      expect(session[:recovery_marker]).to be_nil
      expect(warden.user(:user)).to be_nil
      expect(controller.current_account).to be_nil
    end

    it 'preserves another device activation and its API token' do
      other_activation = Fabricate(:session_activation, user: user)
      other_token_id = other_activation.access_token_id

      expect { get :success }.not_to change(SessionActivation, :count)

      expect(other_activation.reload.access_token_id).to eq(other_token_id)
      expect(other_activation.access_token.reload).not_to be_revoked
    end

    it 'allows the next request to reach the anonymous flow instead of looping on 401' do
      get :success
      get :success

      expect(response).to have_http_status(:ok)
      expect(response.headers['X-Protected-Action']).to eq('executed')
    end

    it 'keeps JSON responses as 401 without an HTML login redirect' do
      get :success, format: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'Parent session is inactive')
      expect(response.headers['Location']).to be_nil
      expect(response.headers['X-Protected-Action']).to be_nil
      expect(warden).to be_custom_failure
    end

    it 'does not redirect XHR requests' do
      request.headers['X-Requested-With'] = 'XMLHttpRequest'
      get :success

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Location']).to be_nil
      expect(response.headers['X-Protected-Action']).to be_nil
    end

    it 'never replays or redirects an unsafe request' do
      post :success

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['Location']).to be_nil
      expect(response.headers['X-Protected-Action']).to be_nil
    end
  end

  it 'recovers a missing local activation rather than retaining its cookie' do
    allow(controller).to receive(:current_session).and_return(nil)
    expect(parent_client).not_to receive(:assert_active!)

    get :success

    expect(response).to have_http_status(:see_other)
    expect(cookies['_session_id']).to be_nil
  end

  it 'preserves credentials when Identity is unavailable' do
    local_session_id = warden.cookies.signed['_session_id']
    allow(parent_client).to receive(:assert_active!).and_raise(Rinspace::ParentSessionClient::UnavailableError)

    get :success

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers['Retry-After']).to eq('3')
    expect(response.cache_control).to include(private: true, no_store: true)
    expect(warden.cookies.signed['_session_id']).to eq(local_session_id)
    expect(cookies['remember_user_token']).to eq('expired-local-remember-cookie')
    expect(session[:recovery_marker]).to eq('local-only')
    expect(warden.user(:user)).to eq(user)
    expect(response.headers['X-Protected-Action']).to be_nil
  end

  it 'does not disturb an active parent' do
    get :success

    expect(response).to have_http_status(:ok)
    expect(warden.user(:user)).to eq(user)
    expect(session[:recovery_marker]).to eq('local-only')
  end

  it 'does not apply the cookie recovery path to bearer requests' do
    request.headers['Authorization'] = 'Bearer synthetic-spec-only'
    expect(parent_client).not_to receive(:assert_active!)

    get :success

    expect(response).to have_http_status(:ok)
    expect(session[:recovery_marker]).to eq('local-only')
  end

  it 'does not change legacy local session behavior' do
    allow(activation).to receive(:rinspace_managed?).and_return(false)
    expect(parent_client).not_to receive(:assert_active!)

    get :success

    expect(response).to have_http_status(:ok)
    expect(warden.user(:user)).to eq(user)
  end
end
