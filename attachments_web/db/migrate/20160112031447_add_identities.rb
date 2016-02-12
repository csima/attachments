class AddIdentities < ActiveRecord::Migration
  def change
    create_table :identities do |t|
      t.string :name
      t.string :refresh_token
      t.string :access_token
      t.timestamp :expires
      t.string :uid
      t.string :provider
      t.references :user
    end

    add_index :identities, :user_id
  end
end
