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

class M96Card < ActiveRecord::Base
  belongs_to :project, :class_name => 'M96Project', :foreign_key => 'project_id'
end

class M96TransitionPrerequisite < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transition_prerequisites"
end

class M96TransitionAction < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transition_actions"
end

class M96PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm96_type' #disable single table inheretance
  belongs_to :project, :class_name => "M96Project", :foreign_key => "project_id"
end

class M96EnumerationValue < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}enumeration_values"
end

class M96CardDefaults < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_defaults"
end

class M96Transition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}transitions"
end

class M96PropertyValue
  IGNORED_IDENTIFIER = ':ignore' unless defined?(IGNORED_IDENTIFIER)
end

class M96Filter
  
  ENCODED_FORM = /^\[([^\]]*?)\]\[([^\]]*?)\]\[(.*?)\]$/ unless defined?(ENCODED_FORM)
  
  attr_reader :operator, :value, :project, :property_definition_name, :property_definition
  attr_writer :value
  
  def initialize(project, filter_parameter)
    @project = project
    filter_parameter =~ ENCODED_FORM
    raise "Invalid filter parameter: #{filter_parameter.bold}" unless $& 
    @property_definition_name, @value = $1, $3
    @property_definition = project.find_property_definition_or_nil(@property_definition_name)
    @property_definition_name = @property_definition.name if @property_definition
  end
  
  def value
    @value #unless (card_type_filter? && ignored?)
  end
  
  def ignored?
    @value == M96PropertyValue::IGNORED_IDENTIFIER
  end
  
end

class M96Filters
  include Enumerable
  
  attr_accessor :project
  
  def initialize(project, filter_strings)
    self.project = project
    filter_strings.compact.collect { |filter_string| read_filter_string(filter_string) }
    filters.reject!(&:ignored?)
  end
  
  def each(&block)
    filters.each(&block)
  end
  
  def size
    filters.size
  end
  
  def using_numeric_property_definition
    select { |filter| filter.property_definition.numeric? }
  end
  
  private
  
  def filters
    @filters ||= []
  end
  
  def read_filter_string(filter_string)
    filter = M96Filter.new(project, filter_string)
    filters << filter
    undefined_filters << filter if !filter.property_definition_name.blank? && filter.property_definition.nil?
  end
  
  def undefined_filters
    @undefined_filters ||= []
  end

end

class M96CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  
  belongs_to :project, :class_name => "M96Project", :foreign_key => "project_id"
  serialize :params
  
  attr_accessor :filters
  
  def after_find
    load_from_params(self.params)
  end
  
  def load_from_params(parameters)
    @filters = M96Filters.new(project, parameters[:filters] || [])
  end
end

class M96FormulaPropertyDefinition < M96PropertyDefinition
end

class M96AggregatePropertyDefinition < M96PropertyDefinition
end

class M96Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  
  has_many :card_list_views, :order => "#{MigrationHelper.safe_table_name('card_list_views')}.name", :class_name => "M96CardListView", :foreign_key => "project_id"
  has_many :history_subscriptions, :foreign_key => "project_id"
  has_many :numeric_list_property_definitions_with_hidden, :conditions => ["#{MigrationHelper.safe_table_name('property_definitions')}.type = ? AND #{MigrationHelper.safe_table_name('property_definitions')}.is_numeric = ?", 'EnumeratedPropertyDefinition', true], :class_name => 'M96PropertyDefinition', :foreign_key => "project_id"
  has_many :numeric_free_property_definitions_with_hidden, :conditions => ["#{MigrationHelper.safe_table_name('property_definitions')}.type = ? AND #{MigrationHelper.safe_table_name('property_definitions')}.is_numeric = ?", 'TextPropertyDefinition', true], :class_name => 'M96PropertyDefinition', :foreign_key => "project_id"
  has_many :property_definitions_with_hidden, :order => "#{MigrationHelper.safe_table_name('property_definitions')}.name", :class_name => 'M96PropertyDefinition', :foreign_key => "project_id"
  has_many :property_definitions, :order => "#{MigrationHelper.safe_table_name('property_definitions')}.name", :conditions => {:hidden => false}, :class_name => "M96PropertyDefinition", :foreign_key => "project_id"
  has_many :formula_property_definitions_with_hidden, :conditions => ["#{MigrationHelper.safe_table_name('property_definitions')}.type = ?", 'FormulaPropertyDefinition'], :class_name => 'M96FormulaPropertyDefinition', :foreign_key => "project_id"
  has_many :aggregate_property_definitions_with_hidden, :conditions => ["#{MigrationHelper.safe_table_name('property_definitions')}.type = ?", 'AggregatePropertyDefinition'], :class_name => 'M96AggregatePropertyDefinition', :foreign_key => "project_id"
    
  def find_property_definition_or_nil(property_name, options={})
    return nil if property_name.nil?
    return property_name if property_name.kind_of?(PropertyDefinition)
    property_name = property_name.to_s
    candidates = options[:with_hidden] ? property_definitions_with_hidden : property_definitions
    candidates.detect { |definition| definition.name.downcase == property_name.to_s.downcase.trim }
  end
  
  cattr_accessor :current
  def activate
    @@current = self
    M96Card.set_table_name "#{ActiveRecord::Base.table_name_prefix}#{identifier}_cards"
    M96Card.reset_column_information
  end

  def deactivate
    M96Card.set_table_name nil
    @@current = nil
  end

  def with_active_project
    previous_active_project = @@current
    begin
      if previous_active_project
        previous_active_project.deactivate
      end
      activate
      yield(self)
    ensure
      deactivate
      if previous_active_project
        previous_active_project.activate
      end
    end
  end
end

class M96HistorySubscription < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}history_subscriptions"
  
  def to_history_filter_params
    @history_filter_params ||= M96HistoryFilterParams.new(self.filter_params)
  end
  
  def filter_property_names
    names = []
    names << to_history_filter_params.involved_filter_properties.keys if to_history_filter_params.involved_filter_properties
    names << to_history_filter_params.acquired_filter_properties.keys if to_history_filter_params.acquired_filter_properties
    names.flatten.uniq
  end
  
  def rename_property(original_name, new_name)
    ["acquired_filter_properties", "involved_filter_properties"].each {|filter_properties| self.filter_params.gsub!("#{filter_properties}[#{original_name}]", "#{filter_properties}[#{new_name}]")}
  end
  
  def rename_property_value(property_definition_name, original_value, new_value)
    params = to_history_filter_params
    params.rename_property_value property_definition_name, original_value, new_value
    self.filter_params = params.serialize
  end
  
  # optimization
  def project
    return Project.current
  end  
end

class String
  def to_num(precision = nil)
    is_integer = (self.to_i == self.to_f)
    if is_integer
      self.to_i 
    else
      return self.to_f.round_to(precision) if precision
      self.to_f
    end  
  end
  
  def to_num_maintain_precision(precision)
    return self if self.nil? || self.blank? || !self.numeric?
    original_precision = self =~ /\.(\d*)$/ ? $1.length : 0
    result = self =~ /(\.\d{#{precision + 1},})|(\.$)/ ? self.to_num(precision).to_s : self
    final_precision = (original_precision >= precision) ? precision : original_precision
    sprintf("%.#{final_precision}f", result)
  end
end

class M96HistoryFilterParams
  PARAM_KEYS = ['involved_filter_tags', 'acquired_filter_tags', 'involved_filter_properties', 'acquired_filter_properties', 'filter_user', 'filter_types', 'card_number', 'page_identifier'] unless defined?(PARAM_KEYS)
  
  def initialize(params={}, period=nil)
    @params = if params.blank?
      @params = {} 
    else
      params.is_a?(String) ? parse_str_params(params) : parse_hash_params(params)
    end
    @params.merge!(:period => period) if period
  end
  
  def serialize
    ActionController::Routing::Route.new.build_query_string(@params)[1..-1]
  end
  
  def involved_filter_properties
    retrieve_filter_properties 'involved_filter_properties'
  end
  
  def acquired_filter_properties
    retrieve_filter_properties 'acquired_filter_properties'
  end
  
  def rename_property_value(property_definition_name, original_value, new_value)
    rename_property_value_for_filter_property('involved_filter_properties', property_definition_name, original_value, new_value)
    rename_property_value_for_filter_property('acquired_filter_properties', property_definition_name, original_value, new_value)
  end
  
  private
  
  def rename_property_value_for_filter_property(filter_property, property_definition_name, original_value, new_value)
    return unless @params[filter_property]
    if (@params[filter_property][property_definition_name] == original_value)
      @params[filter_property][property_definition_name] = new_value
    end
  end
  
  def retrieve_filter_properties(filter_property)
    return unless @params[filter_property]
    sanitized_values = @params[filter_property].collect do |key, value|
      [key, (value || '')]
    end
    Hash[*sanitized_values.flatten]
  end
  
  def parse_str_params(params)
    parse_hash_params(ActionController::Request.parse_query_parameters(params))
  end
  
  def parse_hash_params(params)
    params.reject! { |key, value| value.blank? }
    PARAM_KEYS.inject({}) do |result, key|
      value = params[key] || params[key.to_sym]
      value.reject_all!(M96PropertyValue::IGNORED_IDENTIFIER) if value.respond_to?(:reject_all!)
      result[key] = value unless value.blank?
      result
    end
  end
end

class M96PrecisionChange
  include SqlHelper, SecureRandomHelper
  
  def self.create_change(project, old_value, new_value)
    if new_value > old_value
      M96PrecisionChange::Increase.new(project, old_value, new_value)
    else
      M96PrecisionChange::Decrease.new(project, old_value, new_value)
    end
  end

  def initialize(project, old_value, new_value)
    @project, @old_precision, @new_precision = project, old_value, new_value
  end
  
  def run
    update_cards
    update_transitions
    update_card_defaults
    delete_aliased_managed_numeric_values
    adjust_card_list_views
    adjust_history_subscriptions
    update_precision_of_calculated_numbers
  end
  
  private
  
  def update_precision_of_calculated_numbers
    set_conditions = all_calculated_property_definitions.inject([]) do |result, calculated_property_definition|
      next result unless calculated_property_definition.numeric?
      result << "#{calculated_property_definition.column_name} = #{as_number calculated_property_definition.column_name, @new_precision}"
      result
    end
    execute("UPDATE #{M96Card.quoted_table_name} SET #{set_conditions.join(', ')}") unless set_conditions.empty?
  end
  
  def all_calculated_property_definitions
    @project.formula_property_definitions_with_hidden + @project.aggregate_property_definitions_with_hidden
  end  
  
end

class M96PrecisionChange::Increase < M96PrecisionChange
  
  private
  
  def update_transitions; end
  
  def update_cards; end
  
  def delete_aliased_managed_numeric_values; end
  
  def adjust_card_list_views; end
  
  def adjust_history_subscriptions; end
  
  def update_card_defaults; end
  
end

class M96PrecisionChange::Decrease < M96PrecisionChange
  
  private
  
  def update_cards
    (@project.numeric_list_property_definitions_with_hidden + @project.numeric_free_property_definitions_with_hidden).each do |prop_def|
      execute %{ UPDATE #{M96Card.quoted_table_name} SET #{quote_column_name prop_def.column_name} = #{as_number quote_column_name(prop_def.column_name), @new_precision}
                 WHERE #{connection.value_out_of_precision(prop_def.column_name, @new_precision)} }
    end
  end
  
  def update_transitions
    prereqs_to_update = "tt" + random_32_char_hex
    actions_to_update = "tt" + random_32_char_hex
    
    begin
      connection.create_table(prereqs_to_update) {}
      connection.create_table(actions_to_update) {}
      
      execute sanitize_sql(%{
        INSERT INTO #{quote_table_name(prereqs_to_update)}
          (SELECT tp.id FROM #{M96TransitionPrerequisite.quoted_table_name} tp
          JOIN #{M96PropertyDefinition.quoted_table_name} pd ON (pd.id = tp.property_definition_id AND 
              pd.type IN ('EnumeratedPropertyDefinition', 'TextPropertyDefinition')) AND 
              pd.is_numeric = ?
          JOIN #{M96Transition.quoted_table_name} t ON (t.id = tp.transition_id)
          WHERE t.project_id = #{@project.id} AND #{connection.value_out_of_precision("tp.value", @new_precision)})
      }, true) 
      
      execute sanitize_sql(%{
        INSERT INTO #{quote_table_name(actions_to_update)}
          (SELECT ta.id FROM #{M96TransitionAction.quoted_table_name} ta
          JOIN #{M96PropertyDefinition.quoted_table_name} pd ON (pd.id = ta.property_definition_id AND
              pd.type IN ('EnumeratedPropertyDefinition', 'TextPropertyDefinition')) AND
              pd.is_numeric = ?
          JOIN #{M96Transition.quoted_table_name} t ON (t.id = ta.executor_id)
          WHERE t.project_id = #{@project.id} AND ta.executor_type = 'Transition' AND #{connection.value_out_of_precision("ta.value", @new_precision)})
      }, true)
      
      execute %{
        UPDATE #{M96TransitionPrerequisite.quoted_table_name} SET value = #{as_number('value', @new_precision)}
        WHERE #{M96TransitionPrerequisite.quoted_table_name}.id IN (SELECT #{quote_table_name(prereqs_to_update)}.id FROM #{quote_table_name(prereqs_to_update)})
      }
      
      execute %{
        UPDATE #{M96TransitionAction.quoted_table_name} SET value = #{as_number('value', @new_precision)}
        WHERE #{M96TransitionAction.quoted_table_name}.id IN (SELECT #{quote_table_name(actions_to_update)}.id FROM #{quote_table_name(actions_to_update)})
      }
      
    ensure
      connection.drop_table(prereqs_to_update)
      connection.drop_table(actions_to_update)
    end
  end
  
  def update_card_defaults
    defaults_to_update = "tt" + random_32_char_hex
    
    begin
      connection.create_table(defaults_to_update) {}
      
      execute sanitize_sql(%{
        INSERT INTO #{quote_table_name(defaults_to_update)}
          (SELECT ta.id FROM #{M96TransitionAction.quoted_table_name} ta
          JOIN #{M96PropertyDefinition.quoted_table_name} pd ON (pd.id = ta.property_definition_id AND
              pd.type IN ('EnumeratedPropertyDefinition', 'TextPropertyDefinition')) AND
              pd.is_numeric = ?
          JOIN #{M96CardDefaults.quoted_table_name} cd ON (cd.id = ta.executor_id)
          WHERE cd.project_id = #{@project.id} AND ta.executor_type = 'CardDefaults' AND #{connection.value_out_of_precision("ta.value", @new_precision)})
      }, true)
      
      execute %{
        UPDATE #{M96TransitionAction.quoted_table_name} SET value = #{as_number('value', @new_precision)}
        WHERE #{M96TransitionAction.quoted_table_name}.id IN (SELECT #{quote_table_name(defaults_to_update)}.id FROM #{quote_table_name(defaults_to_update)})
      }
    ensure
      connection.drop_table(defaults_to_update)
    end
  end
  
  def delete_aliased_managed_numeric_values
    @project.numeric_list_property_definitions_with_hidden.each do |property_definition|
      
      rows = select_all_rows %{
        SELECT #{as_number('ev.value', @new_precision)} AS value, MIN(ev.position) AS position, COUNT(*) AS alias_count FROM #{M96EnumerationValue.quoted_table_name} ev
        WHERE ev.property_definition_id = #{property_definition.id}
        GROUP BY #{as_number('ev.value', @new_precision)}
        ORDER BY position
      }
      
      rows = rows.each_with_index { |row, index| row['position'] = index + 1 }

      rows.each do |row|
        if row['alias_count'].to_i > 1
          recreate_new_managed_value(row, property_definition)
        else
          update_existing_managed_value(row, property_definition)
        end
      end
    end
  end
  
  def recreate_new_managed_value(row, property_definition)
    ids_to_delete = "tt" + random_32_char_hex
    
    begin
      connection.create_table(ids_to_delete) {}
      
      execute %{
        INSERT INTO #{quote_table_name(ids_to_delete)}
          (SELECT ev.id FROM #{M96EnumerationValue.quoted_table_name} ev
           WHERE ev.property_definition_id = #{property_definition.id} AND
                 #{number_comparison_sql('ev.value', '=', row['value'], @new_precision)})
      }
      
      values = select_all_rows(%{
        SELECT value FROM #{M96EnumerationValue.quoted_table_name} ev
        WHERE ev.id IN (SELECT id FROM #{quote_table_name(ids_to_delete)})
      }).collect { |value_row| value_row['value'] }.sort
      
      execute %{
        DELETE FROM #{M96EnumerationValue.quoted_table_name}
        WHERE id IN (SELECT id FROM #{quote_table_name(ids_to_delete)})
      }
      
      new_value = values.first.to_num_maintain_precision(@new_precision)
      
      execute %{
        INSERT INTO #{M96EnumerationValue.quoted_table_name} (value, position, property_definition_id) 
        VALUES (#{new_value}, #{row['position']}, #{property_definition.id})
      }
      
      set_appropriate_card_values_to(property_definition, new_value)
    ensure
      connection.drop_table(ids_to_delete)
    end
  end
  
  def set_appropriate_card_values_to(property_definition, value)
    execute %{
      UPDATE #{M96Card.quoted_table_name}
      SET #{quote_column_name property_definition.column_name} = '#{value}'
      WHERE #{number_comparison_sql(quote_column_name(property_definition.column_name), '=', connection.quote(value))}
    }
  end
  
  def update_existing_managed_value(row, property_definition)
    execute %{
      UPDATE #{M96EnumerationValue.quoted_table_name} SET
      value = #{as_number(connection.quote(row['value']), @new_precision)}, 
      position = #{row['position']}
      WHERE property_definition_id = #{property_definition.id} AND
            #{number_comparison_sql('value', '=', connection.quote(row['value']), @new_precision)} AND
            #{connection.value_out_of_precision('value', @new_precision)}
    }
    
    execute %{
      UPDATE #{M96EnumerationValue.quoted_table_name} SET
      position = #{row['position']}
      WHERE property_definition_id = #{property_definition.id} AND
            #{number_comparison_sql('value', '=', row['value'], @new_precision)}
    }
  end
  
  def adjust_card_list_views
    @project.card_list_views.select { |view| view.filters.size > 0 }.each do |view|
      view.params[:filters] = view.params[:filters].collect do |filter_string|
        new_filter_string = filter_string.gsub(/\[(.*)\]\[(.*)\]\[(.*)\]/) do |match|
          property_definition_name = $1
          old_value = $3
          prop_def = @project.find_property_definition_or_nil(property_definition_name, :with_hidden => true)
          return match unless prop_def && prop_def.is_numeric
          "[#{$1}][#{$2}][#{old_value.to_num_maintain_precision(@new_precision)}]"
        end
        new_filter_string ? new_filter_string : filter_string
      end
      view.save
    end
  end
  
  def adjust_history_subscriptions
    @project.history_subscriptions.select { |subscription| subscription.filter_property_names.size > 0 }.each do |subscription|
      history_filter_params = subscription.to_history_filter_params
      
      subscription.filter_property_names.each do |prop_name|
        prop_def = @project.find_property_definition_or_nil(prop_name, :with_hidden => true)
        next unless prop_def && prop_def.numeric?
        if history_filter_params.involved_filter_properties && history_filter_params.involved_filter_properties[prop_name]
          value = history_filter_params.involved_filter_properties[prop_name]
          subscription.rename_property_value(prop_name, value, value.to_num_maintain_precision(@new_precision).to_s)
        end
        if history_filter_params.acquired_filter_properties && history_filter_params.acquired_filter_properties[prop_name]
          value = history_filter_params.acquired_filter_properties[prop_name]
          subscription.rename_property_value(prop_name, value, value.to_num_maintain_precision(@new_precision).to_s)
        end
      end
      
      subscription.save
    end
  end
end

class DuplicateEnumerationValuesRemover
  include SecureRandomHelper, SqlHelper
  
  def initialize(project, property_definition)
    @project = project
    @property_definition = property_definition
    @new_precision = 10
  end
  
  def run
    delete_aliased_managed_numeric_values(@property_definition)
  end
  
  private
  
  def delete_aliased_managed_numeric_values(property_definition)
    rows = select_all_rows %{
      SELECT #{as_number 'ev.value', @new_precision} AS value, MIN(ev.position) AS position, COUNT(*) AS alias_count FROM #{M96EnumerationValue.quoted_table_name} ev
      WHERE ev.property_definition_id = #{property_definition.id}
      GROUP BY #{as_number 'ev.value', @new_precision}
      ORDER BY position
    }
    
    rows = rows.each_with_index { |row, index| row['position'] = index + 1 }
    
    rows.each do |row|
      if row['alias_count'].to_i > 1
        recreate_new_managed_value(row, property_definition)
      else
        update_existing_managed_value(row, property_definition)
      end
    end
  end
  
  def recreate_new_managed_value(row, property_definition)
    ids_to_delete = "tt" + random_32_char_hex
    
    begin
      connection.create_table(ids_to_delete) {}
      
      execute %{
        INSERT INTO #{quote_table_name(ids_to_delete)}
          (SELECT ev.id FROM #{M96EnumerationValue.quoted_table_name} ev
           WHERE ev.property_definition_id = #{property_definition.id} AND
                 #{number_comparison_sql('ev.value', '=', row['value'], @new_precision)}
      }
      
      values = connection.select_all(%{
        SELECT value FROM #{M96EnumerationValue.quoted_table_name} ev
        WHERE ev.id IN (SELECT id FROM #{quote_table_name(ids_to_delete)})
      }).collect { |value_row| value_row['value'] }.sort
      
      execute %{
        DELETE FROM #{M96EnumerationValue.quoted_table_name}
        WHERE id IN (SELECT id FROM #{quote_table_name(ids_to_delete)})
      }
      
      new_value = values.first.to_num_maintain_precision(@new_precision)
      
      execute %{
        INSERT INTO #{M96EnumerationValue.quoted_table_name} (value, position, property_definition_id) 
        VALUES (#{new_value}, #{row['position']}, #{property_definition.id})
      }
      
      set_appropriate_card_values_to(property_definition, new_value)
      update_transitions(property_definition, new_value)
      adjust_card_list_views(property_definition, new_value)
      adjust_history_subscriptions(property_definition, new_value)
    ensure
      connection.drop_table(ids_to_delete)
    end
  end
  
  def set_appropriate_card_values_to(property_definition, value)
    execute %{
      UPDATE #{M96Card.quoted_table_name}
      SET #{quote_column_name(property_definition.column_name)} = '#{value}'
      WHERE #{number_comparison_sql(quote_column_name(property_definition.column_name), '=', connection.quote(value))}
    }
  end
  
  def update_existing_managed_value(row, property_definition)
    execute %{
      UPDATE #{M96EnumerationValue.quoted_table_name} SET
      value = #{as_number(connection.quote(row['value']), @new_precision )},
      position = #{row['position']}
      WHERE property_definition_id = #{property_definition.id} AND
      #{number_comparison_sql('value', '=', row['value'], @new_precision)} AND
      #{property_definition.connection.value_out_of_precision('value', @new_precision)}
    }
    
    execute %{
      UPDATE #{M96EnumerationValue.quoted_table_name} SET
      position = #{row['position']}
      WHERE property_definition_id = #{property_definition.id} AND
      #{number_comparison_sql('value', '=', row['value'], @new_precision)}
    }
  end
  
  def update_transitions(property_definition, new_value)
    prereqs_to_update = "tt" + random_32_char_hex
    actions_to_update = "tt" + random_32_char_hex

    begin
      connection.create_table(prereqs_to_update) {}
      connection.create_table(actions_to_update) {}

      execute %{
        INSERT INTO #{quoted_table_name(prereqs_to_update)}
          (SELECT tp.id FROM #{M96TransitionPrerequisite.quoted_table_name} tp
          JOIN #{M96Transition.quoted_table_name} t ON (t.id = tp.transition_id)
          WHERE t.project_id = #{@project.id} AND tp.property_definition_id = #{property_definition.id} AND 
          #{number_comparison_sql('tp.value', '=', new_value)}
      }

      execute %{
        INSERT INTO #{quoted_table_name(actions_to_update)}
          (SELECT ta.id FROM #{M96TransitionAction.quoted_table_name} ta
          JOIN #{M96Transition.quoted_table_name} t ON (t.id = ta.executor_id)
          WHERE t.project_id = #{@project.id} AND ta.property_definition_id = #{property_definition.id} AND ta.executor_type = 'Transition' AND #{number_comparison_sql('ta.value', '=', new_value)})
      }

      execute %{
        UPDATE #{M96TransitionPrerequisite.quoted_table_name} SET value = '#{new_value}'
        WHERE #{M96TransitionPrerequisite.quoted_table_name}.id IN (SELECT #{quote_table_name(prereqs_to_update)}.id FROM #{quote_table_name(prereqs_to_update)})
      }

      execute %{
        UPDATE #{M96TransitionAction.quoted_table_name} SET value = '#{new_value}'
        WHERE #{M96TransitionAction.quoted_table_name}.id IN (SELECT #{quoted_table_name(actions_to_update)}.id FROM #{quoted_table_name(actions_to_update)})
      }

    ensure
      connection.drop_table(prereqs_to_update)
      connection.drop_table(actions_to_update)
    end
  end
  
  def adjust_card_list_views(property_definition, new_value)
    @project.card_list_views.select { |view| view.filters.size > 0 }.each do |view|
      view.params[:filters] = view.params[:filters].collect do |filter_string|
        new_filter_string = filter_string.gsub(/\[#{property_definition.name}\]\[(.*)\]\[(.*)\]/) do |match|
          $2.to_num == new_value.to_num ? "[#{property_definition.name}][#{$1}][#{new_value}]" : match
        end
        new_filter_string ? new_filter_string : filter_string
      end
      view.save
    end
  end
  
  def adjust_history_subscriptions(property_definition, new_value)
    @project.history_subscriptions.select { |subscription| subscription.filter_property_names.size > 0 }.each do |subscription|
      history_filter_params = subscription.to_history_filter_params
      
      subscription.filter_property_names.each do |prop_name|
        next unless prop_name.downcase == property_definition.name.downcase
        if history_filter_params.involved_filter_properties && history_filter_params.involved_filter_properties[prop_name]
          value = history_filter_params.involved_filter_properties[prop_name]
          subscription.rename_property_value(prop_name, value, new_value) if value.to_num == new_value.to_num
        end
        if history_filter_params.acquired_filter_properties && history_filter_params.acquired_filter_properties[prop_name]
          value = history_filter_params.acquired_filter_properties[prop_name]
          subscription.rename_property_value(prop_name, value, new_value) if value.to_num == new_value.to_num
        end
      end
      
      subscription.save
    end
  end
  
end


class UpdatePrecisionForExistingProjects < ActiveRecord::Migration
  def self.up
    execute("UPDATE #{safe_table_name('projects')} SET #{quote_column_name('precision')} = 10")

    M96Project.find(:all).each do |project|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_cards")
      project.with_active_project do |project|
        project.numeric_list_property_definitions_with_hidden.each do |prop_def|
          DuplicateEnumerationValuesRemover.new(project, prop_def).run
        end
        M96PrecisionChange::Decrease.new(project, 10, 10).run
      end
    end
  end

  def self.down
  end
end
