# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_06_26_191703) do
  create_table "echo_lights", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "echo_id", null: false
    t.bigint "light_definition_id", null: false
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["echo_id", "light_definition_id"], name: "index_echo_lights_on_echo_id_and_light_definition_id", unique: true
    t.index ["echo_id"], name: "index_echo_lights_on_echo_id"
    t.index ["light_definition_id"], name: "index_echo_lights_on_light_definition_id"
  end

  create_table "echoes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", limit: 191, null: false
    t.string "pattern_name", limit: 191
    t.text "input_data", null: false
    t.text "response_data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_echoes_on_user_id"
  end

  create_table "light_definitions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", limit: 191, null: false
    t.string "name", limit: 191, null: false
    t.integer "r", null: false
    t.integer "g", null: false
    t.integer "b", null: false
    t.integer "a", default: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_light_definitions_on_key", unique: true
  end

  create_table "lights", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "light_definition_id", null: false
    t.integer "amount", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["light_definition_id"], name: "index_lights_on_light_definition_id"
    t.index ["user_id", "light_definition_id"], name: "index_lights_on_user_id_and_light_definition_id", unique: true
    t.index ["user_id"], name: "index_lights_on_user_id"
  end

  create_table "rooms", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title", limit: 191, null: false
    t.string "status", limit: 191, default: "waiting", null: false
    t.bigint "user1_id", null: false
    t.bigint "user2_id", null: false
    t.integer "timer_seconds", default: 0, null: false
    t.boolean "timer_running", default: false, null: false
    t.datetime "timer_started_at"
    t.integer "heart_count", default: 0, null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "last_activity_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "user1_emotion", limit: 191
    t.string "user2_emotion", limit: 191
    t.index ["created_at"], name: "index_rooms_on_created_at"
    t.index ["last_activity_at"], name: "index_rooms_on_last_activity_at"
    t.index ["status"], name: "index_rooms_on_status"
    t.index ["user1_emotion"], name: "index_rooms_on_user1_emotion"
    t.index ["user1_id", "user2_id"], name: "index_rooms_on_user1_id_and_user2_id"
    t.index ["user1_id"], name: "index_rooms_on_user1_id"
    t.index ["user2_emotion"], name: "index_rooms_on_user2_emotion"
    t.index ["user2_id"], name: "index_rooms_on_user2_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", limit: 191, default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token", limit: 191
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pair_user_id"
    t.string "name", limit: 191
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["pair_user_id"], name: "index_users_on_pair_user_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "echo_lights", "echoes"
  add_foreign_key "echo_lights", "light_definitions"
  add_foreign_key "echoes", "users"
  add_foreign_key "lights", "light_definitions"
  add_foreign_key "lights", "users"
  add_foreign_key "rooms", "users", column: "user1_id"
  add_foreign_key "rooms", "users", column: "user2_id"
  add_foreign_key "users", "users", column: "pair_user_id"
end
