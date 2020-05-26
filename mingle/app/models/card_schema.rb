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

class CardSchema
  class ColumnInvalidException < StandardError; end

  unless defined?(INVALID_SQL_NAMES)
    INVALID_SQL_NAMES = %w(and char created_by date decimal description from group id inner int join left modified_by name new number outer select some table type user using varchar varchar2 version where)
  end

  class << self
    def generate_cards_table_name(project_identifier)
      ActiveRecord::Base.connection.db_specific_table_name("#{project_identifier}_cards")
    end

    def generate_card_versions_table_name(project_identifier)
      ActiveRecord::Base.connection.db_specific_table_name("#{project_identifier}_card_versions")
    end
  end

  def initialize(project)
    @project = project
  end

  def invalid_identifier?(identifier)
    invalid_method_name = (Card.instance_methods + Card.private_instance_methods).include?(identifier)
    invalid_sql_name = INVALID_SQL_NAMES.include?(identifier) || identifier =~ /^\d/
    ends_with_question = identifier =~ /\?$/
    invalid_method_name || invalid_sql_name || ends_with_question
  end

  def unique_column_name_from_name(name, prefix, suffix=nil)
    generated_name = if name =~ /^[0-9A-Za-z\s_\-\'\?]+$/
      "#{prefix}_" << name.gsub(/\W/, '_').downcase
    else
      generate_unique_column_name(prefix, suffix)
    end
    name_without_suffix = if column_defined?(append_suffix(generated_name, suffix)) || exist_ruby_name?(generated_name)
      generate_unique_column_name(generated_name, suffix)
    else
      generated_name
    end
    append_suffix(name_without_suffix, suffix)
  end

  def add_column(column_name, column_type, index_column)
    add_column_without_reset_card(column_name, column_type, index_column)
    reset_column_information
  end

  def clear_column(column_name)
    all_card_models.each do |model|
      clear_column_if_exist(model, column_name)
    end
  end

  def remove_column(column_name, index_column=false)
    all_card_models.each do |model|
      remove_column_if_exist(model, column_name, index_column)
    end
    reset_column_information
  end

  def column_defined?(column_name)
    column_holders.any?{|holder| holder.column_name == column_name}
  end

  def exist_ruby_name?(column_name)
    @project.all_property_definitions.any?{|prop| prop.ruby_name == column_name}
  end

  def column_defined_in_card_table?(column_name)
    connection.column_defined_in_model?(Card, column_name)
  end

  def rename_column_value(column_name, old_value, new_value)
    reindex_project_cards(column_name, old_value)
    all_card_models.each do |model|
      model.update_all({column_name => new_value}, {column_name => old_value})
    end
  end

  def reindex_project_cards(column_name, old_value)
    sql = SqlHelper.sanitize_sql(%{SELECT ID FROM #{Card.quoted_table_name} WHERE #{column_name} = ? ORDER BY ID DESC}, old_value)
    card_ids = @project.connection.select_values(sql)
    FullTextSearch.index_card_selection(@project, card_ids)
  end

  def column_not_insync_properties
    columns_on_card = connection.columns(Card.table_name).collect(&:name)
    column_holders.reject do |holder|
      columns_on_card.include?(holder.column_name)
    end
  end

  def create_tables
    connection.create_table(Card.table_name, connection.cards_table_options) do |t|
      t.column "project_id",          :integer,  :null => false
      t.column "number",              :integer,  :null => false
      t.column "name",                :string,   :null => false
      t.column "description",         :text
      t.column "created_at",          :datetime, :null => false
      t.column "updated_at",          :datetime, :null => false
      t.column "version",             :integer
      t.column "created_by_user_id",  :integer, :references => 'users', :null => false
      t.column "modified_by_user_id", :integer, :references => 'users', :null => false
      t.column 'card_type_name',      :string, :null => false
      t.column 'has_macros',          :boolean, :null => false, :default => false
      t.column "project_card_rank",   :decimal
      t.column 'caching_stamp',   :integer, :null => false, :default => 0
      t.column 'redcloth',   :boolean
    end
    add_card_index

    connection.create_table(Card.versioned_table_name, connection.cards_table_options) do |t|
      t.column "card_id",                   :integer, :references => Card.table_name
      t.column "version",                   :integer
      t.column "project_id",                :integer
      t.column "number",                    :integer
      t.column "name",                      :string
      t.column "description",               :text
      t.column "created_at",                :datetime
      t.column "updated_at",                :datetime
      t.column "created_by_user_id",        :integer, :references => 'users', :null => false
      t.column "modified_by_user_id",       :integer, :references => 'users', :null => false
      t.column "comment",                   :text
      t.column "system_generated_comment",  :text
      t.column 'card_type_name',            :string, :null => false
      t.column 'has_macros',                :boolean, :null => false, :default => false
      t.column 'updater_id',                :string
      t.column 'redcloth',   :boolean
    end
    add_card_version_index
  end

  def create
    create_tables
    update
  end

  def update
    column_holders.each do |column_holder|
      add_column_without_reset_card(column_holder.column_name, column_holder.column_type, column_holder.index_column?)
    end
    reset_column_information
  end

  # when project identifier updated, we need update card/card_version table and index names
  def update_names
    old_card_table_name = Card.table_name
    old_card_versions_table_name = Card.versioned_table_name
    @project.set_cards_table_and_card_versions_table
    if old_card_table_name != Card.table_name
      connection.rename_table(old_card_table_name, Card.table_name)
      unless Card.table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
        remove_indexes(Card.table_name)
        add_card_index
      end
    end
    if old_card_versions_table_name != Card.versioned_table_name
      connection.rename_table(old_card_versions_table_name, Card.versioned_table_name)
      unless Card.versioned_table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
        remove_indexes(Card.versioned_table_name)
        add_card_version_index
      end
    end
  end

  def drop
    all_card_models.each do |model|
      connection.drop_table_if_exists(model.table_name)
    end
  end

  private

  def remove_indexes(table_name)
    connection.indexes(table_name).each do |index|
      connection.remove_index(table_name, :name => index.name)
    end
  end

  def add_card_index
    unless Card.table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
      connection.add_index(Card.table_name, :number, :unique => true)
    end
  end

  def add_card_version_index
    unless Card.versioned_table_name =~ Project::INTERNAL_TABLE_PREFIX_PATTERN
      connection.add_index(Card.versioned_table_name, :number)
      connection.add_index(Card.versioned_table_name, :version)
      connection.add_index(Card.versioned_table_name, :card_id)
      connection.execute "CREATE INDEX #{connection.index_name(Card.versioned_table_name, :column => 'updated_at')} ON #{connection.quote_table_name(Card.versioned_table_name)} (UPDATED_AT DESC)"
    end
  end

  def add_column_without_reset_card(column_name, column_type, index_column)
    raise ColumnInvalidException.new("#{column_name.bold} is invalid for card schema") if invalid_identifier?(column_name)
    all_card_models.each do |model|
      next if connection.column_defined_in_model?(model, column_name)
      connection.add_column(model.table_name, column_name, column_type, :references => nil)
      if index_column
        connection.add_index(model.table_name, column_name)
      end
    end
  end

  def remove_column_if_exist(model, column, index_column)
    if connection.column_defined_in_model?(model, column)
      if index_column
        connection.remove_index(model.table_name, column)
      end
      connection.remove_column(model.table_name, column)
    end
  end

  def append_suffix(name, suffix)
    suffix ? "#{name}_#{suffix}" : name
  end

  def generate_unique_column_name(name, suffix, number = 1)
    result = "#{name}_#{number}"
    return result unless column_defined?(append_suffix(result, suffix)) || exist_ruby_name?(result)
    generate_unique_column_name(name, suffix, number + 1)
  end

  def connection
    @project.connection
  end

  def column_holders
    @project.property_definitions_with_hidden_for_migration.reload
  end

  def clear_column_if_exist(model, column)
    connection.execute("UPDATE #{model.table_name} SET #{column}=null") if connection.column_defined_in_model?(model, column)
  end


  def reset_column_information
    all_card_models.each(&:reset_column_information)
  end

  def all_card_models
    [Card, Card::Version]
  end

end
