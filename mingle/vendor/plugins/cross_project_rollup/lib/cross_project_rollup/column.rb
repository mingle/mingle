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

#Copyright 2009 ThoughtWorks, Inc.  All rights reserved.

module CrossProjectRollup
  class Column
    include Mql
    
    attr_accessor :cells
    
    def initialize(projects, macro_params, column_params)
      @projects        = projects
      @row_property    = macro_params['rows']
      @rows_conditions = macro_params['rows-conditions']
      @aggregation     = Aggregation.create_from_param(column_params['aggregate'])
      @label           = column_params['label'] || @aggregation.aggregate_mql
      @conditions      = column_params['conditions']
      @cells           = {}
    end
      
    def get_data
      mql = build_mql :select_columns   => [@row_property, @aggregation.aggregate_mql],
                      :where_conditions => [@conditions, @rows_conditions],
                      :group_by         => @row_property
      data = @projects.map { |project| project.execute_mql(mql) }.flatten
      @cells = mql_result_to_cells(data)
    end
    
    def subtotal(subtotal_conditions)
      @aggregation.subtotal(@projects, subtotal_conditions, @conditions, @rows_conditions)
    end
    
    def total
      @aggregation.total(@cells)
    end
    
    def label
      @label
    end
    
    def cell_value(row_head)
      @cells[row_head] || 0
    end
    
    def mql_result_to_cells(data)
      return {} if data.blank?
      transformed_data = DataTransformer.new(@projects, data, @row_property, @label).transformed_data
      
      row_heads = transformed_data.map do |data_row|
        data_row[@row_property]
      end.uniq
      row_heads.each do |row_head|
        rows = transformed_data.select { |row_data| row_data[@row_property] == row_head }
        
        @cells[row_head] = @aggregation.cell_value(rows, label)
      end
      @cells
    end
    
    protected
    
    class Aggregation
      include Mql
      
      attr_reader :aggregate_mql
      
      def initialize(aggregate)
        @aggregate_mql = aggregate
      end
      
      def subtotal(projects, *conditions)
        subtotal_mql = build_mql :select_columns   => aggregate_mql, 
                                 :where_conditions => conditions
        data = projects.map do |project|
          project.execute_mql(subtotal_mql)
        end.flatten
        data.map(&:values).flatten.map(&:to_f).sum
      end
      
      def total(cells)
        cells.values.sum
      end
    end
    
    class Sum < Aggregation
      def cell_value(rows, column_key)
        rows.sum { |row_data| row_data[column_key].to_f }
      end
    end
    
    class Min < Aggregation
      def cell_value(rows, column_key)
        rows.map { |row_data| row_data[column_key].to_f }.min
      end
    end
    
    class Max < Aggregation
      def cell_value(rows, column_key)
        rows.map { |row_data| row_data[column_key].to_f }.max
      end
    end
    
    class Aggregation
      STRATEGIES = { 'sum' => Sum, 'count' => Sum, 'max' => Max, 'min' => Min }
      
      class << self
        def create_from_param(aggregate)
          aggregate =~ /(.*)\(.*\)/
          aggregate_type = $1.downcase
          raise("<b>#{aggregate_type}</b> is not a recognized aggregate function. #{STRATEGIES.keys.map(&:capitalize).sort.to_sentence} aggregate functions are supported.") unless STRATEGIES[aggregate_type]
          STRATEGIES[aggregate_type].new(aggregate)
        end
      end
    end
    
    class DataTransformer
      
      def initialize(projects, raw_data, row_property, label)
        @projects, @raw_data, @row_property, @label = projects, raw_data, row_property, label
      end
      
      def transformed_data
        group_by_property = GroupByProperty.new(@projects, @row_property)
        
        @raw_data.collect do |row|
          group_by_column, aggregate_column = get_column_names(row)
          if replace_aggregate_function_name_with_label?(aggregate_column)
            row[@label] = row.delete(aggregate_column)
          end
          
          if replace_group_by_property_value_with_row_property?(group_by_column)
            row[@row_property] = row.delete(group_by_column)
          end
          
          row[@row_property] = group_by_property.cross_project_normalize(row[@row_property])
          row
        end
      end
      
      protected
      
      def get_column_names(row)
        return unless row
        row.keys.partition { |key| key.downcase == @row_property.downcase }.flatten
      end
      
      def replace_aggregate_function_name_with_label?(aggregate_column)
        @label != aggregate_column
      end
      
      def replace_group_by_property_value_with_row_property?(group_by_column)
        @row_property != group_by_column
      end
    end
  end
end
