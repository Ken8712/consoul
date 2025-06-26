class CreateEchoLights < ActiveRecord::Migration[7.2]
  def change
    create_table :echo_lights do |t|
      t.references :echo,             null: false, foreign_key: { to_table: :echoes }
      t.references :light_definition, null: false, foreign_key: true
      t.integer    :amount,           null: false
      t.timestamps
    end
    add_index :echo_lights, [:echo_id, :light_definition_id], unique: true
  end
end
