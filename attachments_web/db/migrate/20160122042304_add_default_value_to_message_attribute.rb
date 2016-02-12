class AddDefaultValueToMessageAttribute < ActiveRecord::Migration
def up
  change_column :messages, :downloaded, :boolean, :default => true
end

def down
  change_column :messages, :downloaded, :boolean, :default => nil
end
end
