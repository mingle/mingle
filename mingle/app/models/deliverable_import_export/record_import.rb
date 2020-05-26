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

module DeliverableImportExport

  def insert_batch_size
    # we can make this configurable if needed
    ActiveRecord::Base.connection.database_vendor == :oracle ? 25 : 5000
  end
  module_function :insert_batch_size

  module RecordImport

    def import_table(table, options={}, &select)
      return if table.nil?
      return if table.imported?

      step("Importing #{table.name}...") do
        table.imported = true
        has_lob = table.columns.any? do |column|
          column.sql_type =~ /LOB\(|LOB$/i
        end
        columns = [table.column('id'), *table.columns]
        column_names = columns.map(&:name)

        table.each_slice(DeliverableImportExport.insert_batch_size) do |batch|
          data = []
          contexts = []
          SimpleBench.bench "building #{batch.size} rows for #{table.name}" do
            batch.each do |record|
              old_id = record.delete('id')
              new_id = table.sequence.next
              resolve_associations(table, record)

              if block_given? && select.respond_to?(:call)
                next unless select.call(record, old_id, new_id)
              end

              data << [new_id, *derive_values(table, record)]
              contexts << [record, old_id, new_id]
              table.map_ids(old_id, new_id)
              record['id'] = new_id
            end
          end
          next if data.empty?
          SimpleBench.bench "insert_bulk for #{data.size} rows #{table.name}" do
            connection.insert_multi_rows(table.target_name, column_names, data)
          end

          if connection.database_vendor == :oracle && has_lob
            SimpleBench.bench "insert LOBs" do
              batch.each do |record|
                connection.insert_large_objects(table, record, record['id'], table.columns)
              end
            end
          end

          if options[:after_insert].respond_to?(:call)
            contexts.each do |context|
              options[:after_insert].call(*context) # passes |record, old_id, new_id|
            end
          end

        end
      end
    end

    def column_mappings_for(table, record_keys)
      record_keys.inject({}) do |map, key|
        column = table.columns.detect do |c|
          Project.connection.column_name(key) == c.name
        end
        if column
          map[column.name] = key
        else
          Rails.logger.info("Could not find column by key: #{key.inspect}, in columns: #{table.columns.map(&:name).inspect}")
        end
        map
      end
    end
    memoize :column_mappings_for

    def derive_values(table, record)
      mappings = column_mappings_for(table, record.keys.sort)

      table.columns.collect do |c|
        # returning record[c.name] here used to be enough.  but in the case of importing an export from a different db into Oracle, where the schema version is the
        # same, c.name will be a shortened column name and the keys of record will not be shortened.  (note: this fix could not be tested with automation (bug 6251))
        c.type_cast(record[mappings[c.name]])
      end
    end

    def import_record(table, record, association_overrides = [], has_id=true)
      resolve_associations(table, record, association_overrides)
      new_id = insert_bind(table.insert_sql, table.columns.collect{|c| c.type_cast(record[c.name])}, table.columns, nil, nil, (has_id ? nil : -1), nil)
      connection.insert_large_objects(table, record, new_id)
      new_id
    end

    def resolve_associations(table, record, association_overrides=[])
      real_model = record['type'].blank? ? table.model : record['type'].constantize
      associations = associations_to_resolve(table.name, real_model, association_overrides)
      associations.each do |association|
        association_table = if association.options[:polymorphic]
          if association_model_name = record[association.options[:foreign_type]]
            association_model = association.active_record.send(:compute_type, association_model_name)
            find_table_by_model(association_model)
          end
        else
          find_table_by_model(association.klass)
        end

        if association_table
          import_table(association_table)
          foreign_key = association.primary_key_name.to_s
          record[foreign_key] = association_table.get_new_id(record[foreign_key])
        elsif [:created_by, :modified_by].include?(association.name)
          foreign_key = association.options.key?(:foreign_key) ? association.options[:foreign_key] : association.primary_key_name
          record[foreign_key] = User.current.id
        elsif association.active_record == CardCommentMurmur && association.name == :origin # ignore when no association_model_name for CardCommentMurmur (i.e. @card_comment_murmur.origin_type is null)
        elsif association.klass == ::User       # ignore
        else
          raise "Could not import #{table.name} because #{association.class_name} is not available"
        end
      end

      resolve_your_own_associations(real_model, table, record)
    end

    def associations_to_resolve(table_name, real_model, association_overrides)
      associations = association_overrides.dup
      associations += real_model.reflect_on_all_associations.select { |a| a.macro == :belongs_to } unless resolving_our_own_associations_for_table?(table_name)
      associations.delete_if { |association| resolving_our_own_association?(table_name, association.primary_key_name) }
    end

    def resolving_our_own_associations_for_table?(table_name)
      resolving_our_own_associations.include?({ :table => table_name })
    end

    def resolving_our_own_association?(table_name, column_name)
      resolving_our_own_associations.include?({ :table => table_name.to_s, :column => column_name.to_s })
    end

    def find_table_by_model(model)
      table_model = case
      when model == Deliverable
        Project
      when model.superclass == PropertyDefinition
        PropertyDefinition
      else
        model
      end
      @table_by_model[table_model]
    end

  end
end
