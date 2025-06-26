require 'rails_helper'

RSpec.describe EchoLight, type: :model do
  describe 'アソシエーション' do
    it 'echoとの関連が正しく設定されている' do
      expect(EchoLight.new).to respond_to(:echo)
    end

    it 'light_definitionとの関連が正しく設定されている' do
      expect(EchoLight.new).to respond_to(:light_definition)
    end
  end

  describe 'バリデーション' do
    let(:user) { User.create!(email: 'test@test.com', name: 'Test User', password: 'password') }
    let(:echo) { Echo.create!(user: user, title: 'テスト', input_data: '{}', response_data: '{}') }
    let(:light_def) { LightDefinition.create!(key: 'test', name: 'テスト', r: 255, g: 0, b: 0, a: 255) }

    it 'amountが1以上であること' do
      echo_light = EchoLight.new(echo: echo, light_definition: light_def, amount: 0)
      expect(echo_light).not_to be_valid
      expect(echo_light.errors[:amount]).to include("must be greater than 0")
    end

    it 'echo_idとlight_definition_idの組み合わせが一意であること' do
      EchoLight.create!(echo: echo, light_definition: light_def, amount: 5)
      duplicate = EchoLight.new(echo: echo, light_definition: light_def, amount: 3)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:light_definition_id]).to include("has already been taken")
    end
  end
end