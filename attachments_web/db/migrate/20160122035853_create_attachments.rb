class CreateAttachments < ActiveRecord::Migration
  def change
    create_table :attachments do |t|
      t.string :attachmentid
      t.string :messageid
      t.integer :accountid
      t.string :identityid
      t.boolean :downloaded
      t.text :data

      t.timestamps null: false
    end
  end
end
