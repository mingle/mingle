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

class TableMacro < Macro
  parameter :view, :computable => true, :compatible_types => [:string]
  parameter :query
  parameter :project
  parameter :edit_any_number_property


  def self.query_parameter_definitions
    params_to_include = [ "project" ]
    params_to_include << "edit_any_number_property"
    [Macro::ParameterDefinition.new('query', :required => true, :example => "SELECT number, name WHERE condition1 AND condition2")] +
      TableMacro.parameter_definitions.select { |pd| params_to_include.include?(pd.name.to_s) }
  end

  def self.view_parameter_definitions
    [Macro::ParameterDefinition.new('view', :required => true, :example => 'view name')] + TableMacro.parameter_definitions.select { |pd| ['project'].include?(pd.name.to_s) }
  end

  def initialize(*args)
    super
    if view?
      view_name = self.view
      self.view = project.card_list_views.find(:first, :conditions => ["LOWER(name) = LOWER(?)", view_name])
      raise "No such view: #{view_name.bold}" unless self.view
      raise "No such team view: #{view_name.bold}. Only team views can be used with table macro." if self.view.personal?
      raise "Table view is only available to list views. #{view_name.bold} is not a list view." unless self.view.list?
    end

    self.query = if view
      view.as_card_query
    elsif query?
      CardQuery.parse(query, card_query_options)
    else
      raise "Need to specify query or view"
    end

    if edit_any_number_property == true || edit_any_number_property == 'yes'
      self.query.columns << CardQuery::CardIdColumn.new if edit_any_number_property
    elsif edit_any_number_property != false && edit_any_number_property != 'no' && !edit_any_number_property.blank?
      raise "#{'edit-any-number-property'.bold} only accepts boolean (true, false, yes, no) values."
    end
  end

  def can_be_cached?
    self.query.can_be_cached?
  end

  include AsyncMacro

  def generate_data
    tab = ::Builder::XmlMarkup.new(:indent => 2)
    tab.table do
      write_table_header(tab)
      row_count = write_table_body(tab)
      if row_count == MingleConfiguration.macro_records_limit.to_i
        actual_count = query.count
        tab.tr do
          tab.td("Only first #{MingleConfiguration.macro_records_limit} (of #{actual_count}) records loaded.", :class => "too-many-records", 'colspan' => query.columns.size)
        end
      end
    end
  end

  def write_table_header(tab)
    tab.tr do
      query.columns.collect do |column|
        next if column.name == 'id'
        tab.th column.name
      end
    end
  end

  def write_table_body(tab)
    query_values = []
    benchmark = Benchmark.measure do
      query_values = query.values(MingleConfiguration.macro_records_limit.to_i, MingleConfiguration.async_macro_enabled_for?(self.name))
      query_values.each do |record|
        card_url = card_url_for(record) if number_column
        write_row(tab, record, card_url)
      end
    end
    Rails.logger.info("#{self.name} at #{self.macro_position}, Total Table body creation took benchmark : #{benchmark}") if MingleConfiguration.async_macro_enabled_for?(self.name)
    query_values.count
  end

  def tab_index
    key = "table-macro-tab-index"
    ret = ThreadLocalCache.get(key) { 1 }
    ThreadLocalCache.set(key, ret + 1)
    ret
  end

  def write_row(tab, record, card_url=nil)
    tab.tr do
      query.columns.collect do |column|
        next if column.name == 'id'

        value = column.value_from(record).to_s
        if edit_any_number_property
          if column.property_definition.numeric? && !column.property_definition.formulaic? && !column.property_definition.is_managed?
            tab.td(:class => 'inline-edit-number prevent-inline-edit') do
              tab.div(:class => 'inline-any-number-property') do
                tab.input(:type => "text", :value => value, :tabindex => tab_index,
                  :'data-url' => view_helper.url_for(:project_id => project.identifier, :controller => 'cards', :action => 'update_property'),
                  :'data-card-id' => record['id'],
                  :'data-property-name' => column.property_definition.name)
              end
            end
            next
          end
        end

        if value.blank?
          nil_display(column, tab)
        else
          if card_url && should_be_a_link(column)
            tab.td do
              tab.a(:href => card_url) { emit_cell_text(value, tab) }
            end
          elsif card_relationship_column?(column)
            tab.td do
              tab.a(:href => card_url(card_number_from(value))) { emit_cell_text(value, tab) }
            end
          else
            tab.td { emit_cell_text(value, tab) }
          end
        end
      end
    end
  end

  def card_number_from(card_referenced)
    card_referenced.scan(/#\d+/)[0].delete!("#")
  end

  def card_url(card_number)
    view_helper.url_for(:project_id => project.identifier, :controller => 'cards', :action => 'show', :number => card_number)
  end

  def card_relationship_column?(column)
    return if column.nil? || column.property_definition.nil?
    column.property_definition.property_type.is_a?(PropertyType::CardType)
  end

  def number_column
    @number_column ||= query.columns.detect { |c| c.name.downcase == 'number' }
  end

  def card_url_for(record)
    card_number = number_column.value_from(record)
    card_url(card_number)
  end

  def nil_display(column, tab)
    tab.td { tab << ((query.has_aggregated_columns? && !column.is_aggregate?) ? PropertyValue::NOT_SET : '&nbsp;') }
  end

  def emit_cell_text(value, tab)
    tab << (value.escape_html.gsub(/\n/, '<br/>'))
  end

  private

  def should_be_a_link(column)
    column_name = column.name.downcase
    column_name == 'number' || column_name == 'name'
  end

end

Macro.register('table', TableMacro)
