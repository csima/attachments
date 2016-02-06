class AddDefaultValueToAttachmentAttribute < ActiveRecord::Migration
def up
  change_column :attachments, :downloaded, :boolean, :default => true
end

def down
  change_column :attachments, :downloaded, :boolean, :default => nil
end
end
