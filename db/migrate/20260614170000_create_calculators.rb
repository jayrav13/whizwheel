class CreateCalculators < ActiveRecord::Migration[8.1]
  def change
    create_table :calculators do |t|
      t.string  :slug,        null: false
      t.string  :name,        null: false
      t.string  :category
      t.integer :complexity
      t.string  :tags
      t.text    :description
      t.string  :source
      t.datetime :deprecated_at
      t.timestamps
    end
    add_index :calculators, :slug, unique: true
    add_index :calculators, :category
    add_index :calculators, :deprecated_at
  end
end
