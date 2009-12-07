class CreateSettings < ActiveRecord::Migration

  def self.up

    create_table :settings do |t|
      t.string :key, :null => false, :limit => 128
      t.text :value
      t.timestamps
    end

    add_index :settings, :key, :unique => true

  end

  def self.down
    drop_table :settings
  end

end

