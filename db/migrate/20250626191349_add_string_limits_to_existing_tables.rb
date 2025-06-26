class AddStringLimitsToExistingTables < ActiveRecord::Migration[7.2]
  def change
    # roomsテーブルのstring型カラムにlimit追加
    change_column :rooms, :title, :string, limit: 191, null: false
    change_column :rooms, :status, :string, limit: 191, default: "waiting", null: false
    change_column :rooms, :user1_emotion, :string, limit: 191
    change_column :rooms, :user2_emotion, :string, limit: 191
    
    # usersテーブルのstring型カラムにlimit追加
    change_column :users, :email, :string, limit: 191, default: "", null: false
    change_column :users, :name, :string, limit: 191
    change_column :users, :reset_password_token, :string, limit: 191
  end
end
