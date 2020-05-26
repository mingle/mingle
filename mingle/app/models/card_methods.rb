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

module CardMethods
  alias_attribute :modified_on, :updated_at
  alias_attribute :created_on, :created_at

  def api_attributes
    attributes.except("has_macros")
  end

  def card_type
    project.find_card_type_or_nil(self.card_type_name) unless self.card_type_name.blank?
  end

  memoize :card_type

  def card_type_id
    card_type.id
  end

  def caching_stamp
    CardCachingStamp.stamp(self.id)
  end

  def property_definitions
    #ordered by position
    card_type.property_definitions
  end

  def user_property_definitions
    property_definitions.select{|pd| pd.is_a?(UserPropertyDefinition)}
  end

  def property_definitions_with_hidden
    card_type.property_definitions_with_hidden_without_order
  end

  def property_definitions_in_smart_order
    property_definitions.smart_sort_by(&:name)
  end

  def available_tree_configurations
    card_type.tree_configurations
  end

  def short_description
    "#{card_type.name} #{number_and_name}"
  end

  def number_and_name
    "##{number} #{name}"
  end

  def type_and_number
    "#{card_type.name} ##{number}"
  end

  def prefixed_number
    "##{number}"
  end
  alias_method :export_dir, :prefixed_number

  def content
    description
  end

  def content=(value)
    self.description = value
  end

  def content_changed?
    description_changed?
  end

  def description_length
    description.nil? ? 0 : description.length
  end

  def property_definitions_with_value(options = {:with_hidden => true})
    project.property_definitions_in_smart_order(options[:with_hidden]).select { |prop_def| property_value(prop_def).set? }
  end

  def properties_with_value
    property_values.reject { |property_value| property_value.not_set? }
  end

  def user_properties
    @user_properties ||= property_values(user_property_definitions).to_a
  end

  def property_values(pds=property_definitions)
    values = pds.collect { |prop_def| property_value(prop_def) }
    PropertyValueCollection.new(values)
  end

  def property_values_with_hidden
    values = property_definitions_with_hidden.collect { |prop_def| property_value(prop_def) }
    PropertyValueCollection.new(values)
  end

  alias_method :properties, :property_values

  def display_value(prop_def)
    property_value(prop_def).display_value
  end

  def property_value(prop_def)
    prop_def = project.find_property_definition(prop_def) if prop_def.is_a?(String)
    prop_def.property_value_on(self)
  end

  def to_s
    "#{self.class}[number => #{number}, name => #{name}, version => #{version}, project_id => #{project_id}, :id => #{id}]"
  end

  def this_card_condition_availability
    new_record? ? ThisCardConditionAvailability::Later.new(self) : ThisCardConditionAvailability::Now.new(self)
  end

  def this_card_condition_error_message(usage)
    "Macros using #{usage.bold} will be rendered when card is saved."
  end

  def method_missing(method_id, *args)
    method_name = method_id.to_s

    # should never call these cp_xxx methods in production, used a lot inside our tests
    if method_name =~ /^(cp_[^=]+)=?$/
      pd_ruby_name = $1
      prop_def = project.property_definitions_with_hidden.detect { |pd| pd.ruby_name.ignore_case_equal?(pd_ruby_name) ||
          pd.column_name.ignore_case_equal?(pd_ruby_name) }
      raise "Couldn't find property definition by column/ruby name '#{pd_ruby_name}' in #{self}" unless prop_def
      # use property definitions for association read/write
      # # for AssociationPropertyDefinition's subclasses
      # We shouldn't really move this method to test
      # since we wouldn't uncover situations in the production code that call these card properties in tests.
      #   ar base ext
      #   asts as versioned
      # things also get more complex on Oracle, because we can't check column name by =~ /_id$/ to find out
      # we want the association id or the association object
      if prop_def.is_a?(AssociationPropertyDefinition) && prop_def.ruby_name.ignore_case_equal?(pd_ruby_name)
        return method_name =~ /=$/ ? prop_def.update_card_by_obj(self, args.first) : prop_def.value(self)
      else
        return method_name =~ /=$/ ? write_attribute(pd_ruby_name, *args) : read_attribute(pd_ruby_name)
      end
    end
    super

  end
end
