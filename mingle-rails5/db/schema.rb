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

ActiveRecord::Schema.define(version: 20180906054024) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "asynch_requests", force: :cascade do |t|
    t.integer "user_id",                                         null: false
    t.string  "status",                 limit: 255
    t.string  "progress_message",       limit: 4000
    t.integer "error_count",                         default: 0, null: false
    t.integer "warning_count",                       default: 0
    t.integer "total",                               default: 1, null: false
    t.integer "completed",                           default: 0, null: false
    t.string  "type",                   limit: 255
    t.text    "message"
    t.string  "deliverable_identifier", limit: 255,              null: false
    t.string  "tmp_file",               limit: 255
    t.index ["user_id", "deliverable_identifier"], name: "idx_async_req_on_user_proj", using: :btree
    t.index ["user_id"], name: "idx_async_req_on_user_id", using: :btree
  end

  create_table "attachings", force: :cascade do |t|
    t.integer "attachment_id"
    t.integer "attachable_id"
    t.string  "attachable_type", limit: 255
    t.index ["attachable_id", "attachable_type"], name: "idx_attaching_on_id_and_type", using: :btree
    t.index ["attachable_id"], name: "index_att_on_able_id", using: :btree
    t.index ["attachable_type"], name: "index_att_on_able_type", using: :btree
    t.index ["attachment_id"], name: "index_att_on_a_id", using: :btree
  end

  create_table "attachments", force: :cascade do |t|
    t.string  "file",       limit: 255, default: "", null: false
    t.string  "path",       limit: 255, default: "", null: false
    t.integer "project_id",                          null: false
    t.index ["project_id"], name: "idx_atchmnt_on_proj_id", using: :btree
  end

  create_table "backlog_objectives", force: :cascade do |t|
    t.string  "name",            limit: 80
    t.integer "backlog_id"
    t.integer "position"
    t.integer "size",                       default: 0
    t.integer "value",                      default: 0
    t.text    "value_statement"
    t.integer "number"
    t.integer "program_id"
    t.index ["number", "backlog_id"], name: "backlog_number_unique", unique: true, using: :btree
  end

  create_table "backlogs", force: :cascade do |t|
    t.integer "program_id"
  end

  create_table "cache_keys", id: :integer, default: -> { "nextval('project_structure_keys_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer  "deliverable_id"
    t.string   "structure_key",    limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "card_key",         limit: 255
    t.string   "feed_key",         limit: 255
    t.string   "deliverable_type", limit: 255, default: "Project", null: false
  end

  create_table "card_defaults", force: :cascade do |t|
    t.integer "card_type_id", null: false
    t.integer "project_id",   null: false
    t.text    "description"
    t.boolean "redcloth"
    t.index ["card_type_id", "project_id"], name: "idx_card_def_on_ct_and_proj_id", using: :btree
  end

  create_table "card_list_views", force: :cascade do |t|
    t.integer  "project_id",                                null: false
    t.string   "name",             limit: 255, default: "", null: false
    t.text     "params"
    t.text     "canonical_string"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["project_id"], name: "index_card_list_views_on_project_id", using: :btree
  end

  create_table "card_murmur_links", force: :cascade do |t|
    t.integer "card_id"
    t.integer "project_id"
    t.integer "murmur_id"
    t.index ["card_id", "murmur_id"], name: "idx_cml_on_card_and_mur_id", using: :btree
  end

  create_table "card_revision_links", force: :cascade do |t|
    t.integer "project_id",  null: false
    t.integer "card_id",     null: false
    t.integer "revision_id", null: false
    t.index ["card_id", "revision_id"], name: "idx_crl_on_card_and_rev_id", using: :btree
  end

  create_table "card_types", force: :cascade do |t|
    t.integer "project_id"
    t.string  "name",       limit: 255, null: false
    t.string  "color",      limit: 255
    t.integer "position"
    t.index ["project_id"], name: "idx_card_types_on_proj_id", using: :btree
  end

  create_table "card_versions", force: :cascade do |t|
    t.integer  "card_id"
    t.integer  "version"
    t.integer  "project_id"
    t.integer  "number"
    t.string   "name",                     limit: 255, default: ""
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "created_by_user_id",                   default: 0,     null: false
    t.integer  "modified_by_user_id",                  default: 0,     null: false
    t.text     "comment"
    t.string   "card_type_name",           limit: 255,                 null: false
    t.boolean  "has_macros",                           default: false
    t.text     "system_generated_comment"
    t.string   "updater_id",               limit: 255
    t.boolean  "redcloth"
  end

  create_table "cards", force: :cascade do |t|
    t.integer  "project_id",                                      null: false
    t.integer  "number",                                          null: false
    t.text     "description"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "version"
    t.string   "card_type_name",      limit: 255,                 null: false
    t.boolean  "has_macros",                      default: false
    t.decimal  "project_card_rank"
    t.integer  "caching_stamp",                   default: 0,     null: false
    t.string   "name",                limit: 255,                 null: false
    t.integer  "created_by_user_id",                              null: false
    t.integer  "modified_by_user_id",                             null: false
    t.boolean  "redcloth"
    t.index ["number"], name: "index_cards_on_number", using: :btree
    t.index ["project_id"], name: "index_cards_on_project_id", using: :btree
  end

  create_table "changes", force: :cascade do |t|
    t.integer "event_id",                               null: false
    t.string  "type",          limit: 255, default: "", null: false
    t.string  "old_value",     limit: 255
    t.string  "new_value",     limit: 255
    t.integer "attachment_id"
    t.integer "tag_id"
    t.string  "field",         limit: 255, default: "", null: false
    t.index ["event_id", "type"], name: "index_event_changes", using: :btree
  end

  create_table "checklist_items", force: :cascade do |t|
    t.string   "text",       limit: 255
    t.boolean  "completed"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "card_id"
    t.integer  "project_id"
    t.integer  "position"
    t.string   "type",       limit: 255, default: ""
    t.index ["card_id"], name: "index_checklist_items_on_card_id", using: :btree
    t.index ["project_id"], name: "index_checklist_items_on_project_id", using: :btree
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at"
    t.integer  "project_id"
    t.index ["project_id"], name: "index_conversations_on_project_id", using: :btree
  end

  create_table "correction_changes", force: :cascade do |t|
    t.integer "event_id"
    t.string  "old_value",   limit: 255
    t.string  "new_value",   limit: 255
    t.string  "change_type", limit: 255, null: false
    t.integer "resource_1"
    t.integer "resource_2"
  end

  create_table "deliverables", id: :integer, default: -> { "nextval('projects_id_seq'::regclass)" }, force: :cascade do |t|
    t.string   "name",                    limit: 255, default: "",         null: false
    t.string   "identifier",              limit: 255, default: "",         null: false
    t.text     "description"
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.string   "icon",                    limit: 255
    t.integer  "created_by_user_id"
    t.integer  "modified_by_user_id"
    t.string   "card_keywords",           limit: 255
    t.boolean  "template"
    t.string   "secret_key",              limit: 255
    t.string   "email_address",           limit: 255
    t.string   "email_sender_name",       limit: 255
    t.boolean  "hidden",                              default: false
    t.string   "date_format",             limit: 255, default: "%d %b %Y"
    t.string   "time_zone",               limit: 255
    t.integer  "precision",                           default: 2
    t.boolean  "anonymous_accessible",                default: false
    t.boolean  "corruption_checked"
    t.text     "corruption_info"
    t.string   "auto_enroll_user_type",   limit: 255
    t.string   "cards_table",             limit: 255
    t.string   "card_versions_table",     limit: 255
    t.boolean  "membership_requestable"
    t.string   "type",                    limit: 255
    t.boolean  "pre_defined_template"
    t.integer  "landing_tab_id"
    t.text     "ordered_tab_identifiers"
    t.boolean  "exclude_weekends_in_cta",             default: false,      null: false
    t.boolean  "accepts_dependencies",                default: false
    t.date     "last_export_date"
    t.index ["identifier", "type"], name: "index_projects_on_identifier_and_type", using: :btree
    t.index ["name", "type"], name: "index_projects_on_name_and_type", unique: true, using: :btree
  end

  create_table "dependencies", force: :cascade do |t|
    t.string   "name",                 limit: 255,                 null: false
    t.text     "description"
    t.date     "desired_end_date",                                 null: false
    t.integer  "resolving_project_id"
    t.integer  "raising_project_id",                               null: false
    t.integer  "number"
    t.datetime "created_at"
    t.integer  "raising_user_id"
    t.string   "status",               limit: 255, default: "NEW", null: false
    t.integer  "version"
    t.integer  "raising_card_number"
    t.datetime "updated_at"
  end

  create_table "dependency_resolving_cards", force: :cascade do |t|
    t.integer "dependency_id",               null: false
    t.string  "dependency_type", limit: 255
    t.integer "card_number"
    t.integer "project_id",                  null: false
  end

  create_table "dependency_versions", force: :cascade do |t|
    t.integer  "dependency_id",                    null: false
    t.integer  "version",                          null: false
    t.string   "name",                 limit: 255, null: false
    t.text     "description"
    t.date     "desired_end_date",                 null: false
    t.integer  "resolving_project_id"
    t.integer  "raising_project_id",               null: false
    t.integer  "number",                           null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "raising_user_id"
    t.string   "status",               limit: 255, null: false
    t.integer  "raising_card_number"
    t.index ["dependency_id"], name: "index_dependency_versions_on_dependency_id", using: :btree
  end

  create_table "dependency_views", force: :cascade do |t|
    t.integer  "project_id",              null: false
    t.integer  "user_id",                 null: false
    t.string   "params",     limit: 4096
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["project_id", "user_id"], name: "index_dependency_views_on_project_id_and_user_id", unique: true, using: :btree
    t.index ["project_id"], name: "index_dependency_views_on_project_id", using: :btree
  end

  create_table "enumeration_values", force: :cascade do |t|
    t.string  "value",                  limit: 255, default: "", null: false
    t.integer "property_definition_id"
    t.string  "color",                  limit: 255
    t.integer "position"
    t.index ["position"], name: "index_enumeration_values_on_position", using: :btree
    t.index ["property_definition_id"], name: "index_enumeration_values_on_property_definition_id", using: :btree
    t.index ["value", "property_definition_id"], name: "unique_enumeration_values", unique: true, using: :btree
    t.index ["value"], name: "index_enumeration_values_on_value", using: :btree
  end

  create_table "events", force: :cascade do |t|
    t.string   "type",               limit: 255,                                                              null: false
    t.string   "origin_type",        limit: 255,                                                              null: false
    t.integer  "origin_id",                                                                                   null: false
    t.datetime "created_at",                                                                                  null: false
    t.integer  "created_by_user_id"
    t.integer  "deliverable_id",                                                                              null: false
    t.boolean  "history_generated",               default: false
    t.datetime "mingle_timestamp",                default: -> { "timezone('utc'::text, clock_timestamp())" }
    t.string   "deliverable_type",   limit: 255,  default: "Project",                                         null: false
    t.string   "details",            limit: 4096
    t.index ["created_by_user_id"], name: "index_events_on_created_by_user_id", using: :btree
    t.index ["deliverable_id"], name: "idx_events_on_proj_id", using: :btree
    t.index ["origin_type", "origin_id"], name: "index_events_on_origin_type_and_origin_id", using: :btree
  end

  create_table "exports", force: :cascade do |t|
    t.string   "status",      limit: 255
    t.integer  "user_id"
    t.integer  "total"
    t.integer  "completed"
    t.string   "export_file", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "config"
  end

  create_table "favorites", force: :cascade do |t|
    t.integer  "project_id",                                 null: false
    t.string   "favorited_type", limit: 255,                 null: false
    t.integer  "favorited_id",                               null: false
    t.boolean  "tab_view",                   default: false, null: false
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["project_id", "favorited_type", "favorited_id"], name: "idx_fav_on_type_and_id", using: :btree
  end

  create_table "git_configurations", force: :cascade do |t|
    t.integer "project_id"
    t.string  "repository_path",             limit: 255
    t.string  "username",                    limit: 255
    t.string  "password",                    limit: 255
    t.boolean "initialized"
    t.boolean "card_revision_links_invalid"
    t.boolean "marked_for_deletion",                     default: false
  end

  create_table "githubs", force: :cascade do |t|
    t.string   "username",   limit: 255
    t.string   "repository", limit: 255
    t.integer  "project_id"
    t.integer  "webhook_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "groups", force: :cascade do |t|
    t.string  "name",           limit: 255
    t.integer "deliverable_id"
    t.boolean "internal",                   default: false, null: false
  end

  create_table "hg_configurations", force: :cascade do |t|
    t.integer "project_id"
    t.string  "repository_path",             limit: 255
    t.string  "username",                    limit: 255
    t.string  "password",                    limit: 255
    t.boolean "initialized"
    t.boolean "card_revision_links_invalid"
    t.boolean "marked_for_deletion",                     default: false
  end

  create_table "history_subscriptions", force: :cascade do |t|
    t.integer "user_id",                              null: false
    t.integer "project_id",                           null: false
    t.text    "filter_params"
    t.integer "last_max_card_version_id",             null: false
    t.integer "last_max_page_version_id",             null: false
    t.integer "last_max_revision_id",                 null: false
    t.string  "hashed_filter_params",     limit: 255
    t.string  "error_message",            limit: 255
    t.index ["project_id", "user_id"], name: "idx_hist_sub_on_proj_user", using: :btree
  end

  create_table "licenses", force: :cascade do |t|
    t.boolean "eula_accepted"
    t.text    "license_key"
  end

  create_table "login_access", force: :cascade do |t|
    t.integer  "user_id",                                null: false
    t.string   "login_token",               limit: 255
    t.datetime "last_login_at"
    t.string   "lost_password_key",         limit: 4096
    t.datetime "lost_password_reported_at"
    t.datetime "first_login_at"
  end

  create_table "luau_configs", force: :cascade do |t|
    t.string   "base_url",                  limit: 255
    t.datetime "submitted_at"
    t.string   "state",                     limit: 255
    t.string   "client_key",                limit: 255
    t.string   "auth_state_explanation",    limit: 255
    t.string   "sync_status",               limit: 255
    t.datetime "last_sync_time"
    t.boolean  "marked_for_deletion"
    t.string   "client_digest",             limit: 255
    t.integer  "sync_forced",                           default: 0
    t.datetime "last_successful_sync_time"
  end

  create_table "luau_group_memberships", force: :cascade do |t|
    t.integer "luau_group_id", null: false
    t.integer "group_id",      null: false
  end

  create_table "luau_group_user_mappings", force: :cascade do |t|
    t.integer "luau_group_id"
    t.string  "user_login",    limit: 255
  end

  create_table "luau_groups", force: :cascade do |t|
    t.string  "identifier",             limit: 255,                 null: false
    t.string  "full_name",              limit: 255,                 null: false
    t.boolean "restricted_to_readonly",             default: false, null: false
    t.string  "name",                   limit: 255
    t.index ["identifier"], name: "idx_luau_groups_on_ident", unique: true, using: :btree
  end

  create_table "luau_groups_mappings", force: :cascade do |t|
    t.integer "parent_group_id",                 null: false
    t.integer "child_group_id",                  null: false
    t.boolean "direct",          default: false, null: false
    t.index ["parent_group_id", "child_group_id"], name: "idx_parent_child", unique: true, using: :btree
  end

  create_table "luau_lock_fail", force: :cascade do |t|
    t.string "lock_fail", limit: 1, null: false
  end

  create_table "member_roles", force: :cascade do |t|
    t.integer "deliverable_id",             null: false
    t.string  "member_type",    limit: 255, null: false
    t.integer "member_id",                  null: false
    t.string  "permission",     limit: 255
    t.index ["deliverable_id", "member_type", "member_id"], name: "idx_unique_member_roles", unique: true, using: :btree
  end

  create_table "murmur_channels", id: :integer, default: -> { "nextval('collaboration_settings_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "project_id",                                                     null: false
    t.string  "jabber_chat_room_id",     limit: 255
    t.string  "jabber_chat_room_status", limit: 255
    t.boolean "enabled"
    t.string  "type",                    limit: 255, default: "BuiltInChannel"
  end

  create_table "murmurs", force: :cascade do |t|
    t.integer  "project_id",                                             null: false
    t.string   "packet_id",        limit: 255
    t.string   "jabber_user_name", limit: 255
    t.datetime "created_at",                                             null: false
    t.text     "murmur",                                                 null: false
    t.integer  "author_id"
    t.string   "origin_type",      limit: 255
    t.integer  "origin_id"
    t.string   "type",             limit: 255, default: "DefaultMurmur"
    t.integer  "conversation_id"
    t.string   "source",           limit: 255
    t.index ["conversation_id"], name: "index_murmurs_on_conversation_id", using: :btree
    t.index ["project_id", "created_at"], name: "index_murmurs_on_project_id_and_created_at", using: :btree
  end

  create_table "murmurs_read_counts", force: :cascade do |t|
    t.integer "user_id",                null: false
    t.integer "project_id",             null: false
    t.integer "read_count", default: 0
  end

  create_table "oauth_authorizations", force: :cascade do |t|
    t.string   "user_id",         limit: 255
    t.integer  "oauth_client_id"
    t.string   "code",            limit: 255
    t.integer  "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "oauth_clients", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.string   "client_id",     limit: 255
    t.string   "client_secret", limit: 255
    t.string   "redirect_uri",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "oauth_tokens", force: :cascade do |t|
    t.string   "user_id",         limit: 255
    t.integer  "oauth_client_id"
    t.string   "access_token",    limit: 255
    t.string   "refresh_token",   limit: 255
    t.integer  "expires_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "obj_prop_defs", id: :integer, default: -> { "nextval('objective_prop_defs_id_seq'::regclass)" }, force: :cascade do |t|
    t.string   "name",        limit: 255, null: false
    t.integer  "program_id"
    t.string   "type",        limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
    t.index ["program_id", "name"], name: "index_obj_prop_defs_on_program_id_and_name", unique: true, using: :btree
  end

  create_table "obj_prop_mappings", id: :integer, default: -> { "nextval('objective_prop_mappings_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "obj_prop_def_id"
    t.integer "objective_type_id"
    t.index ["obj_prop_def_id", "objective_type_id"], name: "index_obj_prop_mappings_on_obj_prop_def_id_and_41de0810630f428c", unique: true, using: :btree
  end

  create_table "obj_prop_value_mappings", force: :cascade do |t|
    t.integer  "objective_id"
    t.integer  "obj_prop_value_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["obj_prop_value_id", "objective_id"], name: "index_obj_prop_value_mappings_on_obj_prop_valuea872878e2f4b044c", unique: true, using: :btree
  end

  create_table "obj_prop_values", force: :cascade do |t|
    t.integer  "obj_prop_def_id"
    t.string   "value",           limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["obj_prop_def_id", "value"], name: "index_obj_prop_values_on_obj_prop_def_id_and_value", unique: true, using: :btree
  end

  create_table "objective_filters", force: :cascade do |t|
    t.integer  "project_id"
    t.integer  "objective_id"
    t.string   "params",       limit: 4096
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "synced"
  end

  create_table "objective_snapshots", id: :integer, default: -> { "nextval('stream_histories_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer  "total"
    t.integer  "completed"
    t.integer  "project_id"
    t.integer  "objective_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "dated"
    t.index ["objective_id", "project_id", "dated"], name: "idx_obj_proj_dated", unique: true, using: :btree
    t.index ["project_id", "objective_id"], name: "index_stream_snapshots_on_project_id_and_stream_id", using: :btree
  end

  create_table "objective_types", force: :cascade do |t|
    t.integer  "program_id",                  null: false
    t.text     "value_statement"
    t.string   "name",            limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "objective_versions", force: :cascade do |t|
    t.integer  "objective_id"
    t.integer  "version"
    t.integer  "plan_id"
    t.integer  "vertical_position"
    t.string   "identifier",          limit: 255
    t.text     "value_statement"
    t.integer  "size",                            default: 0
    t.integer  "value",                           default: 0
    t.string   "name",                limit: 255
    t.datetime "start_at"
    t.datetime "end_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "modified_by_user_id"
    t.integer  "number"
    t.integer  "program_id"
    t.integer  "position"
    t.string   "status",              limit: 255, default: "PLANNED"
    t.integer  "objective_type_id"
  end

  create_table "objectives", id: :integer, default: -> { "nextval('streams_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer  "plan_id"
    t.string   "name",                limit: 80
    t.date     "start_at"
    t.date     "end_at"
    t.integer  "vertical_position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "identifier",          limit: 40
    t.text     "value_statement"
    t.integer  "size",                            default: 0
    t.integer  "value",                           default: 0
    t.integer  "version"
    t.integer  "modified_by_user_id"
    t.integer  "number"
    t.integer  "program_id"
    t.integer  "position"
    t.string   "status",              limit: 255, default: "PLANNED"
    t.integer  "objective_type_id"
  end

  create_table "page_versions", force: :cascade do |t|
    t.integer  "page_id"
    t.integer  "version"
    t.string   "name",                     limit: 255, default: ""
    t.text     "content"
    t.integer  "project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "created_by_user_id"
    t.integer  "modified_by_user_id"
    t.boolean  "has_macros",                           default: false
    t.text     "system_generated_comment"
    t.boolean  "redcloth"
    t.index ["project_id", "page_id", "version"], name: "idx_page_ver_on_page_ver", using: :btree
  end

  create_table "pages", force: :cascade do |t|
    t.string   "name",                limit: 255, default: "",    null: false
    t.text     "content"
    t.integer  "project_id"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "created_by_user_id"
    t.integer  "modified_by_user_id"
    t.integer  "version"
    t.boolean  "has_macros",                      default: false
    t.boolean  "redcloth"
    t.index ["name"], name: "index_pages_on_name", using: :btree
    t.index ["project_id"], name: "index_pages_on_project_id", using: :btree
  end

  create_table "perforce_configurations", force: :cascade do |t|
    t.integer "project_id"
    t.string  "username",                    limit: 255
    t.string  "password",                    limit: 255
    t.string  "port",                        limit: 255
    t.string  "host",                        limit: 255
    t.text    "repository_path"
    t.boolean "initialized"
    t.boolean "card_revision_links_invalid"
    t.boolean "marked_for_deletion",                     default: false
  end

  create_table "plans", force: :cascade do |t|
    t.date     "start_at"
    t.date     "end_at"
    t.integer  "program_id"
    t.integer  "precision",  default: 2
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "program_dependency_views", force: :cascade do |t|
    t.integer  "program_id",              null: false
    t.integer  "user_id",                 null: false
    t.string   "params",     limit: 4096
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["program_id", "user_id"], name: "index_program_dependency_views_on_program_id_and_user_id", unique: true, using: :btree
    t.index ["program_id"], name: "index_program_dependency_views_on_program_id", using: :btree
  end

  create_table "program_projects", id: :integer, default: -> { "nextval('plan_projects_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "project_id",                          null: false
    t.integer "done_status_id"
    t.integer "status_property_id"
    t.integer "program_id"
    t.boolean "accepts_dependencies", default: true
  end

  create_table "project_variables", force: :cascade do |t|
    t.integer "project_id",               null: false
    t.string  "data_type",    limit: 255, null: false
    t.string  "name",         limit: 255, null: false
    t.string  "value",        limit: 255
    t.integer "card_type_id"
  end

  create_table "projects_luau_group_memberships", force: :cascade do |t|
    t.integer "project_id",    null: false
    t.integer "luau_group_id", null: false
    t.index ["project_id", "luau_group_id"], name: "idx_luau_group_mbsps_on_proj_group_id", unique: true, using: :btree
  end

  create_table "property_definitions", force: :cascade do |t|
    t.string   "type",                         limit: 255
    t.integer  "project_id",                                                null: false
    t.string   "name",                         limit: 255,  default: "",    null: false
    t.text     "description"
    t.string   "column_name",                  limit: 255,  default: "",    null: false
    t.boolean  "hidden",                                    default: false, null: false
    t.boolean  "restricted",                                default: false, null: false
    t.boolean  "transition_only",                           default: false
    t.integer  "valid_card_type_id"
    t.boolean  "is_numeric",                                default: false
    t.integer  "tree_configuration_id"
    t.integer  "position"
    t.text     "formula"
    t.integer  "aggregate_target_id"
    t.string   "aggregate_type",               limit: 255
    t.integer  "aggregate_card_type_id"
    t.integer  "aggregate_scope_card_type_id"
    t.string   "ruby_name",                    limit: 255
    t.string   "dependant_formulas",           limit: 4096
    t.text     "aggregate_condition"
    t.boolean  "null_is_zero",                              default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["column_name"], name: "index_attribute_definitions_on_column_name", using: :btree
    t.index ["project_id", "name"], name: "index_property_definitions_on_project_id_and_name", unique: true, using: :btree
    t.index ["project_id", "ruby_name"], name: "M20120821135500_idx", unique: true, using: :btree
    t.index ["project_id"], name: "index_attribute_definitions_on_project_id", using: :btree
  end

  create_table "property_type_mappings", id: :integer, default: -> { "nextval('card_types_property_definitions_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "card_type_id",           null: false
    t.integer "property_definition_id", null: false
    t.integer "position"
    t.index ["card_type_id", "property_definition_id"], name: "idx_ctpd_on_ct_and_pd_id", using: :btree
    t.index ["card_type_id"], name: "index_card_types_property_definitions_on_card_type_id", using: :btree
    t.index ["property_definition_id"], name: "index_card_types_property_definitions_on_property_definition_id", using: :btree
  end

  create_table "revisions", force: :cascade do |t|
    t.integer  "project_id",                 null: false
    t.integer  "number",                     null: false
    t.text     "commit_message",             null: false
    t.datetime "commit_time",                null: false
    t.string   "commit_user",    limit: 255, null: false
    t.string   "identifier",     limit: 255
    t.index ["commit_time"], name: "idx_rev_on_commit_time", using: :btree
    t.index ["identifier"], name: "index_revisions_on_identifier", using: :btree
    t.index ["number"], name: "idx_rev_on_number", using: :btree
    t.index ["project_id"], name: "idx_rev_on_proj_id", using: :btree
  end

  create_table "saas_tos", force: :cascade do |t|
    t.string   "user_email", limit: 255
    t.boolean  "accepted",               default: false, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.string   "session_id", limit: 255, null: false
    t.text     "data"
    t.datetime "updated_at",             null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", using: :btree
  end

  create_table "stale_prop_defs", id: :integer, default: -> { "nextval('compute_aggregate_requests_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "card_id",     null: false
    t.integer "prop_def_id", null: false
    t.integer "project_id",  null: false
    t.index ["project_id", "card_id", "prop_def_id"], name: "idx_stagg_on_card_and_agg_pd", using: :btree
  end

  create_table "subversion_configurations", force: :cascade do |t|
    t.integer "project_id"
    t.string  "username",                    limit: 255
    t.string  "password",                    limit: 255
    t.text    "repository_path"
    t.boolean "card_revision_links_invalid"
    t.boolean "marked_for_deletion",                     default: false
    t.boolean "initialized"
  end

  create_table "tab_positions", force: :cascade do |t|
    t.integer "project_id"
    t.string  "html_id",    limit: 255, null: false
    t.integer "position"
  end

  create_table "table_sequences", id: :integer, default: -> { "nextval('sequences_id_seq'::regclass)" }, force: :cascade do |t|
    t.string  "name",       limit: 255
    t.integer "last_value"
    t.index ["name"], name: "index_sequences_on_name", unique: true, using: :btree
  end

  create_table "tabs", force: :cascade do |t|
    t.string  "name",        limit: 255
    t.integer "position"
    t.string  "tab_type",    limit: 255, null: false
    t.string  "target_type", limit: 255
    t.integer "target_id"
    t.integer "project_id",              null: false
  end

  create_table "taggings", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string  "taggable_type", limit: 255
    t.integer "position",                  default: 0, null: false
    t.index ["tag_id"], name: "index_taggings_on_tag_id", using: :btree
    t.index ["taggable_id", "taggable_type"], name: "idx_tagging_on_id_and_type", using: :btree
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id", using: :btree
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type", using: :btree
  end

  create_table "tags", force: :cascade do |t|
    t.string   "name",       limit: 255, default: "", null: false
    t.integer  "project_id",                          null: false
    t.datetime "deleted_at"
    t.string   "color",      limit: 255
    t.index ["name", "project_id"], name: "unique_tag_names", unique: true, using: :btree
    t.index ["name"], name: "index_tags_on_name", using: :btree
    t.index ["project_id"], name: "index_tags_on_project_id", using: :btree
  end

  create_table "temporary_id_storages", id: false, force: :cascade do |t|
    t.string  "session_id", limit: 255
    t.integer "id_1"
    t.integer "id_2"
    t.index ["session_id", "id_1"], name: "idx_tmp_sess_on_sess_and_id1", using: :btree
    t.index ["session_id"], name: "index_temporary_id_storages_on_session_id", using: :btree
  end

  create_table "tfsscm_configurations", force: :cascade do |t|
    t.integer "project_id"
    t.boolean "initialized"
    t.boolean "card_revision_links_invalid"
    t.boolean "marked_for_deletion",                     default: false
    t.string  "server_url",                  limit: 255
    t.string  "username",                    limit: 255
    t.string  "tfs_project",                 limit: 255
    t.string  "password",                    limit: 255
    t.string  "domain",                      limit: 255
    t.string  "collection",                  limit: 255
  end

  create_table "todos", force: :cascade do |t|
    t.integer  "user_id"
    t.boolean  "done",                   default: false
    t.string   "content",    limit: 255
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["user_id"], name: "todo_user_id_idx", using: :btree
  end

  create_table "transition_actions", force: :cascade do |t|
    t.integer "executor_id",                                  null: false
    t.integer "target_id",                                    null: false
    t.string  "value",               limit: 255, default: ""
    t.string  "executor_type",       limit: 255,              null: false
    t.string  "type",                limit: 255
    t.integer "variable_binding_id"
    t.index ["executor_id", "executor_type"], name: "idx_tact_on_exec_id_and_type", using: :btree
  end

  create_table "transition_prerequisites", force: :cascade do |t|
    t.integer "transition_id",                                   null: false
    t.string  "type",                   limit: 255, default: "", null: false
    t.integer "user_id"
    t.integer "property_definition_id"
    t.string  "value",                  limit: 255
    t.integer "project_variable_id"
    t.integer "group_id"
    t.index ["transition_id"], name: "idx_tpre_on_trans_id", using: :btree
  end

  create_table "transitions", force: :cascade do |t|
    t.integer "project_id",                                  null: false
    t.string  "name",            limit: 255, default: "",    null: false
    t.integer "card_type_id"
    t.boolean "require_comment",             default: false
    t.index ["project_id"], name: "idx_trans_on_proj_id", using: :btree
  end

  create_table "tree_belongings", id: :integer, default: -> { "nextval('card_trees_cards_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "tree_configuration_id", null: false
    t.integer "card_id",               null: false
    t.index ["tree_configuration_id", "card_id"], name: "unique_card_in_tree", unique: true, using: :btree
  end

  create_table "tree_configurations", id: :integer, default: -> { "nextval('card_trees_id_seq'::regclass)" }, force: :cascade do |t|
    t.string  "name",        limit: 255, null: false
    t.integer "project_id",              null: false
    t.string  "description", limit: 255
    t.index ["project_id", "name"], name: "uniq_tree_name_in_project", unique: true, using: :btree
  end

  create_table "user_display_preferences", force: :cascade do |t|
    t.integer "user_id",                                                 null: false
    t.boolean "sidebar_visible",                                         null: false
    t.boolean "favorites_visible",                                       null: false
    t.boolean "recent_pages_visible",                                    null: false
    t.boolean "color_legend_visible"
    t.boolean "filters_visible"
    t.boolean "history_have_been_visible"
    t.boolean "history_changed_to_visible"
    t.boolean "excel_import_export_visible"
    t.boolean "include_description"
    t.boolean "show_murmurs_in_sidebar"
    t.boolean "personal_favorites_visible"
    t.boolean "murmur_this_comment",                     default: true,  null: false
    t.boolean "explore_mingle_tab_visible",              default: true,  null: false
    t.text    "contextual_help",                         default: "{}",  null: false
    t.boolean "export_all_columns",                      default: false, null: false
    t.boolean "show_deactived_users",                    default: true,  null: false
    t.string  "timeline_granularity",        limit: 255
    t.boolean "grid_settings",                           default: true,  null: false
    t.text    "preferences"
  end

  create_table "user_engagements", force: :cascade do |t|
    t.integer "user_id",                              null: false
    t.boolean "trial_feedback_shown", default: false
  end

  create_table "user_filter_usages", force: :cascade do |t|
    t.integer "filterable_id"
    t.string  "filterable_type", limit: 255
    t.integer "user_id"
  end

  create_table "user_memberships", id: :integer, default: -> { "nextval('group_memberships_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer "group_id"
    t.integer "user_id"
    t.index ["user_id"], name: "user_memberships_user_id_idx", using: :btree
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                     limit: 255
    t.string   "password",                  limit: 255
    t.boolean  "admin"
    t.string   "version_control_user_name", limit: 255
    t.string   "login",                     limit: 255, default: "",    null: false
    t.string   "name",                      limit: 255
    t.boolean  "activated",                             default: true
    t.boolean  "light",                                 default: false
    t.string   "icon",                      limit: 255
    t.string   "jabber_user_name",          limit: 255
    t.string   "jabber_password",           limit: 255
    t.string   "salt",                      limit: 255
    t.boolean  "locked_against_delete",                 default: false
    t.boolean  "system",                                default: false
    t.string   "api_key",                   limit: 255
    t.string   "read_notification_digest",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["login"], name: "index_users_on_login", unique: true, using: :btree
  end

  create_table "variable_bindings", force: :cascade do |t|
    t.integer "project_variable_id",    null: false
    t.integer "property_definition_id", null: false
    t.index ["project_variable_id", "property_definition_id"], name: "idx_var_bind_on_pv_and_pd_id", using: :btree
  end

  create_table "works", id: :integer, default: -> { "nextval('scheduled_works_id_seq'::regclass)" }, force: :cascade do |t|
    t.integer  "objective_id"
    t.integer  "card_number"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "plan_id"
    t.boolean  "completed"
    t.string   "name",            limit: 255
    t.string   "bulk_updater_id", limit: 255
    t.integer  "project_id"
    t.index ["objective_id", "card_number", "project_id"], name: "idx_card_work", unique: true, using: :btree
    t.index ["plan_id", "objective_id"], name: "idx_works_on_plan_stream_id", using: :btree
    t.index ["plan_id", "project_id"], name: "idx_works_on_plan_proj_id", using: :btree
    t.index ["plan_id"], name: "idx_works_on_plan_id", using: :btree
    t.index ["project_id", "card_number"], name: "idx_works_on_proj_card_num", using: :btree
    t.index ["project_id"], name: "idx_works_on_proj_id", using: :btree
  end

end
