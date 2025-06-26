# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# 開発・テスト用のユーザーペア作成
if Rails.env.development? || Rails.env.test? || Rails.env.production?
  # m@m.com ユーザー
  user_m = User.find_or_create_by!(email: 'm@m.com') do |user|
    user.name = 'M'
    user.password = 'aaaaa1'
    user.password_confirmation = 'aaaaa1'
  end

  # w@w.com ユーザー
  user_w = User.find_or_create_by!(email: 'w@w.com') do |user|
    user.name = 'W'
    user.password = 'aaaaa1'
    user.password_confirmation = 'aaaaa1'
  end

  # ペア関係を作成（双方向）
  unless user_m.paired?
    user_m.create_mutual_pair_with(user_w)
    puts "テスト用ペア作成完了: #{user_m.email} ⇔ #{user_w.email}"
  else
    puts "テスト用ペアは既に存在します"
  end
end

# Light定義の初期データ作成
light_definitions_data = [
  { key: 'philia',  name: '愛',     r: 255, g: 48,  b: 255, a: 205 },
  { key: 'hatred',  name: '憎しみ', r: 255, g: 0,   b: 0,   a: 255 },
  { key: 'joy',     name: '喜び',   r: 255, g: 223, b: 80,  a: 230 },
  { key: 'sadness', name: '悲しみ', r: 0,   g: 0,   b: 255, a: 153 },
  { key: 'wonder',  name: '驚き',   r: 80,  g: 255, b: 255, a: 255 },
  { key: 'motive',  name: '欲望',   r: 0,   g: 255, b: 0,   a: 255 }
]

light_definitions_data.each do |data|
  light_def = LightDefinition.find_or_create_by!(key: data[:key]) do |ld|
    ld.name = data[:name]
    ld.r = data[:r]
    ld.g = data[:g]
    ld.b = data[:b]
    ld.a = data[:a]
  end
  puts "Light定義作成/確認: #{light_def.key} (#{light_def.name})"
end

puts "シードデータの作成が完了しました"