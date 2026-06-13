class CreateCalculations < ActiveRecord::Migration[8.1]
  def change
    create_table :calculations do |t|
      t.references :user, null: true, foreign_key: true
      t.string :calculator, null: false
      t.jsonb  :inputs, null: false, default: {}
      t.jsonb  :result, null: false, default: {}
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :calculations, :calculator
    add_index :calculations, :deleted_at
  end
end
