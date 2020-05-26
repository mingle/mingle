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

require 'stripper'

class ElasticSearch
  module ActiveRecordExt

    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      # Valid options:
      # :type (optional) configue type to store data in.  default to model table name
      # :json (optional) configure the json document to be indexed (see http://api.rubyonrails.org/classes/ActiveModel/Serializers/JSON.html#method-i-as_json for available options)
      def elastic_searchable(options = {})
        self.cattr_accessor :elastic_options
        options.symbolize_keys!
        self.elastic_options = options
        self.elastic_options[:type] ||= self.table_name

        after_destroy do |searchable|
          msg = searchable.message.merge(:type => elastic_options[:type], :index_name => elastic_options[:index_name].call(searchable))
          ElasticSearchDeindexPublisher.publish(msg)
        end

        self.send(:include, ElasticSearchableInstanceMethods)
      end

      def deindex(ids, index_name)
        ElasticSearch.deindex(ids, index_name, elastic_options[:type])
      end
    end

    module ElasticSearchableInstanceMethods

      def reindex
        ElasticSearch.reindex(id, as_json_for_index, self.elastic_options[:index_name].call(self), self.class.elastic_options[:type])
      end

      def as_json_for_index
        options = self.class.elastic_options
        json = as_json(evaluate_proc_values(options[:json]))
        json.merge!(evaluate_proc_values(options[:merge])) if options[:merge]

        Stripper.sanitize_string_value json
      end

      def evaluate_proc_values(hash)
        copy = hash.dup
        copy.each do |key, value|
          next unless value.respond_to?(:call)
          copy[key] = value.call(self)
        end
      end
    end

  end
end
