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

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  attribute :updated_at, :datetime
  attribute :created_at, :datetime

  class << self
    def validate_filesize_of_with_custom_message(*attrs)

      options = attrs.pop if attrs.last.is_a?(Hash)


      raise ArgumentError, 'Please include the :in option.' if !options || !options[:in]
      raise ArgumentError, 'Invalid value for option :in' unless options[:in].is_a? Range

      validates_each(attrs, options) do |record, attr, value|
        unless value.blank?
          size = File.size?(value) || 0
          # patch start : make file column filesize validation support custom warning message
          record.errors.add attr, options[:size_smaller_warn] || 'is smaller than the allowed size range.' if size < options[:in].first
          record.errors.add attr, options[:size_bigger_warn] || 'is larger than the allowed size range.' if size > options[:in].last
        end
      end
    end

    ORACLE_BATCH_LIMIT = 1000

    def batched_find(ids)
      found = []
      ids.each_slice(ORACLE_BATCH_LIMIT) do |u|
        where(id: u).find_each do|records|
          found << records
        end
      end
      found
    end

    def validates_file_format_of_with_custom_message(*attrs)

      options = attrs.pop if attrs.last.is_a?Hash
      raise ArgumentError, 'Please include the :in option.' if !options || !options[:in]
      options[:in] = [options[:in]] if options[:in].is_a?String
      raise ArgumentError, 'Invalid value for option :in' unless options[:in].is_a? Array

      validates_each(attrs, options) do |record, attr, value|
        unless value.blank?
          mime_extensions = record.send("#{attr}_options")[:mime_extensions]
          extensions = options[:in].map{|o| mime_extensions[o] || o }
          record.errors.add attr, options[:error_message] || 'is not a valid format.' unless extensions.include?(value.scan(EXT_REGEXP).flatten.first)
        end
      end
    end
  end

  def column_defined?(column_name)
    column_name = self.class.connection.column_name(column_name).downcase
    self.class.column_names.any? {|n| n.downcase == column_name}
  end


end
