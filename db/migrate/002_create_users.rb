class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :users, id: :uuid do |t|
      t.string :supabase_uid, null: false
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.integer :role, default: 0
      t.uuid :restaurant_id
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :users, :supabase_uid, unique: true
    add_index :users, :email
    add_index :users, :restaurant_id
    add_index :users, :role

    add_foreign_key :users, :restaurants, on_delete: :cascade
  end
end
