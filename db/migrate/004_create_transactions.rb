class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions, id: :uuid do |t|
      t.uuid :restaurant_id, null: false
      t.uuid :employee_id, null: false
      t.string :transaction_id, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :payment_method, default: 0
      t.integer :status, default: 0
      t.datetime :transaction_time, null: false
      t.jsonb :items, default: []
      t.text :notes
      t.timestamps
    end

    add_index :transactions, :restaurant_id
    add_index :transactions, :employee_id
    add_index :transactions, :transaction_id
    add_index :transactions, :transaction_time
    add_index :transactions, :status
    add_index :transactions, :amount
    add_index :transactions, :items, using: :gin

    add_foreign_key :transactions, :restaurants, on_delete: :cascade
    add_foreign_key :transactions, :employees, on_delete: :cascade
  end
end
