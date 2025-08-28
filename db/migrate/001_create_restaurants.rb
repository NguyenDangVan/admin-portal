class CreateRestaurants < ActiveRecord::Migration[7.0]
  def change
    create_table :restaurants, id: :uuid do |t|
      t.string :name, null: false
      t.text :address
      t.string :phone
      t.string :email
      t.integer :status, default: 0
      t.jsonb :settings, default: {}
      t.timestamps
    end

    add_index :restaurants, :name
    add_index :restaurants, :status
    add_index :restaurants, :settings, using: :gin
  end
end
