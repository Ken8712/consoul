require 'rails_helper'

RSpec.describe Echo, type: :model do
  describe 'アソシエーション' do
    it 'userとの関連が正しく設定されている' do
      expect(Echo.new).to respond_to(:user)
    end

    it 'echo_lightsとの関連が正しく設定されている' do
      expect(Echo.new).to respond_to(:echo_lights)
    end

    it 'light_definitionsとの関連が正しく設定されている' do
      expect(Echo.new).to respond_to(:light_definitions)
    end
  end

  describe 'バリデーション' do
    it 'titleが必須であること' do
      user = User.create!(email: 'test@test.com', name: 'Test User', password: 'password')
      echo = Echo.new(user: user, input_data: '{}', response_data: '{}')
      expect(echo).not_to be_valid
      expect(echo.errors[:title]).to include("can't be blank")
    end
  end

  describe '作成' do
    let(:user) { User.create!(email: 'test@test.com', name: 'Test User', password: 'password') }

    it '有効なデータでechoを作成できること' do
      echo = Echo.new(
        user: user,
        title: 'テストエコー',
        pattern_name: 'test_pattern',
        input_data: '{"test": "data"}',
        response_data: '{"response": "data"}'
      )
      expect(echo).to be_valid
    end
  end
end