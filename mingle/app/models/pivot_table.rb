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

class PivotTable
  include MqlSupport

  class CaptionCell
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def to_s
      @value
    end
  end
  EMPTY_CELL = CaptionCell.new('&nbsp;')
  TOTALS_CELL = CaptionCell.new('Totals')

  class LabelCell
    attr_reader :query

    def initialize(property_value, query)
      @property_value = property_value
      @query = query
    end

    def value
      @property_value.charting_value || PropertyValue::NOT_SET
    end

    def to_s
      value.to_s
    end
  end

  class DataCell
    attr_reader :value
    attr_reader :query

    def initialize(data, column_property_value, options={})
      key = PivotTable.lookup_key(column_property_value, data)
      @value = if (data.keys.include?(key))
        data[key]
      elsif (!key.blank?)
        data[key.to_num.to_s]
      end
      @query = options[:query]
    end

    def has_query?
      !query.nil?
    end

    def to_s
      value.to_s
    end
  end

  def self.lookup_key(prop_value, data)
    key = prop_value.charting_value
    return '' if key.blank?
    if prop_value.property_definition.numeric?
      key = data.keys.detect { |k| !k.blank? && k.to_f == key.to_f} || key
    end
    key || ''
  end

  attr_reader :project
  attr_reader :rows
  attr_reader :columns
  attr_reader :conditions
  attr_reader :aggregation
  attr_reader :rows_query, :column_property_values, :row_property_values

  def initialize(project, options)
    @project = project
    @rows = property_from_options(options, :rows)
    @columns = property_from_options(options, :columns)
    @conditions = CardQuery.parse(options[:conditions] || '', {:content_provider => options[:content_provider], :alert_receiver => options[:alert_receiver]})
    @aggregation = options[:aggregation].nil? ? 'COUNT(*)' : options[:aggregation]
    @empty_columns = options[:empty_columns].nil? ? true : options[:empty_columns]
    @empty_rows = options[:empty_rows].nil? ? true : options[:empty_rows]
    @totals = options[:totals].nil? ? false : options[:totals]

    # determine what goes in header row and the header column
    @row_property_values = property_values(empty_rows?, rows)
    @column_property_values = property_values(empty_columns?, columns)

    # construct a query that is restricted and executed for each row
    @rows_query = CardQuery.parse("SELECT #{columns.as_mql}, #{aggregation}").restrict_with(conditions)
  end

  def table_data
    ([header_data] + body_data).tap  { |data| data << total_data if totals? }
  end

  def header_data
    [EMPTY_CELL] + column_property_values.collect do |column_property_value|
      column_query = rows_query.restrict_with(property_value_condition(columns, column_property_value))
      LabelCell.new(column_property_value, column_query)
    end
  end

  def body_data
    @__body_data__ ||= query_body_data
    @body_data ||= row_property_values.collect do |row_property_value|
      row_query = rows_query.restrict_with(property_value_condition(rows, row_property_value), :cast_numeric_columns => true)
      row_key = PivotTable.lookup_key(row_property_value, @__body_data__)
      row_data = @__body_data__[row_key]
      [LabelCell.new(row_property_value, row_query)] + column_property_values.collect do |column_property_value|
        cell_query = row_query.restrict_with(property_value_condition(columns, column_property_value), :cast_numeric_columns => true)
        DataCell.new(row_data, column_property_value, :query => cell_query)
      end
    end
  end

  def total_data
    totals_query = rows_query.dup
    totals_query.cast_numeric_columns = true
    data = totals_query.values_as_coords.stringify_keys!
    [TOTALS_CELL] + column_property_values.collect { |column_property_value| DataCell.new(data, column_property_value, :totals => true) }
  end

  def can_be_cached?
    conditions.can_be_cached?
  end

  private

  def query_body_data
    data_query = if rows.ignore_case_equal?(columns)
      CardQuery.parse("SELECT #{rows.as_mql}, #{aggregation} GROUP BY #{rows.as_mql}")
    else
      CardQuery.parse("SELECT #{rows.as_mql}, #{columns.as_mql}, #{aggregation} GROUP BY #{rows.as_mql}, #{columns.as_mql}")
    end.restrict_with(conditions, :cast_numeric_columns => true)

    rows_column, columns_column, aggregation_column, _ = if rows.ignore_case_equal?(columns)
      [data_query.columns[0]] + data_query.columns
    else
      data_query.columns
    end
    data = data_query.values.inject(Hash.new{|h,k|h[k]={}}) do |ret, row|
      row_id = rows_column.value_from(row, true)
      column_id = columns_column.value_from(row, true)
      ret[row_id.to_s][column_id.to_s] = project.to_num(aggregation_column.value_from(row, true))
      ret
    end
    # for some query, the null value maybe included, e.g. select count(*)
    if empty_columns? && !data.any?{|k,cs|cs.has_key?('')}
      d = empty_column_data
      data.each do |row, columns|
        columns[''] = d[row]
      end
    end
    if empty_rows? && !data.has_key?('')
      data[''] = empty_row_data.stringify_keys!
    end
    data
  end

  def empty_row_data
    rows_query.restrict_with("#{rows.as_mql} IS NULL", :cast_numeric_columns => true).values_as_coords
  end

  def empty_column_data
    CardQuery.parse("SELECT #{rows.as_mql}, #{aggregation}", :cast_numeric_columns => true).restrict_with(conditions).restrict_with("#{columns.as_mql} IS NULL").values_as_coords
  end

  def url_to_chart_id(type, url_id)
    return '' if url_id.blank?
    property_values_map(type)[url_id]
  end

  def totals?
    @totals
  end

  def empty_rows?
    @empty_rows
  end

  def empty_columns?
    @empty_columns
  end

  def property_values(display_all, name)
    prop_def = project.find_property_definition(name, :with_hidden => true)
    if display_all && prop_def.respond_to?(:property_values)
      prop_def.property_values.values << prop_def.property_value_from_db(nil)
    else
      values = distinct_property_query(prop_def.name).restrict_with(conditions).values
      values = values.collect do |record|
        record[prop_def.name]
      end

      values += [nil] if display_all
      prop_def.make_uniq(values).collect { |value| prop_def.property_value_from_url(value) }
    end
  end

  def property_value_condition(column_name, property_value)
    mql_number_condition = property_value.property_definition.refers_to_cards? ? 'NUMBER' : ''
    property_value.not_set? ? "#{column_name.as_mql} IS NULL" : "#{column_name.as_mql} = #{mql_number_condition} #{quote_mql_value(property_value.url_identifier)}"
  end

  def property_from_options(options, key)
    options[key].tap { |value| raise "Cannot use project as the #{key.to_s.bold} parameter." if value.downcase == 'project' }
  end
end
