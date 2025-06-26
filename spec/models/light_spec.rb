require 'rails_helper'

RSpec.describe Light, type: :model do
  describe 'アソシエーション' do
    it 'userとの関連が正しく設定されている' do
      expect(Light.new).to respond_to(:user)
    end

    it 'light_definitionとの関連が正しく設定されている' do
      expect(Light.new).to respond_to(:light_definition)
    end
  end

  describe 'バリデーション' do
    let(:user) { User.create!(email: 'test@test.com', name: 'Test User', password: 'password') }
    let(:light_def) { LightDefinition.create!(key: 'test', name: 'テスト', r: 255, g: 0, b: 0, a: 255) }

    it 'amountが0以上であること' do
      light = Light.new(user: user, light_definition: light_def, amount: -1)
      expect(light).not_to be_valid
      expect(light.errors[:amount]).to include("must be greater than or equal to 0")
    end

    it 'user_idとlight_definition_idの組み合わせが一意であること' do
      Light.create!(user: user, light_definition: light_def, amount: 5)
      duplicate = Light.new(user: user, light_definition: light_def, amount: 3)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:light_definition_id]).to include("has already been taken")
    end
  end

  describe '作成とデフォルト値' do
    let(:user) { User.create!(email: 'test@test.com', name: 'Test User', password: 'password') }
    let(:light_def) { LightDefinition.create!(key: 'test', name: 'テスト', r: 255, g: 0, b: 0, a: 255) }

    it 'amountのデフォルト値が0であること' do
      light = Light.create!(user: user, light_definition: light_def)
      expect(light.amount).to eq(0)
    end
  end
end