# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160122043442) do

  create_table "attachments", force: :cascade do |t|
    t.string   "attachmentid"
    t.string   "messageid"
    t.integer  "accountid"
    t.string   "identityid"
    t.boolean  "downloaded",   default: true
    t.text     "data"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "identities", force: :cascade do |t|
    t.string   "name"
    t.string   "refresh_token"
    t.string   "access_token"
    t.datetime "expires"
    t.string   "uid"
    t.string   "provider"
    t.integer  "user_id"
    t.string   "email"
  end

  add_index "identities", ["user_id"], name: "index_identities_on_user_id"

  create_table "messages", force: :cascade do |t|
    t.string   "messageid"
    t.integer  "accountid"
    t.string   "identityid"
    t.boolean  "downloaded", default: true
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.text     "data"
  end

  create_table "sessions", force: :cascade do |t|
    t.string   "session_id", null: false
    t.text     "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], name: "index_sessions_on_session_id", unique: true
  add_index "sessions", ["updated_at"], name: "index_sessions_on_updated_at"

  create_table "users", force: :cascade do |t|
    t.string   "provider"
    t.string   "uid"
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "email"
  end

end
