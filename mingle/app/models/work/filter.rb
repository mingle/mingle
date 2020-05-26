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

class Work

  class Filter < Struct.new(:attribute, :op, :value)
    class NamedFilters < Struct.new(:attr_name, :filters)
      def self.collect(filters)
        Filter.group_by(:attribute, filters).collect {|attr_name, filters| NamedFilters.new(attr_name, filters)}
      end

      def append_finder(finder)
        finder.send("filter_by_#{attr_name}", *convert_filters_to_finder_conditions)
      end

      def valid?
        ['objective', 'project', 'status'].include?(attr_name)
      end

      private
      def convert_filters_to_finder_conditions
        grouped_filters = Filter.group_by(:op, filters)
        in_cond = grouped_filters['is'].collect(&:db_identifier)
        out_cond = grouped_filters['is not'].collect(&:db_identifier)
        [in_cond, out_cond]
      end
    end

    module Filters
      def apply(finder)
        NamedFilters.collect(self).select(&:valid?).inject(finder) do |finder, named_filters|
          named_filters.append_finder(finder)
        end
      end
    end

    ENCODED_FORM = /^\[([^\]]*?)\]\[([^\]]*?)\]\[(.*?)\]$/
    IGNORED_FILTER_VALUE = ':ignore'
    FILTER_VALUE_MAP = {'status' => {'done' => true, 'not done' => false}}

    class <<self
      # the encode result is an Array, sorted, so that it's easier for test in cruby and jruby.
      # it's not a perfect reason to sort it because of test, but the filters are a very small set,
      # so it really does not matter to sort it.
      def encode(filters)
        filters.map do |key, value|
          op, value = value.is_a?(Array) ? value : ['is', value]
          "[%s][%s][%s]" % [key, op, url_identifier(value)]
        end.sort
      end

      def decode(filters)
        (filters || []).collect { |filter| filter =~ ENCODED_FORM ? self.new($1.to_s.downcase, $2.to_s.downcase, $3.to_s.downcase) : nil }.compact.reject(&:ignored?).extend(Filters)
      end

      def group_by(name, filters)
        filters.inject(Hash.new {|hash, key| hash[key] = []}) do |map, filter|
          map[filter[name]] << filter
          map
        end
      end

      def filter_attributes(plan)
        commons = {'operators' => [['is', 'is'], ['is not', 'is not']], 'appendedActions' => [], 'options' => {}}
        [
          commons.merge({
            'name' => 'Project',
            'tooltip' => 'Project',
            'nameValuePairs' => plan.program.projects.smart_sort_by(&:name).collect { |project| [project.name, project.name] }
          }),
          commons.merge({
            'name' => 'Status',
            'tooltip' => 'Status',
            'nameValuePairs' => [['Done', 'done'], ['Not Done', 'not done'], ['("Done" status not defined for project)', 'not mapped']],
          })
        ]
      end
      
      protected
      
      def url_identifier(value)
        value.respond_to?(:name) ? value.name : value
      end
    end

    def ignored?
      value == IGNORED_FILTER_VALUE
    end

    def to_filter_hash
      {
        :property => self.attribute,
        :operator => self.op,
        :value => self.value,
        :valueValue => [self.value, self.value]
      }
    end

    def db_identifier
      if map = FILTER_VALUE_MAP[attribute]
        map[value]
      else
        value
      end
    end
  end

  def self.build_association_finder(model_class)
    lambda do |*args|
      in_cond, out_cond = args.collect {|array| array.collect(&:downcase)}
      join_name = "LOWER(#{model_class.table_name}.name)"

      conditions = if out_cond.blank?
        ["#{join_name} IN (?)", in_cond]
      elsif in_cond.blank?
        ["#{join_name} NOT IN (?)", out_cond]
      else
        ["#{join_name} IN (?) OR #{join_name} NOT IN (?)", in_cond, out_cond]
      end

      { :conditions => conditions, :include => model_class.to_s.downcase.to_sym }
    end
  end

  named_scope :filter_by_project, build_association_finder(Project)
  named_scope :filter_by_objective, build_association_finder(Objective)
  named_scope :filter_by_status, lambda { |in_cond, out_cond|
    in_cond_sql = in_cond.collect {|cond| cond.nil? ? "completed IS ?" : "completed = ?" }
    out_cond_sql = out_cond.collect {|cond| cond.nil? ? "completed IS NOT ?" : "(completed <> ? OR completed IS NULL)" }
    cond_sql = (in_cond_sql + out_cond_sql).join(' OR ')
    { :conditions => [cond_sql, *(in_cond + out_cond)] } 
  }

end
