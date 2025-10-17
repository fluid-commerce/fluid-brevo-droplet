class CreateActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :job_type
      t.string :status
      t.text :message
      t.jsonb :details

      t.timestamps
    end
  end
end
