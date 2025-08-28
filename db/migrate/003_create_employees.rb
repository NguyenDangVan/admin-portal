class CreateEmployees < ActiveRecord::Migration[7.0]
  def change
    create_table :employees, id: :uuid do |t|
      t.uuid :restaurant_id, null: false
      t.string :employee_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.integer :position, default: 0
      t.decimal :hourly_rate, precision: 8, scale: 2
      t.date :hire_date
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :employees, :restaurant_id
    add_index :employees, :employee_id
    add_index :employees, :email
    add_index :employees, :position
    add_index :employees, :active

    add_foreign_key :employees, :restaurants, on_delete: :cascade
  end
end
