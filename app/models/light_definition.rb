class LightDefinition < ApplicationRecord
  has_many :lights, dependent: :destroy
  has_many :echo_lights, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :r, :g, :b, :a,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: 0,
                            less_than_or_equal_to: 255 }

  # CSS表示用ヘルパー
  def hex_rgba
    "#%02X%02X%02X%02X" % [r, g, b, a]
  end

  # 絵文字からLightDefinitionを取得
  EMOJI_MAPPING = {
    "😊" => "joy",
    "😢" => "sadness",
    "😠" => "hatred",
    "🤔" => "wonder"
  }.freeze

  def self.from_emoji(emoji)
    key = EMOJI_MAPPING[emoji]
    find_by(key: key) if key
  end
end