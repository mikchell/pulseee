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

ActiveRecord::Schema[8.1].define(version: 2026_06_08_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "answer_group_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "group_name"
    t.string "submit_token", null: false
    t.datetime "updated_at", null: false
    t.index ["submit_token"], name: "index_answer_group_snapshots_on_submit_token", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_groups_on_name", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.string "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "score_answers", force: :cascade do |t|
    t.integer "score", null: false
    t.string "submit_token", null: false
    t.bigint "survey_question_id", null: false
    t.index ["submit_token", "survey_question_id"], name: "index_score_answers_on_submit_token_and_survey_question_id", unique: true
    t.index ["survey_question_id"], name: "index_score_answers_on_survey_question_id"
    t.check_constraint "score >= 1 AND score <= 5", name: "chk_score_answers_score"
  end

  create_table "survey_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "state", default: "pending", null: false
    t.datetime "submitted_at"
    t.bigint "survey_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["state"], name: "index_survey_assignments_on_state"
    t.index ["survey_id", "user_id"], name: "index_survey_assignments_on_survey_id_and_user_id", unique: true
    t.index ["survey_id"], name: "index_survey_assignments_on_survey_id"
    t.index ["user_id"], name: "index_survey_assignments_on_user_id"
    t.check_constraint "state::text = ANY (ARRAY['pending'::character varying, 'submitted'::character varying]::text[])", name: "chk_survey_assignments_state"
  end

  create_table "survey_questions", force: :cascade do |t|
    t.string "body", null: false
    t.datetime "created_at", null: false
    t.integer "order_index", null: false
    t.bigint "question_id", null: false
    t.bigint "survey_id", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_survey_questions_on_question_id"
    t.index ["survey_id", "order_index"], name: "index_survey_questions_on_survey_id_and_order_index", unique: true
    t.index ["survey_id", "question_id"], name: "index_survey_questions_on_survey_id_and_question_id", unique: true
    t.index ["survey_id"], name: "index_survey_questions_on_survey_id"
  end

  create_table "surveys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "end_at", null: false
    t.datetime "start_at", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_surveys_on_status"
    t.check_constraint "end_at > start_at", name: "chk_surveys_period"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying]::text[])", name: "chk_surveys_status"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "group_id"
    t.string "name", null: false
    t.boolean "survey_subject", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["group_id"], name: "index_users_on_group_id"
  end

  add_foreign_key "score_answers", "survey_questions"
  add_foreign_key "survey_assignments", "surveys"
  add_foreign_key "survey_assignments", "users"
  add_foreign_key "survey_questions", "questions"
  add_foreign_key "survey_questions", "surveys"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "users", "groups"
end
