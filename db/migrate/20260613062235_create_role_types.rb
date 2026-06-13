class CreateRoleTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :role_types do |t|
      t.string :display_name, null: false
      t.string :permalink, null: false
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :role_types, :permalink, unique: true
  end
end
