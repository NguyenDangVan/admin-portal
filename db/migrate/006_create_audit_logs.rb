class CreateAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.uuid :restaurant_id
      t.uuid :user_id
      t.string :action, null: false
      t.string :auditable_type
      t.uuid :auditable_id
      t.jsonb :changes, default: {}
      t.jsonb :metadata, default: {}
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :audit_logs, :restaurant_id
    add_index :audit_logs, :user_id
    add_index :audit_logs, :action
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, :created_at
    add_index :audit_logs, :changes, using: :gin
    add_index :audit_logs, :metadata, using: :gin

    add_foreign_key :audit_logs, :restaurants, on_delete: :cascade
    add_foreign_key :audit_logs, :users, on_delete: :cascade
  end
end
