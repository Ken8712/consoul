class CreateRooms < ActiveRecord::Migration[7.2]
  def change
    create_table :rooms do |t|
      t.string :title, null: false
      t.string :status, null: false, default: 'waiting'
      t.references :user1, null: false, foreign_key: { to_table: :users }
      t.references :user2, null: false, foreign_key: { to_table: :users }
      t.integer :timer_seconds, null: false, default: 0
      t.boolean :timer_running, null: false, default: false
      t.datetime :timer_started_at
      t.integer :heart_count, null: false, default: 0
      t.datetime :started_at

      # このカラムはルームの終了時間を記録します。このフラグによってルームが終了したかどうかを判断できます。もう一度開始することはできません。たとえcompletedステータスをwaitingに戻しても、ルームは再利用できません。
      # ended_atがわざわざある理由は、時間を記録するためだけではなく、ルームの状態を明確にするためです。
      t.datetime :ended_at
      t.datetime :last_activity_at

      t.timestamps
    end

    add_index :rooms, :status
    add_index :rooms, [ :user1_id, :user2_id ]
    add_index :rooms, :created_at
    add_index :rooms, :last_activity_at
  end
end
