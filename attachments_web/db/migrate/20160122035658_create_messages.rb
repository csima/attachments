class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string :messageid
      t.integer :accountid
      t.string :identityid
      t.boolean :downloaded

      t.timestamps null: false
    end
  end
end
