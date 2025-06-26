class CreateLightDefinitions < ActiveRecord::Migration[7.2]
  def change
    create_table :light_definitions do |t|
      t.string  :key,  null: false, limit: 191
      t.string  :name, null: false, limit: 191
      t.integer :r,    null: false
      t.integer :g,    null: false
      t.integer :b,    null: false
      t.integer :a,    null: false, default: 255
      t.timestamps
    end
    add_index :light_definitions, :key, unique: true
  end
end
