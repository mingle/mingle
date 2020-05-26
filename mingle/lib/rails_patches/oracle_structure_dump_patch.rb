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

if RUBY_PLATFORM =~ /java/
  module ::JdbcSpec::Oracle

    def structure_dump #:nodoc:
      s = user_sequences_dump
      s << user_tables_dump
      s << user_indexes_dump
    end

    def user_sequences_dump
      #The following patch makes sequences faithful to development
      # ---- patched block begin ---- #
      select_all("select * from user_sequences").inject("") do |structure, sequence_details|
        create_sequence_statement = "create sequence #{sequence_details['sequence_name']}"
        create_sequence_statement << " NOCACHE" if sequence_details['cache_size'].to_i == 0
        create_sequence_statement << " ORDER" if sequence_details['order_flag'].downcase == 'y'
        structure << "#{create_sequence_statement};\n\n"
      end
    end

    def user_tables_dump
      # ---- patched block end   ---- #
      # this patch makes it so the 'primary key' keywords are added to the create table sql
      select_all("select table_name from user_tables").map{|t|t.to_a.first.last}.sort.inject("") do |structure, table|
        ddl = "create table #{table} (\n "

        # ---- patched block begin ---- #
        primary_key_cols = select_values(%{ select cc.column_name
                                            from all_constraints c, all_cons_columns cc
                                            where c.table_name = '#{table}'
                                            and c.constraint_type = 'P'
                                            and cc.owner = c.owner
                                            and cc.constraint_name = c.constraint_name })
        # ---- patched block end   ---- #

        cols = select_all(%Q{
              select column_name, data_type, data_length, data_precision, data_scale, data_default, nullable
              from user_tab_columns
              where table_name = '#{table}'
              order by column_id
            }).map do |row|
          row = row.inject({}) do |h,args|
            h[args[0].downcase] = args[1]
            h
          end
          col = "#{quote_column_name row['column_name'].downcase} #{row['data_type'].downcase}"  # here is another patched line (we quote column name)
          if row['data_type'] =='NUMBER' and !row['data_precision'].nil?
            col << "(#{row['data_precision'].to_i}"
            col << ",#{row['data_scale'].to_i}" if !row['data_scale'].nil?
            col << ')'
          elsif row['data_type'].include?('CHAR')
            col << "(#{row['data_length'].to_i})"
          end
          col << " default #{row['data_default']}" if !row['data_default'].nil?
          col << ' not null' if row['nullable'] == 'N'
          # ---- patched block begin ---- #
          col << ' primary key ' if primary_key_cols.any? { |pk_col| pk_col.downcase == row['column_name'].downcase }
          # ---- patched block end   ---- #
          col
        end
        ddl << cols.join(",\n ")
        ddl << ");\n\n"
        structure << ddl
      end

    end

    def user_indexes_dump
      indices_sqls = select_all("select * from user_indexes where index_type = 'NORMAL'").map do |index|
        next if index['index_name'] =~ /^sys_/i
        create_index_statement = "create #{index['uniqueness'] == 'UNIQUE' ? 'UNIQUE' : ''} index #{index['index_name']}"
        create_index_statement << " ON #{index['table_name']}"
        create_index_statement << "(#{index_columns(index['index_name'])})"
      end.reject(&:blank?)
      indices_sqls.sort.join(";\n\n") << ';'
    end

    def index_columns(index_name)
      select_all("select column_name from user_ind_columns where index_name = '#{index_name}' order by column_position").inject([]) do |columns, column_information|
        columns << column_information["column_name"].inspect
      end.join(",")
    end

  end
end
