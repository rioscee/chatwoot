class CreateSalesPipelineTables < ActiveRecord::Migration[7.0]
  def change
    create_table :pipelines do |t|
      t.string :name, null: false
      t.bigint :account_id, null: false

      t.timestamps
    end

    add_index :pipelines, :account_id

    create_table :pipeline_stages do |t|
      t.string :name, null: false
      t.bigint :pipeline_id, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :pipeline_stages, :pipeline_id
    add_index :pipeline_stages, [:pipeline_id, :position]

    create_table :deals do |t|
      t.string :name, null: false
      t.decimal :value, precision: 15, scale: 2, default: 0.0, null: false
      t.string :currency, default: 'USD', null: false
      t.string :status, default: 'open', null: false # open, won, lost
      t.bigint :pipeline_stage_id, null: false
      t.bigint :account_id, null: false
      t.bigint :contact_id # optional, links to customer contact
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :deals, :account_id
    add_index :deals, :pipeline_stage_id
    add_index :deals, [:pipeline_stage_id, :position]
    add_index :deals, :contact_id
  end
end
