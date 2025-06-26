class CreateEchoes < ActiveRecord::Migration[7.2]
  def change
    create_table :echoes do |t|
      t.references :user,        null: false, foreign_key: true
      t.string     :title,       null: false, limit: 191
      t.string     :pattern_name, limit: 191
      t.text       :input_data,    null: false
      t.text       :response_data, null: false
      t.timestamps
    end
  end
end
