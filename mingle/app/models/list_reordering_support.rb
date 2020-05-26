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

module ListReorderingSupport

  module PropertyDefinitionSupport
    def move_to_correct_position(value, just_created, old_value)
      # For card type definition uses Project.current, the values(project.card_types)
      # may has been cached
      # One scenario is: When updating card type name and remove availabled property,
      # bulk_update_properties will load project's cardtypes, then the card_type
      # name will be setted back when we update its position.
      values.reload if values.respond_to?(:reload)

      others = just_created ? values.reject{|e| e.id == value.id }.collect(&:value) : values.collect{|e| value.id == e.id ? old_value : e.value }
      others.compact!
      if others.smart_sort == others
        reorder(values.smart_sort_by(&:value))
      elsif others.smart_sort == others.reverse
        reorder(values.smart_sort_by(&:value).reverse)
      end
    end

    def backfill_values(original_list, subset_reordered_list)
      backfilled_list = []
      while(!subset_reordered_list.empty?) do
        update_list(original_list, subset_reordered_list, backfilled_list)
      end
      backfilled_list
    end

    def update_list(original_list, subset_reordered_list, backfilled_list)
      original_list.inject(backfilled_list) do |backfilled_list, value|
        if subset_reordered_list.first == value
          subset_reordered_list.shift
          backfilled_list << value
          subset_reordered_list.empty? ? (next backfilled_list) : (return backfilled_list)
        elsif !subset_reordered_list.include?(value) && !backfilled_list.include?(value)
          backfilled_list << value
        end
        backfilled_list
      end
    end

    def reorder(new_order_values, &block)
      # always convert ActiveRecord model to raw data type
      # so that we have consistent data type for algorithms.
      # And ActiveRecord model is slow to do comparasion
      new_order_values, value_id = if block_given?
        [new_order_values, block]
      else
        [new_order_values.map(&:id), lambda {|v| v.id}]
      end
      original_value_list = values.map(&value_id)

      invalid_values = new_order_values.reject { |new_value| original_value_list.include?(new_value) }
      if invalid_values.any?
        self.errors.add("#{pluralize(invalid_values.size, 'column')} to reorder '#{invalid_values.join(', ')}'")
        return
      end

      new_order_values = backfill_values(original_value_list, new_order_values.dup)
      values.each do |value|
        new_position = new_order_values.index(value_id[value]) + 1
        if value.position != new_position
          value.update_attributes(:position => new_position, :nature_reorder_disabled => true)
        end
      end
    end
  end

  module EnumerationValueSupport
    def save_with_reorder_values(validate = true)
      just_created = new_record?
      save_without_reorder_values(validate).tap do |result|
        property_definition.move_to_correct_position(self, just_created, @old_value) if valid? && !nature_reorder_disabled
      end
    end

    def save_with_reorder_values!
      just_created = new_record?
      save_without_reorder_values!.tap do |result|
        property_definition.move_to_correct_position(self, just_created, @old_value) if !nature_reorder_disabled
      end
    end
  end
end
