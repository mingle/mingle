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

class XAxisLabels

  module Errors

    def start_same_as_a_property(start_label, x_axis_property_def)
      XAxisLabelsError.new("#{start_label.to_s.bold} is not a valid value for #{'start-label'.bold} since it is an existing value for property #{x_axis_property_def.name.bold}.", x_axis_property_def.project)
    end

    def tree_not_found(tree_name, project)
      XAxisLabelsError.new("Tree #{tree_name.bold} does not exist.", project)
    end

    module_function :start_same_as_a_property, :tree_not_found

  end

  def initialize(x_axis_property_def, params={})
    @x_axis_property_def = x_axis_property_def
    @labels = @x_axis_property_def.project.with_active_project do
      generate_labels
    end
  end


  def labels
    @labels
  end

  def prepend_artificial_start_label(show_start_label, start_label)
    # this could be a massive hack ... but it seems to work quite well for plotting the starting point of a burndown!!
    if show_start_label
      raise XAxisLabels::Errors.start_same_as_a_property(start_label, @x_axis_property_def) if @labels.include?(start_label.to_s)
      @labels.unshift(start_label.to_s)
    end
  end

  def reformat_values_from(options={})
    labels = options[:labels] || @labels
    labels
  end

  def label_value_for_input_value(value, project)
    @x_axis_property_def.label_value_for_charting(value)
  end

  private

  def generate_labels
    @x_axis_property_def.label_values_for_charting
  end
end

class DateXAxisLabels < XAxisLabels

  def initialize(x_axis_property_def, params={})
    @date_format = params[:date_format]
    @x_label_start = params[:x_label_start]
    @x_label_end = params[:x_label_end]
    @labels_query = params[:labels_query]
    super(x_axis_property_def, params)
  end

  def reformat_values_from(options={})
    another_project = options[:another_project]
    return @labels if @x_axis_property_def.project == another_project #optimization
    @labels.collect { |date_str| transform_date(date_str, another_project, @x_axis_property_def.project)  }
  end

  def label_value_for_input_value(label, project)
    transform_date(label, @x_axis_property_def.project, project)
  end

  private

  def transform_date(date_str, from_project, to_project)
    date = Date.parse_with_hint(date_str, from_project.date_format) rescue date_str
    date.respond_to?(:strftime) ? date.strftime(to_project.date_format) : date
  end

  def generate_labels
    values = @labels_query.nil? ? super : @labels_query.values.map{|h| h.values.first}
    fill_in_missing_x_labels_dates(values, @date_format, @x_label_start, @x_label_end)
  end

  def fill_in_missing_x_labels_dates(x_axis_values, date_format, _x_labels_start, _x_labels_end)

    x_axis_values = x_axis_values.compact

    # to dates in order to do a range
    start_date = Date.parse_with_hint(x_axis_values.first, @x_axis_property_def.project.date_format)
    specified_start_date = Date.parse_with_hint(_x_labels_start, @x_axis_property_def.project.date_format)
    start_date = specified_start_date if start_date.nil? || (specified_start_date && specified_start_date < start_date)

    end_date = Date.parse_with_hint(x_axis_values.last, @x_axis_property_def.project.date_format)
    specified_end_date = Date.parse_with_hint(_x_labels_end, @x_axis_property_def.project.date_format)
    end_date = specified_end_date if end_date.nil? || (specified_end_date && specified_end_date > end_date)
    return [] if start_date.nil? || end_date.nil?
    # back to strings ... ick :(
    (start_date..end_date).collect{|date| date.strftime(date_format)}
  end
end

class FreeNumericXAxisLabels < XAxisLabels
  def generate_labels
    XAxisLabelsHelper.format_labels(super, @x_axis_property_def)  end
end

class XAxisLabelsError < StandardError
  attr_reader :project

  def initialize(message, project=nil)
    @project = project
    super(message)
  end
end


class XAxisLabelsHelper
  class RestrictWithPrecision
    attr_reader :values, :x_axis_property_def
    def initialize(values, x_axis_property_def)
      @values, @x_axis_property_def = values, x_axis_property_def
    end

    def perform
      values.collect { |overly_precise_label| detect_existing_value_with_appropriate_precision_for(x_axis_property_def, overly_precise_label) }.uniq
    end

    private
    def detect_existing_value_with_appropriate_precision_for(property_definition, value)
      return value unless property_definition.numeric?
      value = value.to_s.trim

      # need to compare with BigDecimal to take account of variations in implicit precision
      idx = decimalized_unique_numeric_values_for(property_definition).index(BigDecimal.new(value.to_s.trim))

      # need to maintain original value from existing values.
      # while this looks duplicative, it's really not because it's memoized.
      existing_values = unique_numeric_values_for(property_definition)
      idx.nil? ? nil : unique_numeric_values_for(property_definition)[idx]
    end
    memoize :detect_existing_value_with_appropriate_precision_for

    def decimalized_unique_numeric_values_for(prop_def)
      unique_numeric_values_for(prop_def).map {|v| v ? BigDecimal.new(v.to_s.trim) : nil}
    end
    memoize :decimalized_unique_numeric_values_for

    def unique_numeric_values_for(prop_def)
      values = distinct_property_query(prop_def.name).single_values
      prop_def.make_uniq(values)
    end
    memoize :unique_numeric_values_for

    # The 2 methods are copied from Chart, may be we can put it to a module
    def distinct_property_query(property_name)
      prop_column = CardQuery::Column.new(property_name)
      CardQuery.new(:distinct => true, :columns => [prop_column], :order_by => [prop_column])
    end
  end

  class << self

    def format_labels(values, x_axis_property_def)
      values = restrict_to_real_values_with_highest_precision(values, x_axis_property_def)
      convert_to_string_format_with_consistent_comparison(values)
    end


    def restrict_to_real_values_with_highest_precision(values, x_axis_property_def)
      RestrictWithPrecision.new(values, x_axis_property_def).perform
    end

    def format_labels_for_from_tree(from_tree, query_values)
      ids =  query_values.collect{|value| value['id']}
      return [] if ids.empty?
      expanded_card_names = from_tree.expanded_card_names(CardQuery::SqlCondition.new("#{Card.quoted_table_name}.id IN (#{ids.join(',')})"))
      expanded_card_names.values.smart_sort
    end

    def deduce_card_number_and_name_from_expanded_tree_label(x_axis_property_def, values, series_project, x_labels_tree)
      return values if x_labels_tree.blank?

      series_project.with_active_project do |series_project|
        tree_configuration = series_project.find_tree_configuration(x_labels_tree)
        return values unless tree_configuration

        values.collect do |value|
          if node = find_leaf_node(tree_configuration, value.split(" > "))
            "##{node.number} #{node.name}"
          else
            value
          end
        end
      end
    end

    private

    def convert_to_string_format_with_consistent_comparison(values)
      values.map! {|value| value.to_s if value}
    end

    def find_leaf_node(tree_configuration, node_names_path)
      node_names_path.inject(nil) do |parent_node, card_name|
        if node = tree_configuration.find_card_by_parent_node_and_name(parent_node, card_name)
          node
        else
          return nil
        end
      end
    end
  end

end

class StackBarChartXAxisLabelsCardPropertyDefintion < XAxisLabels
  def initialize(x_axis_property_def, params={})
     @labels_query = params[:labels_query]
     super(x_axis_property_def, params)
   end

   private

   def generate_labels
     labels = if @labels_query
      format_labels(@labels_query.values)
     else
       @x_axis_property_def.label_values_for_charting
     end
     XAxisLabelsHelper.format_labels(labels, @x_axis_property_def)
   end

   def format_labels(query_values)
     split_values = Array.new

     query_values.each_with_index do |value, i|
       label = value[@x_axis_property_def.name]
       if(label)
         name = label.match(/\#[0-9]*\s(.*)/)[1]
         split_values[i] = {'Number' => value['number'], 'Name' => name, 'Label' => label}
       else
         split_values[i] = {'Number' => value['number'], 'Name' => nil, 'Label' => nil}
       end
     end

     split_values.smart_sort_by{|value| value['Name']}.collect{|value| value['Label']}
   end
end

class StackBarChartXAxisLabels < XAxisLabels

  def initialize(x_axis_property_def, params={})
    @labels_query = params[:labels_query]
    super(x_axis_property_def, params)
  end

  private

  def generate_labels
    labels = if @labels_query
      @labels_query.single_values
    else
      @x_axis_property_def.label_values_for_charting
    end
    XAxisLabelsHelper.format_labels(labels, @x_axis_property_def)
  end

end

class StackBarChartXAxisLabelsFromTree < XAxisLabels
  def initialize(x_axis_property_def, params={})
    @labels_query = params[:labels_query]
    @from_tree = x_axis_property_def.project.find_tree_configuration(params[:from_tree])
    raise XAxisLabels::Errors.tree_not_found(params[:from_tree], x_axis_property_def.project) if !@from_tree
    super(x_axis_property_def, params)
  end

  def generate_labels
    values = @labels_query.single_values.compact
    return values if values.empty?
    numbers = values.collect do |value|
       /^#(\d*)/.match(value)[1]
    end
    from_tree_condition = "FROM TREE '#{@from_tree.name}' WHERE number IN (#{numbers.join(',')})"
    id_column, number_column, name_column = CardQuery::CardIdColumn.new, CardQuery::Column.new('Number'), CardQuery::Column.new('Name')
    query = CardQuery.new(:columns => [id_column, number_column, name_column])

    query.restrict_with!(from_tree_condition)
    XAxisLabelsHelper.format_labels_for_from_tree(@from_tree, query.values)
  end

  def format_labels(query_values)
    ids =  query_values.collect{|value| value['id']}
    expanded_card_names = @from_tree.expanded_card_names(CardQuery::SqlCondition.new("#{Card.quoted_table_name}.id IN (#{ids.join(',')})"))
    expanded_card_names.values.smart_sort
  end

  def reformat_values_from(options={})
    x_labels_tree = options[:x_labels_tree]
    series_project = options[:series_project]
    labels = options[:labels] || @labels
    XAxisLabelsHelper.deduce_card_number_and_name_from_expanded_tree_label(@x_axis_property_def, @labels, series_project, x_labels_tree)
  end
end

class CardXAxisLabels < XAxisLabels

  def initialize(x_axis_property_def, card_query_options, params={})
    @card_query_options = card_query_options
    @x_labels_conditions = params[:x_labels_conditions]
    super(x_axis_property_def, params)
  end

  private

  def generate_labels
    x_axis_property_def_conditions = if(@x_axis_property_def && @x_axis_property_def.is_a?(TreeRelationshipPropertyDefinition))
      CardQuery::SqlCondition.new(["LOWER(#{Card.quoted_table_name}.card_type_name) = ?", @x_axis_property_def.valid_card_type.name.downcase])
    end

    id_column, number_column, name_column = CardQuery::CardIdColumn.new, CardQuery::Column.new('Number'), CardQuery::Column.new('Name')
    query = CardQuery.new(@card_query_options.merge(:columns => [id_column, number_column, name_column], :conditions => x_axis_property_def_conditions))
    query.restrict_with!(conditions) unless conditions.blank?

    format_labels(query.values)
  end

  def format_labels(query_values)
    query_values.smart_sort_by{|value| value['Name']}.collect{|value| "##{value['Number']} #{value['Name']}"}
  end

  def conditions
    @x_labels_conditions
  end

end

class CardXAxisLabelsFromTree < CardXAxisLabels
  def initialize(x_axis_property_def, card_query_options, params={})
    @from_tree = x_axis_property_def.project.find_tree_configuration(params[:from_tree])
    raise XAxisLabels::Errors.tree_not_found(params[:from_tree], x_axis_property_def.project) if !@from_tree
    super(x_axis_property_def, card_query_options, params)
  end

  def reformat_values_from(options={})
    x_labels_tree = options[:x_labels_tree]
    series_project = options[:series_project]
    labels = options[:labels] || @labels
    XAxisLabelsHelper.deduce_card_number_and_name_from_expanded_tree_label(@x_axis_property_def, labels, series_project, x_labels_tree)
  end

  private

  def conditions
    if @x_labels_conditions.blank?
      "FROM TREE '#{@from_tree.name}'"
    else
      "FROM TREE '#{@from_tree.name}' WHERE #{@x_labels_conditions}"
     end
  end

  def format_labels(query_values)
    XAxisLabelsHelper.format_labels_for_from_tree(@from_tree, query_values)
  end

end
