class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role_type, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
