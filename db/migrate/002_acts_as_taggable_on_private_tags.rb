class ActsAsTaggableOnPrivateTags < ActiveRecord::Migration
  def self.up
    change_table :tags do |t|
      t.boolean :private, :null => false, :default => false
    end
    
    add_index :tags, :private
  end
  
  def self.down
    remove_column :tags, :private
  end
end