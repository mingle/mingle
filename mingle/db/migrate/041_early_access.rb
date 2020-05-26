#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

class EarlyAccess < ActiveRecord::Migration
  
  def self.up
    create_table "attachings", :force => true do |t|
      t.column "attachment_id",   :integer
      t.column "attachable_id",   :integer
      t.column "attachable_type", :string
    end

    create_table "attachments", :force => true do |t|
      t.column "file",       :string,  :default => "", :null => false
      t.column "path",       :string,  :default => "", :null => false
      t.column "project_id", :integer,                 :null => false
    end

    create_table "card_imports", :force => true do |t|
      t.column "project_id",    :integer,                                :null => false
      t.column "size",          :integer,                 :default => 0, :null => false
      t.column "created_count", :integer,                 :default => 0, :null => false
      t.column "updated_count", :integer,                 :default => 0, :null => false
      t.column "error_count",   :integer,                 :default => 0, :null => false
      t.column "status",        :string
      t.column "mapping",       :string,  :limit => safe_limit(4096)
      t.column "ignore",        :string,  :limit => safe_limit(4096)
      t.column "user_id",       :integer,                                :null => false
    end

    create_table "card_list_views", :force => true do |t|
      t.column "project_id", :integer,                                 :null => false
      t.column "name",       :string,                  :default => "", :null => false
      t.column "params",     :string,  :limit => safe_limit(4096)
      t.column "tab_view",   :boolean
    end

    add_index "card_list_views", ["project_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_card_list_views_on_project_id"

    create_table "card_revision_links", :force => true do |t|
      t.column "project_id",  :integer, :null => false
      t.column "card_id",     :integer, :null => false
      t.column "revision_id", :integer, :null => false
    end

    create_table "card_versions", :force => true do |t|
      t.column "card_id",             :integer
      t.column "version",             :integer
      t.column "project_id",          :integer
      t.column "number",              :integer
      t.column "name",                :string,   :default => ""
      t.column "description",         :text
      t.column "created_at",          :datetime
      t.column "updated_at",          :datetime
      t.column "created_by_user_id",  :integer,  :default => 0,  :null => false
      t.column "modified_by_user_id", :integer,  :default => 0,  :null => false
      t.column "comment",             :text
    end

    create_table "cards", :force => true do |t|
      t.column "project_id",          :integer,                  :null => false
      t.column "number",              :integer,                  :null => false
      t.column "name",                :string,   :default => "", :null => false
      t.column "description",         :text
      t.column "created_at",          :datetime,                 :null => false
      t.column "updated_at",          :datetime,                 :null => false
      t.column "version",             :integer
      t.column "tag_list",            :text
      t.column "created_by_user_id",  :integer,  :default => 0,  :null => false
      t.column "modified_by_user_id", :integer,  :default => 0,  :null => false
    end

    add_index "cards", ["number"], :name => "#{ActiveRecord::Base.table_name_prefix}index_cards_on_number"
    add_index "cards", ["project_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_cards_on_project_id"

    create_table "changes", :force => true do |t|
      t.column "version_id",         :integer,                  :null => false
      t.column "version_type",       :string,   :default => "", :null => false
      t.column "type",               :string,   :default => "", :null => false
      t.column "old_value",          :string
      t.column "new_value",          :string
      t.column "attachment_id",      :integer
      t.column "tag_id",             :integer
      t.column "field",              :string,   :default => "", :null => false
      t.column "project_id",         :integer,                  :null => false
      t.column "created_at",         :datetime,                 :null => false
      t.column "created_by_user_id", :integer
    end

    add_index "changes", ["version_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_changes_on_version_id"

    create_table "enumeration_values", :force => true do |t|
      t.column "value",                  :string,  :default => "", :null => false
      t.column "property_definition_id", :integer
      t.column "color",                  :string
      t.column "position",               :integer
    end

    add_index "enumeration_values", ["position"], :name => "#{ActiveRecord::Base.table_name_prefix}index_enumeration_values_on_position"
    add_index "enumeration_values", ["property_definition_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_enumeration_values_on_property_definition_id"
    add_index "enumeration_values", ["value"], :name => "#{ActiveRecord::Base.table_name_prefix}index_enumeration_values_on_value"

    create_table "generate_changes_requests", :force => true do |t|
      t.column "changed_id",   :integer, :null => false
      t.column "changed_type", :string,  :null => false
      t.column "project_id",   :integer, :null => false
    end

    create_table "history_subscriptions", :force => true do |t|
      t.column "user_id",                  :integer,                 :null => false
      t.column "project_id",               :integer,                 :null => false
      t.column "filter_params",            :string,  :limit => safe_limit(4096)
      t.column "last_max_card_version_id", :integer,                 :null => false
      t.column "last_max_page_version_id", :integer,                 :null => false
      t.column "last_max_revision_id",     :integer,                 :null => false
    end

    create_table "licenses", :force => true do |t|
      t.column "install_date",  :date
      t.column "eula_accepted", :boolean
    end

    create_table "page_versions", :force => true do |t|
      t.column "page_id",             :integer
      t.column "version",             :integer
      t.column "name",                :string,   :default => ""
      t.column "content",             :text
      t.column "project_id",          :integer
      t.column "created_at",          :datetime
      t.column "updated_at",          :datetime
      t.column "created_by_user_id",  :integer
      t.column "modified_by_user_id", :integer
    end

    create_table "pages", :force => true do |t|
      t.column "name",                :string,   :default => "", :null => false
      t.column "content",             :text
      t.column "project_id",          :integer
      t.column "created_at",          :datetime,                 :null => false
      t.column "updated_at",          :datetime,                 :null => false
      t.column "created_by_user_id",  :integer
      t.column "modified_by_user_id", :integer
      t.column "version",             :integer
    end

    add_index "pages", ["name"], :name => "#{ActiveRecord::Base.table_name_prefix}index_pages_on_name"
    add_index "pages", ["project_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_pages_on_project_id"

    create_table "project_exports", :force => true do |t|
      t.column "project_id",       :integer,                 :null => false
      t.column "template",         :boolean,                 :null => false
      t.column "total_tables",     :integer
      t.column "completed_tables", :integer
      t.column "status_message",   :string
      t.column "completed",        :boolean
      t.column "failed",           :boolean
      t.column "filename",         :string,  :limit => safe_limit(4096)
      t.column "error_detail",     :string,  :limit => safe_limit(4096)
    end

    create_table "project_imports", :force => true do |t|
      t.column "project_id",          :integer
      t.column "project_name",        :string
      t.column "project_identifier",  :string
      t.column "directory",           :string
      t.column "completed",           :boolean
      t.column "failed",              :boolean
      t.column "created_at",          :date
      t.column "updated_at",          :date
      t.column "created_by_user_id",  :integer
      t.column "modified_by_user_id", :integer
      t.column "total_tables",        :integer
      t.column "completed_tables",    :integer
      t.column "status_message",      :string
    end

    create_table "projects", :force => true do |t|
      t.column "name",                        :string,   :default => "",    :null => false
      t.column "identifier",                  :string,   :default => "",    :null => false
      t.column "description",                 :text
      t.column "created_at",                  :datetime,                    :null => false
      t.column "updated_at",                  :datetime,                    :null => false
      t.column "repository_path",             :string
      t.column "icon",                        :string
      t.column "created_by_user_id",          :integer
      t.column "modified_by_user_id",         :integer
      t.column "card_keywords",               :string
      t.column "template",                    :boolean
      t.column "secret_key",                  :string
      t.column "email_address",               :string
      t.column "email_sender_name",           :string
      t.column "revisions_invalid",           :boolean,  :default => false, :null => false
      t.column "card_revision_links_invalid", :boolean,  :default => false, :null => false
      t.column "hidden",                      :boolean,  :default => false
    end

    add_index "projects", ["identifier"], :name => "#{ActiveRecord::Base.table_name_prefix}index_projects_on_identifier"

    create_table "projects_members", :force => true do |t|
      t.column "user_id",    :integer,                    :null => false
      t.column "project_id", :integer,                    :null => false
      t.column "admin",      :boolean, :default => false, :null => false
    end

    create_table "property_definitions", :force => true do |t|
      t.column "type",        :string
      t.column "project_id",  :integer,                    :null => false
      t.column "name",        :string,  :default => "",    :null => false
      t.column "description", :text
      t.column "column_name", :string,  :default => "",    :null => false
      t.column "hidden",      :boolean, :default => false, :null => false
      t.column "restricted",  :boolean, :default => false, :null => false
    end

    add_index "property_definitions", ["column_name"], :name => "#{ActiveRecord::Base.table_name_prefix}index_attribute_definitions_on_column_name"
    add_index "property_definitions", ["project_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_attribute_definitions_on_project_id"

    create_table "revisions", :force => true do |t|
      t.column "project_id",     :integer,                  :null => false
      t.column "number",         :integer,                  :null => false
      t.column "commit_message", :string,   :limit => safe_limit(4096), :null => false
      t.column "commit_time",    :datetime,                 :null => false
      t.column "commit_user",    :string,                   :null => false
    end

    create_table "sequences", :force => true do |t|
      t.column "name",       :string
      t.column "last_value", :integer
    end

    create_table "taggings", :force => true do |t|
      t.column "tag_id",        :integer
      t.column "taggable_id",   :integer
      t.column "taggable_type", :string
    end

    add_index "taggings", ["tag_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_taggings_on_tag_id"
    add_index "taggings", ["taggable_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_taggings_on_taggable_id"
    add_index "taggings", ["taggable_type"], :name => "#{ActiveRecord::Base.table_name_prefix}index_taggings_on_taggable_type"

    create_table "tags", :force => true do |t|
      t.column "name",       :string,   :default => "", :null => false
      t.column "project_id", :integer,                  :null => false
      t.column "deleted_at", :datetime
    end

    add_index "tags", ["name"], :name => "#{ActiveRecord::Base.table_name_prefix}index_tags_on_name"
    add_index "tags", ["project_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_tags_on_project_id"

    create_table "terms", :force => true do |t|
      t.column "project_id",      :integer
      t.column "searchable_id",   :integer
      t.column "searchable_type", :string
      t.column "attribute_name",  :string
      t.column "term",            :string
      t.column "associated_id",   :integer
      t.column "associated_type", :string
      t.column "weight",          :integer, :default => 1, :null => false
    end

    create_table "transition_actions", :force => true do |t|
      t.column "transition_id",          :integer,                 :null => false
      t.column "property_definition_id", :integer,                 :null => false
      t.column "value",                  :string,  :default => ""
    end

    create_table "transition_prerequisites", :force => true do |t|
      t.column "transition_id",          :integer,                 :null => false
      t.column "type",                   :string,  :default => "", :null => false
      t.column "user_id",                :integer
      t.column "property_definition_id", :integer
      t.column "value",                  :string
    end

    create_table "transitions", :force => true do |t|
      t.column "project_id", :integer,                 :null => false
      t.column "name",       :string,  :default => "", :null => false
    end

    create_table "update_full_text_index_requests", :force => true do |t|
      t.column "searchable_id",   :integer, :null => false
      t.column "searchable_type", :string,  :null => false
      t.column "project_id",      :integer, :null => false
    end

    create_table "users", :force => true do |t|
      t.column "email",                     :string
      t.column "password",                  :string
      t.column "admin",                     :boolean
      t.column "version_control_user_name", :string
      t.column "lost_password_key",         :string,   :limit => safe_limit(4096)
      t.column "lost_password_reported_at", :datetime
      t.column "login",                     :string,                   :default => "",   :null => false
      t.column "name",                      :string
      t.column "activated",                 :boolean,                  :default => true
    end

  end

  def self.down
    drop_table "attachings"
    drop_table "attachments"
    drop_table "card_imports"
    drop_table "card_list_views"
    drop_table "card_revision_links"
    drop_table "card_versions"
    drop_table "cards"
    drop_table "changes"
    drop_table "enumeration_values"
    drop_table "generate_changes_requests"
    drop_table "history_subscriptions"
    drop_table "licenses"
    drop_table "page_versions"
    drop_table "pages"
    drop_table "project_exports"
    drop_table "project_imports"
    drop_table "projects"
    drop_table "projects_members"
    drop_table "property_definitions"
    drop_table "revisions"
    drop_table "sequences"
    drop_table "taggings"
    drop_table "tags"
    drop_table "terms"
    drop_table "transition_actions"
    drop_table "transition_prerequisites"
    drop_table "transitions"
    drop_table "update_full_text_index_requests"
    drop_table "users"
  end
end
