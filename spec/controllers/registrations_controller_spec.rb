require 'spec_helper'

describe RegistrationsController do
  # needed for devise shit
  before :each do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe 'POST#create' do
    let!(:user_attributes) do
      {
        email: 'i@mclov.in',
        full_name: 'Mclovin',
        password: 'password',
        timezone: 'Pacific Time (US & Canada)'
      }
    end

    before do
      allow(TrackMixpanelEventJob).to receive(:perform_async)
      allow(IdentifyMixpanelUserJob).to receive(:perform_async)
    end

    def do_request
      post :create, user: user_attributes
    end

    it 'creates a new user' do
      expect { do_request }.to change(User, :count).by(1)

      user = User.last
      expect(user.full_name).to eql 'Mclovin'
      expect(user.email).to eql 'i@mclov.in'
      expect(user.timezone).to eql 'Pacific Time (US & Canada)'
      expect(user.timezone_utc_offset).to eql -28800
      expect(user.api_key).to_not be_blank
    end

    it 'should create a new bot' do
      expect { do_request }.to change(Bot, :count).by(1)
      bot = Bot.last
      user = User.last

      expect(bot.owners).to match_array [user]
      expect(bot.name).to eql 'My First Bot'
      expect(bot.provider).to eql 'slack'
    end

    it 'should redirect to the bot_path' do
      do_request
      bot = Bot.last
      expect(response).to redirect_to bot_path(bot)
    end

    it 'should identify the user on Mixpanel' do
      do_request
      expect(IdentifyMixpanelUserJob).to have_received(:perform_async).with(User.last.id, {})
    end

    it 'should track the "User Signed Up" event on Mixpanel' do
      do_request
      expect(TrackMixpanelEventJob).to have_received(:perform_async).with('User Signed Up', User.last.id, {})
    end
  end
end
