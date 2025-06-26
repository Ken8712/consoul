class CreateLights < ActiveRecord::Migration[7.2]
  def change
    create_table :lights do |t|
      t.references :user,             null: false, foreign_key: true
      t.references :light_definition, null: false, foreign_key: true
      t.integer    :amount,           null: false, default: 0
      t.timestamps
    end
    add_index :lights, [:user_id, :light_definition_id], unique: true
  end
end
