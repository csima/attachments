class RemoveExpiresFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :expires, :datetime
  end
end
