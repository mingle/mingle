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

# a collection of property_value which are in correct order for ui showing and updating card
class PropertyValueCollection
  include Enumerable

  class << self
    def from_params(project, params, options={})
      values = params.inject([]) do |ret, (property_name, value)|
        if prop_def = project.find_property_definition_including_card_type_def(property_name, :with_hidden => options[:include_hidden])
          next ret if prop_def.calculated?
          input_value = value.respond_to?(:trim) ? value.trim : value
          input_value = prop_def.project.format_date(input_value) if prop_def.date? && input_value.kind_of?(Time)
          ret << if options[:method] == 'get'
            prop_def.property_value_from_url(input_value)
          else
            prop_def.property_value_from_db(input_value)
          end
        end
        ret
      end
      new(values)
    end
  end

  def initialize(values)
    @values = values
    sort_by_position!
  end

  def assign_to(card, options={})
    @values.each do |property_value|
      property_value.assign_to(card, options)
    end
  end

  def each(&block)
    @values.each(&block)
  end

  def values
    @values.dup
  end

  def to_post_params
    inject({}) do |params, property_value|
      params[property_value.name] = property_value.db_identifier
      params
    end
  end

  def to_get_params
    inject({}) do |params, property_value|
      params[property_value.name] = property_value.url_identifier
      params
    end
  end

  def names
    @values.collect(&:name)
  end

  def reject(&block)
    self.class.new(@values.reject(&block))
  end

  def empty?
    @values.empty?
  end

  def <<(value)
    @values << value
    sort_by_position!
  end

  def size
    @values.size
  end

  def first
    @values.first
  end

  def delete!(value)
    @values.delete(value)
  end

  def length
    @values.length
  end

  def values_at(*args)
    args.map { |arg| @values.values_at(arg) }.flatten
  end

  private
  def sort_by_position!
    @values = @values.sort_by {|value| value.property_definition.position || 0 }
  end
end
