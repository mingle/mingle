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

require "simple_bench"

class ModelFreeImport
  include SqlHelper, DeliverableImportExport::ImportFileSupport

  class StubbedProject
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  MIGRATION_TABLE_NAME = 'schema_migrations'

  attr_accessor :directory

  def unzip(zip_file)
    self.directory = unzip_export(zip_file)
  end

  def project_identifier
    (table('projects') || table('deliverables')).to_a.first['identifier']
  end

  def program_identifier
    table('deliverables').to_a.find { |d| %w[Program Plan].include? d['type'] }['identifier']
  end

  def program?
    table('deliverables').to_a.any? { |d| %w[Program Plan].include? d['type'] }
  end

  def dependencies?
    (table("dependencies") || []).any? { |dep| !dep.nil? }
  end

  def project?
    !program? && !dependencies?
  end

  def old_cards_table_name
    @old_cards_table_name ||= (table('projects') || table('deliverables')).to_a.first['cards_table']
  end

  def old_card_versions_table_name
    @old_card_versions_table_name ||= (table('projects') || table('deliverables')).to_a.first['card_versions_table']
  end

  def table(table_name)
    @tables ||= {}
    if @tables[table_name]
      return @tables[table_name]
    end
    return nil unless yaml_file_exists?(self.directory, table_name)
    @tables[table_name] = ImportExport::Table.new(directory, table_name)
    if table_name == old_cards_table_name
      @tables[table_name] = ImportExport::Table.new(directory, table_name, card_table_name)
    elsif table_name == old_card_versions_table_name
      @tables[table_name] = ImportExport::Table.new(directory, table_name, card_version_table_name)
    end
    @tables[table_name]
  end

  def tables
    table_names_from_file_names.reject{|table_name| table_name.include?(MIGRATION_TABLE_NAME)}.collect{|table_name| table(table_name)}
  end

  def insert_data
    if self.project?
      SimpleBench.bench "create_card_and_card_version_tables" do
        create_card_and_card_version_tables
      end
    end
    tables.each do |table|
      SimpleBench.bench "insert_table #{table.name}" do
        insert_table(table)
      end
    end
  end

  def card_table_name
    ActiveRecord::Base.connection.safe_table_name(CardSchema.generate_cards_table_name(project_identifier))
  end

  def card_version_table_name
    ActiveRecord::Base.connection.safe_table_name(CardSchema.generate_card_versions_table_name(project_identifier))
  end

  def create_card_and_card_version_tables
    property_definition_column_names = table('property_definitions').collect { |record| record['column_name'] }

    connection.create_table(card_table_name, connection.cards_table_options) do |t|
      t.column "project_id",          :integer
      t.column "number",              :integer
      t.column "name",                :string
      t.column "description",         :text
      t.column "created_at",          :datetime
      t.column "updated_at",          :datetime
      t.column "version",             :integer
      t.column "created_by_user_id",  :integer, :null => true
      t.column "modified_by_user_id", :integer, :null => true
      t.column 'caching_stamp',       :integer, :null => false, :default => 0 if (schema_version >= 152 && schema_version < 165)

      if schema_version >= 48
        t.column('card_type_name',      :string)
        t.column('has_macros',          :boolean, :default => false)
      end

      if schema_version >= 20090116193934
        if schema_version >= 20150331180353
          t.column "project_card_rank", :decimal
        else
          t.column "project_card_rank", :integer
        end
      end

      t.column('caching_stamp',         :integer, :null => false, :default => 0) if schema_version >= 20091012061534

      if schema_version >= 20121213000420
        if schema_version >= 20130301000931
          t.column('redcloth', :boolean)
        else
          t.column('editor_style', :string)
        end
      end
      property_definition_column_names.each do |column_name|
        t.column column_name, :string
      end
    end

    connection.create_table(card_version_table_name, connection.cards_table_options) do |t|
      t.column "card_id",                   :integer
      t.column "version",                   :integer
      t.column "project_id",                :integer
      t.column "number",                    :integer
      t.column "name",                      :string
      t.column "description",               :text
      t.column "created_at",                :datetime
      t.column "updated_at",                :datetime
      t.column "created_by_user_id",        :integer, :null => true
      t.column "modified_by_user_id",       :integer, :null => true
      t.column "comment",                   :text
      t.column("system_generated_comment",  :text) if schema_version >= 83
      if schema_version >= 48
        t.column('card_type_name',            :string)
        t.column('has_macros',                :boolean, :default => false)
      end
      if schema_version >= 20090116004412
        t.column('updater_id',                :string)
      end

      if schema_version >= 20121213000420
        if schema_version >= 20130301000931
          t.column('redcloth', :boolean)
        else
          t.column('editor_style', :string)
        end
      end

      property_definition_column_names.each do |column_name|
        t.column column_name, :string
      end
    end
  end

  # obsoleted metadata tables from old versions of Rails that we should ignore
  def obsolete_tables
    [
      "#{ActiveRecord::Base.table_name_prefix}schema_info#{ActiveRecord::Base.table_name_suffix}",
      "#{ActiveRecord::Base.table_name_prefix}plugin_schema_info#{ActiveRecord::Base.table_name_suffix}",
    ]
  end

  def map_keys_to_jdbc_columns(table, record_keys)
    columns = connection.columns(table.target_name)
    record_keys.inject({}) do |map, key|
      column = columns.detect do |c|
        Project.connection.column_name(key) == c.name
      end
      map[key] = column
      map
    end
  end
  memoize :map_keys_to_jdbc_columns


  def insert_table(table)
    return if obsolete_tables.include?(table.target_name)

    should_import_dependency_events = self.dependencies?

    sorted_keys = nil
    mapping = nil
    sorted_cols = nil
    has_lob = nil
    table.each_slice(DeliverableImportExport.insert_batch_size) do |batch|
      sorted_keys ||= batch.first.keys.sort
      mapping ||= map_keys_to_jdbc_columns(table, sorted_keys)
      sorted_cols ||= sorted_keys.inject([]) do |result, key|
        unless mapping[key].nil?
          has_lob ||= mapping[key].sql_type =~ /LOB\(|LOB$/i
          result << mapping[key].name
        end
        result
      end.compact

      data = SimpleBench.bench "preparing data for multi-row insert" do
        batch.inject([]) do |memo, record|
          update_record_with_correct_cards_and_version_table_name(record) if table.target_name =~ /(deliverable|project)/

          next memo if (!should_import_dependency_events && table.target_name =~ /events/ && record["origin_type"].to_s =~ /^dependenc/i)

          row_to_insert = []
          sorted_keys.each do |key|
            value = record[key]
            unless (key == 'id' && value.blank? || mapping[key].nil?)
              row_to_insert << mapping[key].type_cast(value)
            end
          end
          memo << row_to_insert
          memo
        end
      end

      SimpleBench.bench "insert_bulk for #{data.size} rows #{table.name}" do
        connection.insert_multi_rows(table.target_name, sorted_cols, data)
      end

      if connection.database_vendor == :oracle && has_lob
        SimpleBench.bench "insert LOBs" do
          batch.each do |record|
            connection.insert_large_objects(table, record, record['id'], mapping.values.compact)
          end
        end
      end
    end
    table.reset_pk_sequence!
  end

  private
  def update_record_with_correct_cards_and_version_table_name(record)
    record['cards_table'] = card_table_name
    record['card_versions_table'] = card_version_table_name
  end
end
