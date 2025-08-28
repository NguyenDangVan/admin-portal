class CreateDiscounts < ActiveRecord::Migration[7.0]
  def change
    create_table :discounts, id: :uuid do |t|
      t.uuid :restaurant_id, null: false
      t.string :name, null: false
      t.text :description
      t.integer :discount_type, default: 0
      t.decimal :value, precision: 5, scale: 2, null: false
      t.boolean :is_percentage, default: true
      t.date :start_date
      t.date :end_date
      t.boolean :active, default: true
      t.jsonb :conditions, default: {}
      t.timestamps
    end

    add_index :discounts, :restaurant_id
    add_index :discounts, :name
    add_index :discounts, :discount_type
    add_index :discounts, :active
    add_index :discounts, :start_date
    add_index :discounts, :end_date
    add_index :discounts, :conditions, using: :gin

    add_foreign_key :discounts, :restaurants, on_delete: :cascade
  end
end
