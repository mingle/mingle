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

module ImportExport

  class << self
    def TEMPLATE_MODELS
      PROJECT_STRUCTURE_MODELS()
    end

    def TEMPLATE_EXEMPT_MODELS
      [Attachment, Attaching, Card, Tagging, Card::Version,
       CorrectionChange, TreeBelonging,
       User, MemberRole, UserMembership,
       HistorySubscription, Murmur, Conversation,
       DependencyView, CardChecklistItem
      ] + MinglePlugins::Source.available_plugins
    end

    def PROJECT_STRUCTURE_MODELS
      [Page, Page::Version, Event,
       CardDefaults, CardType, Project, PropertyTypeMapping, Tag,
       Transition, TransitionAction,
       TransitionPrerequisite, CardListView,
       PropertyDefinition, EnumerationValue, Favorite,
       ProjectVariable, VariableBinding,
       TreeConfiguration, Group]
    end

    def ALL_MODELS
      TEMPLATE_MODELS() + TEMPLATE_EXEMPT_MODELS()
    end
  end

  class Table
    include Enumerable, SqlHelper

    attr_reader :name

    def initialize(directory, name, target_name=nil)
      @directory = directory
      @name = name
      @target_name = target_name
    end

    def each(&proc)
      pages = Dir.entries(@directory).select do |file|
        file =~ /^#{@name}_[0-9]+\.yml$/ ||   # new style
          file == "#{@name}.yml"                # old style
      end.sort_by do |file|
        if file =~ /^#{@name}_([0-9]+)\.yml$/
          $1.to_i
        else
          0
        end
      end
      pages.each do |page|
        load(page).each(&proc)
      end
    end

    def load(file)
      file_content = File.read(File.join(@directory, file))
      # safe_load to ensure ruby objects are not injected
      YAML::safe_load(file_content, [Date, Time, DateTime])
      # Need to use JvYAML for compatibility with exports
      JvYAML.load(file_content)
    end

    def target_name
      @target_name || "#{ActiveRecord::Base.table_name_prefix}#{name}"
    end

    def source_name
      "#{ActiveRecord::Base.table_name_prefix}#{name}"
    end

    def insert_sql(columns)
      %{
        INSERT INTO #{quote_table_name(target_name)}
        (#{quote_column_names(columns).join(",")})
        VALUES (#{(['?'] * columns.size).join(',')})
      }
    end

    def insert_multi_sql(columns, rows)
      %Q{
          INSERT INTO #{quote_table_name(target_name)}
                      (#{quote_column_names(columns).join(",")})
               VALUES #{rows.join(",\n")}
      }
    end

    def insert_multi_sql_oracle(columns, rows)
      %Q{
        INSERT INTO #{quote_table_name(target_name)}
          (#{quote_column_names(columns).join(",\n")})
          #{rows.join("\nunion all ")}
      }
    end

    def reset_pk_sequence!
      ActiveRecord::Base.connection.reset_pk_sequence!(self.target_name)
    end

    def quote_column_names(column_names)
      column_names.collect { |column_name| ActiveRecord::Base.connection.quote_column_name(column_name) }
    end

    def first_of_type(type)
      find {|r| r['type'] == type.to_s}
    end

  end

  class TableModels

    def initialize(basedir)
      @tables = {}
      @basedir = basedir
    end

    def table(table_name, model = nil)
      @tables[table_name] ||= {}
      @tables[table_name][model] ||= ImportExport::TableWithModel.new(@basedir, table_name, model)
    end

  end

  class TableWithModel < Table
    include SqlHelper

    DEFAULT_PAGE_SIZE = 1000

    attr_writer :imported
    attr_reader :new_ids_by_old_id

    def initialize(directory, name, model, page_size = DEFAULT_PAGE_SIZE)
      super(directory, name)
      @page_size = page_size
      @imported = false
      @new_ids_by_old_id = {}
      @model = model
    end

    def sequence
      Sequence.find(@model.sequence_name_for_project_import)
    end

    # requires that sql selects a column with name of 'id'
    def write_pages(sql_method, deliverable)
      select_sql = select_sql_with_ordering(sql_method, deliverable)

      page = 0
      loop do
        sql = select_sql.dup
        model.connection.add_limit_offset!(sql, :limit => @page_size, :offset => page * @page_size)
        records = model.connection.select_all(sql)
        if model == Project && records.present?
          records.each do |project_record|
            project_record['cards_table'].gsub!(/^#{ActiveRecord::Base.table_name_prefix}/, '')
            project_record['card_versions_table'].gsub!(/^#{ActiveRecord::Base.table_name_prefix}/, '')
          end
        end

        break if page > 0 && records.size < 1
        dump(records, page)
        break if records.size < @page_size
        page += 1
      end
    end

    # be careful on count of record that selected out
    def select_records(sql_method, project)
      model.find_by_sql(select_sql(sql_method, project))
    end

    def write(sql, connection)
      dump(connection.select_all(sql))
    end

    def model
      raise "Can't find model for #{name.bold}" unless @model
      @model
    end

    def columns_hash
      @columns_hash ||= model.columns_hash_to_import
    end

    def columns
      @columns ||= columns_hash.values.reject{|c| c.primary}
    end

    def column_names
      @column_names ||= columns.collect(&:name)
    end

    def quoted_column_names
      @quoted_column_names ||= quote_column_names(column_names)
    end

    def column_types
      @column_types ||= columns.collect(&:type)
    end

    def column(column_name)
      columns_hash[column_name]
    end

    def target_name
      model.table_name
    end

    def imported?
      @imported
    end

    def insert_sql
      insert_column_names = quoted_column_names
      values = ['?'] * column_names.size
      if connection.prefetch_primary_key?(nil)
        insert_column_names.unshift('id')
        values.unshift(connection.next_id_sql(target_name))
      end

      @insert_sql ||= %{
        INSERT INTO #{quote_table_name(target_name)}
        (#{insert_column_names.join(",")})
        VALUES (#{values.join(',')})
      }
    end

    def reset_timestamps_sql(project)
      timestamp_fields = [column('created_at'), column('updated_at')].compact
      values = timestamp_fields.collect { |c| c.type_cast(Clock.now.utc) } + [project.id]
      names = timestamp_fields.collect(&:name)
      restriction_id_column = model.respond_to?(:deliverable_dependency_column) ? model.deliverable_dependency_column : 'project_id'
      reset_sql = "UPDATE #{quote_table_name(target_name)} SET #{names.collect { |column_name| column_name + ' = ?' }.join(', ')} WHERE #{restriction_id_column} = ?"
      [reset_sql, values, names]
    end

    def map_ids(old_id, new_id)
      new_ids_by_old_id[old_id_key(old_id)] = new_id
    end

    def get_old_id(new_id)
      return nil if new_id.blank?
      new_ids_by_old_id.detect {|key, value| value.to_s == new_id.to_s}.try(:first)
    end

    def get_new_id(old_id)
      return nil if old_id.blank?

      key = old_id_key(old_id)

      if new_ids_by_old_id[key]
        new_ids_by_old_id[key]
      else
        map_ids(old_id, sequence.next)
      end
    end

    private

    def select_sql_with_ordering(sql_method, project)
      order_by_id_sql = model.respond_to?(:order_by_id_sql) ? model.order_by_id_sql : "#{model.quoted_table_name}.id"
      "#{select_sql(sql_method, project)} ORDER BY #{order_by_id_sql}"
    end

    def select_sql(sql_method, project)
      if sql_method == DependenciesExporter::SQL_METHOD
        select_sql_with_multiple_ids(sql_method, project)
      else
        sql = model.send(sql_method)
        model.send(:sanitize_sql, [sql, *([project.id] * sql.count('?'))])
      end
    end

    def select_sql_with_multiple_ids(sql_method, deliverables)
      ids = deliverables.map(&:id).join(", ")
      sql = model.send(sql_method, ids)
      model.send(:sanitize_sql, [sql])
    end

    def old_id_key(old_id)
      old_id.to_s if old_id
    end

    def dump(records, page = 0)
      filename = File.join(@directory, "#{@name}_#{page}.yml")
      if File.exists?(filename)
        records = records + JvYAML.load(File.read(filename))
      end
      File.open(filename, 'w+') {|io| io.write(JvYAML.dump(records))}
    end
  end
end
