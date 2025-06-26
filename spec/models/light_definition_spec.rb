require 'rails_helper'

RSpec.describe LightDefinition, type: :model do
  describe 'アソシエーション' do
    it 'lightsとの関連が正しく設定されている' do
      expect(LightDefinition.new).to respond_to(:lights)
    end

    it 'echo_lightsとの関連が正しく設定されている' do
      expect(LightDefinition.new).to respond_to(:echo_lights)
    end
  end

  describe 'バリデーション' do
    it 'keyが必須であること' do
      light_def = LightDefinition.new(name: 'テスト', r: 255, g: 0, b: 0, a: 255)
      expect(light_def).not_to be_valid
      expect(light_def.errors[:key]).to include("can't be blank")
    end

    it 'keyが一意であること' do
      LightDefinition.create!(key: 'unique', name: 'テスト', r: 255, g: 0, b: 0, a: 255)
      duplicate = LightDefinition.new(key: 'unique', name: 'テスト2', r: 0, g: 255, b: 0, a: 255)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include("has already been taken")
    end

    it 'nameが必須であること' do
      light_def = LightDefinition.new(key: 'test', r: 255, g: 0, b: 0, a: 255)
      expect(light_def).not_to be_valid
      expect(light_def.errors[:name]).to include("can't be blank")
    end

    it 'r,g,b,aが0-255の範囲であること' do
      # 範囲外の値でテスト
      light_def = LightDefinition.new(key: 'test', name: 'テスト', r: -1, g: 256, b: 128, a: 128)
      expect(light_def).not_to be_valid
      expect(light_def.errors[:r]).to include("must be greater than or equal to 0")
      expect(light_def.errors[:g]).to include("must be less than or equal to 255")
    end
  end

  describe 'インスタンスメソッド' do
    let(:light_def) { LightDefinition.create!(key: 'test', name: 'テスト', r: 255, g: 128, b: 64, a: 200) }

    describe '#hex_rgba' do
      it '正しいRGBA16進数文字列を返すこと' do
        expect(light_def.hex_rgba).to eq("#FF8040C8")
      end
    end
  end

  describe 'クラスメソッド' do
    before do
      LightDefinition.create!(key: 'joy', name: '喜び', r: 255, g: 223, b: 80, a: 230)
      LightDefinition.create!(key: 'sadness', name: '悲しみ', r: 0, g: 0, b: 255, a: 153)
    end

    describe '.from_emoji' do
      it '😊に対応するjoyを返すこと' do
        result = LightDefinition.from_emoji('😊')
        expect(result.key).to eq('joy')
      end

      it '😢に対応するsadnessを返すこと' do
        result = LightDefinition.from_emoji('😢')
        expect(result.key).to eq('sadness')
      end

      it '😠に対応するhatredを返すこと（データが存在しない場合nilを返す）' do
        result = LightDefinition.from_emoji('😠')
        expect(result).to be_nil
      end

      it '対応しない絵文字に対してnilを返すこと' do
        result = LightDefinition.from_emoji('😴')
        expect(result).to be_nil
      end
    end
  end
end