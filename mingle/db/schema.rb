# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20170816114316) do

  create_table 'asynch_requests', :force => true do |t|
    t.integer 'user_id',                                               :null => false
    t.string  'status'
    t.string  'progress_message',       :limit => 4000
    t.integer 'error_count',                            :default => 0, :null => false
    t.integer 'warning_count',                          :default => 0
    t.integer 'total',                                  :default => 1, :null => false
    t.integer 'completed',                              :default => 0, :null => false
    t.string  'type'
    t.text    'message'
    t.string  'deliverable_identifier',                                :null => false
    t.string  'tmp_file'
  end

  add_index 'asynch_requests', ['user_id', 'deliverable_identifier'], :name => 'idx_async_req_on_user_proj'
  add_index 'asynch_requests', ['user_id'], :name => 'idx_async_req_on_user_id'

  create_table 'attachings', :force => true do |t|
    t.integer 'attachment_id'
    t.integer 'attachable_id'
    t.string  'attachable_type'
  end

  add_index 'attachings', ['attachable_id', 'attachable_type'], :name => 'idx_attaching_on_id_and_type'
  add_index 'attachings', ['attachable_id'], :name => 'index_att_on_able_id'
  add_index 'attachings', ['attachable_type'], :name => 'index_att_on_able_type'
  add_index 'attachings', ['attachment_id'], :name => 'index_att_on_a_id'

  create_table 'attachments', :force => true do |t|
    t.string  'file',       :default => '', :null => false
    t.string  'path',       :default => '', :null => false
    t.integer 'project_id',                 :null => false
  end

  add_index 'attachments', ['project_id'], :name => 'idx_atchmnt_on_proj_id'

  create_table 'backlog_objectives', :force => true do |t|
    t.string  'name',            :limit => 80
    t.integer 'backlog_id'
    t.integer 'position'
    t.integer 'size',                           :default => 0
    t.integer 'value',                          :default => 0
    t.string  'value_statement', :limit => 750
  end

  create_table 'backlogs', :force => true do |t|
    t.integer 'program_id'
  end

  create_table 'cache_keys', :force => true do |t|
    t.integer  'deliverable_id'
    t.string   'structure_key'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.string   'card_key'
    t.string   'feed_key'
    t.string   'deliverable_type', :default => 'Project', :null => false
  end

  create_table 'card_defaults', :force => true do |t|
    t.integer 'card_type_id', :null => false
    t.integer 'project_id',   :null => false
    t.text    'description'
    t.boolean 'redcloth'
  end

  add_index 'card_defaults', ['card_type_id', 'project_id'], :name => 'idx_card_def_on_ct_and_proj_id'

  create_table 'card_list_views', :force => true do |t|
    t.integer  'project_id',                       :null => false
    t.string   'name',             :default => '', :null => false
    t.text     'params'
    t.text     'canonical_string'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'card_list_views', ['project_id'], :name => 'index_card_list_views_on_project_id'

  create_table 'card_murmur_links', :force => true do |t|
    t.integer 'card_id'
    t.integer 'project_id'
    t.integer 'murmur_id'
  end

  add_index 'card_murmur_links', ['card_id', 'murmur_id'], :name => 'idx_cml_on_card_and_mur_id'

  create_table 'card_revision_links', :force => true do |t|
    t.integer 'project_id',  :null => false
    t.integer 'card_id',     :null => false
    t.integer 'revision_id', :null => false
  end

  add_index 'card_revision_links', ['card_id', 'revision_id'], :name => 'idx_crl_on_card_and_rev_id'

  create_table 'card_types', :force => true do |t|
    t.integer 'project_id'
    t.string  'name',       :null => false
    t.string  'color'
    t.integer 'position'
  end

  add_index 'card_types', ['project_id'], :name => 'idx_card_types_on_proj_id'

  create_table 'card_versions', :force => true do |t|
    t.integer  'card_id'
    t.integer  'version'
    t.integer  'project_id'
    t.integer  'number'
    t.string   'name',                     :default => ''
    t.text     'description'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer  'created_by_user_id',       :default => 0,     :null => false
    t.integer  'modified_by_user_id',      :default => 0,     :null => false
    t.text     'comment'
    t.string   'card_type_name',                              :null => false
    t.boolean  'has_macros',               :default => false
    t.text     'system_generated_comment'
    t.string   'updater_id'
    t.boolean  'redcloth'
  end

  create_table 'cards', :force => true do |t|
    t.integer  'project_id',                                          :null => false
    t.integer  'number',                                              :null => false
    t.text     'description'
    t.datetime 'created_at',                                          :null => false
    t.datetime 'updated_at',                                          :null => false
    t.integer  'version'
    t.string   'card_type_name',                                      :null => false
    t.boolean  'has_macros',                       :default => false
    t.integer  'project_card_rank',   :scale => 0
    t.integer  'caching_stamp',                    :default => 0,     :null => false
    t.string   'name',                                                :null => false
    t.integer  'created_by_user_id',                                  :null => false
    t.integer  'modified_by_user_id',                                 :null => false
    t.boolean  'redcloth'
  end

  add_index 'cards', ['number'], :name => 'index_cards_on_number'
  add_index 'cards', ['project_id'], :name => 'index_cards_on_project_id'

  create_table 'changes', :force => true do |t|
    t.integer 'event_id',                      :null => false
    t.string  'type',          :default => '', :null => false
    t.string  'old_value'
    t.string  'new_value'
    t.integer 'attachment_id'
    t.integer 'tag_id'
    t.string  'field',         :default => '', :null => false
  end

  add_index 'changes', ['event_id', 'type'], :name => 'index_event_changes'

  create_table 'checklist_items', :force => true do |t|
    t.string   'text'
    t.boolean  'completed'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer  'card_id'
    t.integer  'project_id'
    t.integer  'position'
    t.string   'type',       :default => ''
  end

  add_index 'checklist_items', ['card_id'], :name => 'index_checklist_items_on_card_id'
  add_index 'checklist_items', ['project_id'], :name => 'index_checklist_items_on_project_id'

  create_table 'conversations', :force => true do |t|
    t.datetime 'created_at'
    t.integer  'project_id'
  end

  add_index 'conversations', ['project_id'], :name => 'index_conversations_on_project_id'

  create_table 'correction_changes', :force => true do |t|
    t.integer 'event_id'
    t.string  'old_value'
    t.string  'new_value'
    t.string  'change_type', :null => false
    t.integer 'resource_1'
    t.integer 'resource_2'
  end

  create_table 'deliverables', :force => true do |t|
    t.string   'name',                    :default => '',         :null => false
    t.string   'identifier',              :default => '',         :null => false
    t.text     'description'
    t.datetime 'created_at',                                      :null => false
    t.datetime 'updated_at',                                      :null => false
    t.string   'icon'
    t.integer  'created_by_user_id'
    t.integer  'modified_by_user_id'
    t.string   'card_keywords'
    t.boolean  'template'
    t.string   'secret_key'
    t.string   'email_address'
    t.string   'email_sender_name'
    t.boolean  'hidden',                  :default => false
    t.string   'date_format',             :default => '%d %b %Y'
    t.string   'time_zone'
    t.integer  'precision',               :default => 2
    t.boolean  'anonymous_accessible',    :default => false
    t.boolean  'corruption_checked'
    t.text     'corruption_info'
    t.string   'auto_enroll_user_type'
    t.string   'cards_table'
    t.string   'card_versions_table'
    t.boolean  'membership_requestable'
    t.string   'type'
    t.boolean  'pre_defined_template'
    t.integer  'landing_tab_id'
    t.text     'ordered_tab_identifiers'
    t.boolean  'exclude_weekends_in_cta', :default => false,      :null => false
    t.boolean  'accepts_dependencies',    :default => false
    t.date     'last_export_date'
  end

  add_index 'deliverables', ['identifier', 'type'], :name => 'index_projects_on_identifier_and_type'
  add_index 'deliverables', ['name', 'type'], :name => 'index_projects_on_name_and_type', :unique => true

  create_table 'dependencies', :force => true do |t|
    t.string   'name',                                    :null => false
    t.text     'description'
    t.date     'desired_end_date',                        :null => false
    t.integer  'resolving_project_id'
    t.integer  'raising_project_id',                      :null => false
    t.integer  'number'
    t.datetime 'created_at'
    t.integer  'raising_user_id'
    t.string   'status',               :default => 'NEW', :null => false
    t.integer  'version'
    t.integer  'raising_card_number'
    t.datetime 'updated_at'
  end

  create_table 'dependency_resolving_cards', :force => true do |t|
    t.integer 'dependency_id',   :null => false
    t.string  'dependency_type'
    t.integer 'card_number'
    t.integer 'project_id',      :null => false
  end

  create_table 'dependency_versions', :force => true do |t|
    t.integer  'dependency_id',        :null => false
    t.integer  'version',              :null => false
    t.string   'name',                 :null => false
    t.text     'description'
    t.date     'desired_end_date',     :null => false
    t.integer  'resolving_project_id'
    t.integer  'raising_project_id',   :null => false
    t.integer  'number',               :null => false
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer  'raising_user_id'
    t.string   'status',               :null => false
    t.integer  'raising_card_number'
  end

  add_index 'dependency_versions', ['dependency_id'], :name => 'index_dependency_versions_on_dependency_id'

  create_table 'dependency_views', :force => true do |t|
    t.integer  'project_id',                 :null => false
    t.integer  'user_id',                    :null => false
    t.string   'params',     :limit => 4096
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'dependency_views', ['project_id', 'user_id'], :name => 'index_dependency_views_on_project_id_and_user_id', :unique => true
  add_index 'dependency_views', ['project_id'], :name => 'index_dependency_views_on_project_id'

  create_table 'enumeration_values', :force => true do |t|
    t.string  'value',                  :default => '', :null => false
    t.integer 'property_definition_id'
    t.string  'color'
    t.integer 'position'
  end

  add_index 'enumeration_values', ['position'], :name => 'index_enumeration_values_on_position'
  add_index 'enumeration_values', ['property_definition_id'], :name => 'index_enumeration_values_on_property_definition_id'
  add_index 'enumeration_values', ['value', 'property_definition_id'], :name => 'unique_enumeration_values', :unique => true
  add_index 'enumeration_values', ['value'], :name => 'index_enumeration_values_on_value'

  create_table 'events', :force => true do |t|
    t.string   'type',                                                      :null => false
    t.string   'origin_type',                                               :null => false
    t.integer  'origin_id',                                                 :null => false
    t.datetime 'created_at',                                                :null => false
    t.integer  'created_by_user_id'
    t.integer  'deliverable_id',                                            :null => false
    t.boolean  'history_generated',                  :default => false
    t.datetime 'mingle_timestamp'
    t.string   'deliverable_type',                   :default => 'Project', :null => false
    t.string   'details',            :limit => 4096
  end

  add_index 'events', ['created_by_user_id'], :name => 'index_events_on_created_by_user_id'
  add_index 'events', ['deliverable_id'], :name => 'idx_events_on_proj_id'
  add_index 'events', ['origin_type', 'origin_id'], :name => 'index_events_on_origin_type_and_origin_id'

  create_table 'favorites', :force => true do |t|
    t.integer  'project_id',                        :null => false
    t.string   'favorited_type',                    :null => false
    t.integer  'favorited_id',                      :null => false
    t.boolean  'tab_view',       :default => false, :null => false
    t.integer  'user_id'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'favorites', ['project_id', 'favorited_type', 'favorited_id'], :name => 'idx_fav_on_type_and_id'

  create_table 'git_configurations', :force => true do |t|
    t.integer 'project_id'
    t.string  'repository_path'
    t.string  'username'
    t.string  'password'
    t.boolean 'initialized'
    t.boolean 'card_revision_links_invalid'
    t.boolean 'marked_for_deletion',         :default => false
  end

  create_table 'githubs', :force => true do |t|
    t.string   'username'
    t.string   'repository'
    t.integer  'project_id'
    t.integer  'webhook_id'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'groups', :force => true do |t|
    t.string  'name'
    t.integer 'deliverable_id'
    t.boolean 'internal',       :default => false, :null => false
  end

  create_table 'hg_configurations', :force => true do |t|
    t.integer 'project_id'
    t.string  'repository_path'
    t.string  'username'
    t.string  'password'
    t.boolean 'initialized'
    t.boolean 'card_revision_links_invalid'
    t.boolean 'marked_for_deletion',         :default => false
  end

  create_table 'history_subscriptions', :force => true do |t|
    t.integer 'user_id',                  :null => false
    t.integer 'project_id',               :null => false
    t.text    'filter_params'
    t.integer 'last_max_card_version_id', :null => false
    t.integer 'last_max_page_version_id', :null => false
    t.integer 'last_max_revision_id',     :null => false
    t.string  'hashed_filter_params'
    t.string  'error_message'
  end

  add_index 'history_subscriptions', ['user_id', 'project_id'], :name => 'idx_hist_sub_on_proj_user'

  create_table 'licenses', :force => true do |t|
    t.boolean 'eula_accepted'
    t.text    'license_key'
  end

  create_table 'login_access', :force => true do |t|
    t.integer  'user_id',                                   :null => false
    t.string   'login_token'
    t.datetime 'last_login_at'
    t.string   'lost_password_key',         :limit => 4096
    t.datetime 'lost_password_reported_at'
    t.datetime 'first_login_at'
  end

  create_table 'luau_configs', :force => true do |t|
    t.string   'base_url'
    t.datetime 'submitted_at'
    t.string   'state'
    t.string   'client_key'
    t.string   'auth_state_explanation'
    t.string   'sync_status'
    t.datetime 'last_sync_time'
    t.boolean  'marked_for_deletion'
    t.string   'client_digest'
    t.integer  'sync_forced',               :default => 0
    t.datetime 'last_successful_sync_time'
  end

  create_table 'luau_group_memberships', :force => true do |t|
    t.integer 'luau_group_id', :null => false
    t.integer 'group_id',      :null => false
  end

  create_table 'luau_group_user_mappings', :force => true do |t|
    t.integer 'luau_group_id'
    t.string  'user_login'
  end

  create_table 'luau_groups', :force => true do |t|
    t.string  'identifier',                                :null => false
    t.string  'full_name',                                 :null => false
    t.boolean 'restricted_to_readonly', :default => false, :null => false
    t.string  'name'
  end

  add_index 'luau_groups', ['identifier'], :name => 'idx_luau_groups_on_ident', :unique => true

  create_table 'luau_groups_mappings', :force => true do |t|
    t.integer 'parent_group_id',                    :null => false
    t.integer 'child_group_id',                     :null => false
    t.boolean 'direct',          :default => false, :null => false
  end

  add_index 'luau_groups_mappings', ['parent_group_id', 'child_group_id'], :name => 'idx_parent_child', :unique => true

  create_table 'luau_lock_fail', :force => true do |t|
    t.string 'lock_fail', :limit => 1, :null => false
  end

  create_table 'member_roles', :force => true do |t|
    t.integer 'deliverable_id', :null => false
    t.string  'member_type',    :null => false
    t.integer 'member_id',      :null => false
    t.string  'permission'
  end

  add_index 'member_roles', ['deliverable_id', 'member_type', 'member_id'], :name => 'idx_unique_member_roles', :unique => true

  create_table 'murmur_channels', :force => true do |t|
    t.integer 'project_id',                                            :null => false
    t.string  'jabber_chat_room_id'
    t.string  'jabber_chat_room_status'
    t.boolean 'enabled'
    t.string  'type',                    :default => 'BuiltInChannel'
  end

  create_table 'murmurs', :force => true do |t|
    t.integer  'project_id',                                    :null => false
    t.string   'packet_id'
    t.string   'jabber_user_name'
    t.datetime 'created_at',                                    :null => false
    t.text     'murmur',                                        :null => false
    t.integer  'author_id'
    t.string   'origin_type'
    t.integer  'origin_id'
    t.string   'type',             :default => 'DefaultMurmur'
    t.integer  'conversation_id'
    t.string   'source'
  end

  add_index 'murmurs', ['conversation_id'], :name => 'index_murmurs_on_conversation_id'
  add_index 'murmurs', ['project_id', 'created_at'], :name => 'index_murmurs_on_project_id_and_created_at'

  create_table 'murmurs_read_counts', :force => true do |t|
    t.integer 'user_id',                   :null => false
    t.integer 'project_id',                :null => false
    t.integer 'read_count', :default => 0
  end

  create_table 'oauth_authorizations', :force => true do |t|
    t.string   'user_id'
    t.integer  'oauth_client_id'
    t.string   'code'
    t.integer  'expires_at'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'oauth_clients', :force => true do |t|
    t.string   'name'
    t.string   'client_id'
    t.string   'client_secret'
    t.string   'redirect_uri'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'oauth_tokens', :force => true do |t|
    t.string   'user_id'
    t.integer  'oauth_client_id'
    t.string   'access_token'
    t.string   'refresh_token'
    t.integer  'expires_at'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'objective_filters', :force => true do |t|
    t.integer  'project_id'
    t.integer  'objective_id'
    t.string   'params',       :limit => 4096
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.boolean  'synced'
  end

  create_table 'objective_snapshots', :force => true do |t|
    t.integer  'total'
    t.integer  'completed'
    t.integer  'project_id'
    t.integer  'objective_id'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.date     'dated'
  end

  add_index 'objective_snapshots', ['project_id', 'objective_id', 'dated'], :name => 'idx_obj_proj_dated', :unique => true
  add_index 'objective_snapshots', ['project_id', 'objective_id'], :name => 'index_stream_snapshots_on_project_id_and_stream_id'

  create_table 'objective_versions', :force => true do |t|
    t.integer  'objective_id'
    t.integer  'version'
    t.integer  'plan_id'
    t.integer  'vertical_position'
    t.string   'identifier'
    t.string   'value_statement',     :limit => 750
    t.integer  'size',                               :default => 0
    t.integer  'value',                              :default => 0
    t.string   'name'
    t.datetime 'start_at'
    t.datetime 'end_at'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer  'modified_by_user_id'
    t.integer  'number'
  end

  create_table 'objectives', :force => true do |t|
    t.integer  'plan_id'
    t.string   'name',                :limit => 80
    t.date     'start_at'
    t.date     'end_at'
    t.integer  'vertical_position'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.string   'identifier',          :limit => 40
    t.string   'value_statement',     :limit => 750
    t.integer  'size',                               :default => 0
    t.integer  'value',                              :default => 0
    t.integer  'version'
    t.integer  'modified_by_user_id'
    t.integer  'number'
  end

  create_table 'page_versions', :force => true do |t|
    t.integer  'page_id'
    t.integer  'version'
    t.string   'name',                     :default => ''
    t.text     'content'
    t.integer  'project_id'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer  'created_by_user_id'
    t.integer  'modified_by_user_id'
    t.boolean  'has_macros',               :default => false
    t.text     'system_generated_comment'
    t.boolean  'redcloth'
  end

  add_index 'page_versions', ['page_id', 'version', 'project_id'], :name => 'idx_page_ver_on_page_ver'

  create_table 'pages', :force => true do |t|
    t.string   'name',                :default => '',    :null => false
    t.text     'content'
    t.integer  'project_id'
    t.datetime 'created_at',                             :null => false
    t.datetime 'updated_at',                             :null => false
    t.integer  'created_by_user_id'
    t.integer  'modified_by_user_id'
    t.integer  'version'
    t.boolean  'has_macros',          :default => false
    t.boolean  'redcloth'
  end

  add_index 'pages', ['name'], :name => 'index_pages_on_name'
  add_index 'pages', ['project_id'], :name => 'index_pages_on_project_id'

  create_table 'perforce_configurations', :force => true do |t|
    t.integer 'project_id'
    t.string  'username'
    t.string  'password'
    t.string  'port'
    t.string  'host'
    t.text    'repository_path'
    t.boolean 'initialized'
    t.boolean 'card_revision_links_invalid'
    t.boolean 'marked_for_deletion',         :default => false
  end

  create_table 'plans', :force => true do |t|
    t.date     'start_at'
    t.date     'end_at'
    t.integer  'program_id'
    t.integer  'precision',  :default => 2
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'program_dependency_views', :force => true do |t|
    t.integer  'program_id',                 :null => false
    t.integer  'user_id',                    :null => false
    t.string   'params',     :limit => 4096
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'program_dependency_views', ['program_id', 'user_id'], :name => 'index_program_dependency_views_on_program_id_and_user_id', :unique => true
  add_index 'program_dependency_views', ['program_id'], :name => 'index_program_dependency_views_on_program_id'

  create_table 'program_projects', :force => true do |t|
    t.integer 'project_id',                             :null => false
    t.integer 'done_status_id'
    t.integer 'status_property_id'
    t.integer 'program_id'
    t.boolean 'accepts_dependencies', :default => true
  end

  create_table 'project_variables', :force => true do |t|
    t.integer 'project_id',   :null => false
    t.string  'data_type',    :null => false
    t.string  'name',         :null => false
    t.string  'value'
    t.integer 'card_type_id'
  end

  create_table 'projects_luau_group_memberships', :force => true do |t|
    t.integer 'project_id',    :null => false
    t.integer 'luau_group_id', :null => false
  end

  add_index 'projects_luau_group_memberships', ['project_id', 'luau_group_id'], :name => 'idx_luau_group_mbsps_on_proj_group_id', :unique => true

  create_table 'property_definitions', :force => true do |t|
    t.string   'type'
    t.integer  'project_id',                                                      :null => false
    t.string   'name',                                         :default => '',    :null => false
    t.text     'description'
    t.string   'column_name',                                  :default => '',    :null => false
    t.boolean  'hidden',                                       :default => false, :null => false
    t.boolean  'restricted',                                   :default => false, :null => false
    t.boolean  'transition_only',                              :default => false
    t.integer  'valid_card_type_id'
    t.boolean  'is_numeric',                                   :default => false
    t.integer  'tree_configuration_id'
    t.integer  'position'
    t.text     'formula'
    t.integer  'aggregate_target_id'
    t.string   'aggregate_type'
    t.integer  'aggregate_card_type_id'
    t.integer  'aggregate_scope_card_type_id'
    t.string   'ruby_name'
    t.string   'dependant_formulas',           :limit => 4096
    t.text     'aggregate_condition'
    t.boolean  'null_is_zero',                                 :default => false
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'property_definitions', ['column_name'], :name => 'index_attribute_definitions_on_column_name'
  add_index 'property_definitions', ['project_id', 'name'], :name => 'index_property_definitions_on_project_id_and_name', :unique => true
  add_index 'property_definitions', ['project_id', 'ruby_name'], :name => 'M20120821135500_idx', :unique => true
  add_index 'property_definitions', ['project_id'], :name => 'index_attribute_definitions_on_project_id'

  create_table 'property_type_mappings', :force => true do |t|
    t.integer 'card_type_id',           :null => false
    t.integer 'property_definition_id', :null => false
    t.integer 'position'
  end

  add_index 'property_type_mappings', ['card_type_id', 'property_definition_id'], :name => 'idx_ctpd_on_ct_and_pd_id'
  add_index 'property_type_mappings', ['card_type_id'], :name => 'index_card_types_property_definitions_on_card_type_id'
  add_index 'property_type_mappings', ['property_definition_id'], :name => 'index_card_types_property_definitions_on_property_definition_id'

  create_table 'revisions', :force => true do |t|
    t.integer  'project_id',     :null => false
    t.integer  'number',         :null => false
    t.text     'commit_message', :null => false
    t.datetime 'commit_time',    :null => false
    t.string   'commit_user',    :null => false
    t.string   'identifier'
  end

  add_index 'revisions', ['commit_time'], :name => 'idx_rev_on_commit_time'
  add_index 'revisions', ['identifier'], :name => 'index_revisions_on_identifier'
  add_index 'revisions', ['number'], :name => 'idx_rev_on_number'
  add_index 'revisions', ['project_id'], :name => 'idx_rev_on_proj_id'

  create_table 'saas_tos', :force => true do |t|
    t.string   'user_email'
    t.boolean  'accepted',   :default => false, :null => false
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  create_table 'sessions', :force => true do |t|
    t.string   'session_id', :null => false
    t.text     'data'
    t.datetime 'updated_at', :null => false
  end

  add_index 'sessions', ['session_id'], :name => 'index_sessions_on_session_id'

  create_table 'stale_prop_defs', :force => true do |t|
    t.integer 'card_id',     :null => false
    t.integer 'prop_def_id', :null => false
    t.integer 'project_id',  :null => false
  end

  add_index 'stale_prop_defs', ['card_id', 'prop_def_id', 'project_id'], :name => 'idx_stagg_on_card_and_agg_pd'

  create_table 'subversion_configurations', :force => true do |t|
    t.integer 'project_id'
    t.string  'username'
    t.string  'password'
    t.text    'repository_path'
    t.boolean 'card_revision_links_invalid'
    t.boolean 'marked_for_deletion',         :default => false
    t.boolean 'initialized'
  end

  create_table 'tab_positions', :force => true do |t|
    t.integer 'project_id'
    t.string  'html_id',    :null => false
    t.integer 'position'
  end

  create_table 'table_sequences', :force => true do |t|
    t.string  'name'
    t.integer 'last_value'
  end

  add_index 'table_sequences', ['name'], :name => 'index_sequences_on_name', :unique => true

  create_table 'tabs', :force => true do |t|
    t.string  'name'
    t.integer 'position'
    t.string  'tab_type',    :null => false
    t.string  'target_type'
    t.integer 'target_id'
    t.integer 'project_id',  :null => false
  end

  create_table 'taggings', :force => true do |t|
    t.integer 'tag_id'
    t.integer 'taggable_id'
    t.string  'taggable_type'
    t.integer 'position',      :default => 0, :null => false
  end

  add_index 'taggings', ['tag_id'], :name => 'index_taggings_on_tag_id'
  add_index 'taggings', ['taggable_id', 'taggable_type'], :name => 'idx_tagging_on_id_and_type'
  add_index 'taggings', ['taggable_id'], :name => 'index_taggings_on_taggable_id'
  add_index 'taggings', ['taggable_type'], :name => 'index_taggings_on_taggable_type'

  create_table 'tags', :force => true do |t|
    t.string   'name',       :default => '', :null => false
    t.integer  'project_id',                 :null => false
    t.datetime 'deleted_at'
    t.string   'color'
  end

  add_index 'tags', ['name', 'project_id'], :name => 'unique_tag_names', :unique => true
  add_index 'tags', ['name'], :name => 'index_tags_on_name'
  add_index 'tags', ['project_id'], :name => 'index_tags_on_project_id'

  create_table 'temporary_id_storages', :id => false, :force => true do |t|
    t.string  'session_id'
    t.integer 'id_1'
    t.integer 'id_2'
  end

  add_index 'temporary_id_storages', ['session_id', 'id_1'], :name => 'idx_tmp_sess_on_sess_and_id1'
  add_index 'temporary_id_storages', ['session_id'], :name => 'index_temporary_id_storages_on_session_id'

  create_table 'tfsscm_configurations', :force => true do |t|
    t.integer 'project_id'
    t.boolean 'initialized'
    t.boolean 'card_revision_links_invalid'
    t.boolean 'marked_for_deletion',         :default => false
    t.string  'server_url'
    t.string  'username'
    t.string  'tfs_project'
    t.string  'password'
    t.string  'domain'
    t.string  'collection'
  end

  create_table 'todos', :force => true do |t|
    t.integer  'user_id'
    t.boolean  'done',       :default => false
    t.string   'content'
    t.integer  'position'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'todos', ['user_id'], :name => 'todo_user_id_idx'

  create_table 'transition_actions', :force => true do |t|
    t.integer 'executor_id',                         :null => false
    t.integer 'target_id',                           :null => false
    t.string  'value',               :default => ''
    t.string  'executor_type',                       :null => false
    t.string  'type'
    t.integer 'variable_binding_id'
  end

  add_index 'transition_actions', ['executor_id', 'executor_type'], :name => 'idx_tact_on_exec_id_and_type'

  create_table 'transition_prerequisites', :force => true do |t|
    t.integer 'transition_id',                          :null => false
    t.string  'type',                   :default => '', :null => false
    t.integer 'user_id'
    t.integer 'property_definition_id'
    t.string  'value'
    t.integer 'project_variable_id'
    t.integer 'group_id'
  end

  add_index 'transition_prerequisites', ['transition_id'], :name => 'idx_tpre_on_trans_id'

  create_table 'transitions', :force => true do |t|
    t.integer 'project_id',                         :null => false
    t.string  'name',            :default => '',    :null => false
    t.integer 'card_type_id'
    t.boolean 'require_comment', :default => false
  end

  add_index 'transitions', ['project_id'], :name => 'idx_trans_on_proj_id'

  create_table 'tree_belongings', :force => true do |t|
    t.integer 'tree_configuration_id', :null => false
    t.integer 'card_id',               :null => false
  end

  add_index 'tree_belongings', ['tree_configuration_id', 'card_id'], :name => 'unique_card_in_tree', :unique => true

  create_table 'tree_configurations', :force => true do |t|
    t.string  'name',        :null => false
    t.integer 'project_id',  :null => false
    t.string  'description'
  end

  add_index 'tree_configurations', ['name', 'project_id'], :name => 'uniq_tree_name_in_project', :unique => true

  create_table 'user_display_preferences', :force => true do |t|
    t.integer 'user_id',                                        :null => false
    t.boolean 'sidebar_visible',                                :null => false
    t.boolean 'favorites_visible',                              :null => false
    t.boolean 'recent_pages_visible',                           :null => false
    t.boolean 'color_legend_visible'
    t.boolean 'filters_visible'
    t.boolean 'history_have_been_visible'
    t.boolean 'history_changed_to_visible'
    t.boolean 'excel_import_export_visible'
    t.boolean 'include_description'
    t.boolean 'show_murmurs_in_sidebar'
    t.boolean 'personal_favorites_visible'
    t.boolean 'murmur_this_comment',         :default => true,  :null => false
    t.boolean 'explore_mingle_tab_visible',  :default => true,  :null => false
    t.text    'contextual_help',             :default => '{}',  :null => false
    t.boolean 'export_all_columns',          :default => false, :null => false
    t.boolean 'show_deactived_users',        :default => true,  :null => false
    t.string  'timeline_granularity'
    t.boolean 'grid_settings',               :default => true,  :null => false
    t.text    'preferences'
  end

  create_table 'user_engagements', :force => true do |t|
    t.integer 'user_id',                                 :null => false
    t.boolean 'trial_feedback_shown', :default => false
  end

  create_table 'user_filter_usages', :force => true do |t|
    t.integer 'filterable_id'
    t.string  'filterable_type'
    t.integer 'user_id'
  end

  create_table 'user_memberships', :force => true do |t|
    t.integer 'group_id'
    t.integer 'user_id'
  end

  add_index 'user_memberships', ['user_id'], :name => 'user_memberships_user_id_idx'

  create_table 'users', :force => true do |t|
    t.string   'email'
    t.string   'password'
    t.boolean  'admin'
    t.string   'version_control_user_name'
    t.string   'login',                     :default => '',    :null => false
    t.string   'name'
    t.boolean  'activated',                 :default => true
    t.boolean  'light',                     :default => false
    t.string   'icon'
    t.string   'jabber_user_name'
    t.string   'jabber_password'
    t.string   'salt'
    t.boolean  'locked_against_delete',     :default => false
    t.boolean  'system',                    :default => false
    t.string   'api_key'
    t.string   'read_notification_digest'
    t.datetime 'created_at'
    t.datetime 'updated_at'
  end

  add_index 'users', ['login'], :name => 'index_users_on_login', :unique => true

  create_table 'variable_bindings', :force => true do |t|
    t.integer 'project_variable_id',    :null => false
    t.integer 'property_definition_id', :null => false
  end

  add_index 'variable_bindings', ['project_variable_id', 'property_definition_id'], :name => 'idx_var_bind_on_pv_and_pd_id'

  create_table 'works', :force => true do |t|
    t.integer  'objective_id'
    t.integer  'card_number'
    t.datetime 'created_at'
    t.datetime 'updated_at'
    t.integer  'plan_id'
    t.boolean  'completed'
    t.string   'name'
    t.string   'bulk_updater_id'
    t.integer  'project_id'
  end

  add_index 'works', ['card_number', 'project_id', 'objective_id'], :name => 'idx_card_work', :unique => true
  add_index 'works', ['card_number', 'project_id'], :name => 'idx_works_on_proj_card_num'
  add_index 'works', ['objective_id', 'plan_id'], :name => 'idx_works_on_plan_stream_id'
  add_index 'works', ['plan_id', 'project_id'], :name => 'idx_works_on_plan_proj_id'
  add_index 'works', ['plan_id'], :name => 'idx_works_on_plan_id'
  add_index 'works', ['project_id'], :name => 'idx_works_on_proj_id'

end
