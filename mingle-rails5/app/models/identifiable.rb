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

module Identifiable
  IDENTIFIER_REGEX = "[0-9a-z_]+"
  IDENTIFIER_MAX_LEN = 30 # postgres8: 64; oracle9i: 30;

  def self.included(base)
    base.validates_presence_of :name
    base.validates_presence_of :identifier, :if => Proc.new { |model| model.name.present? }

    base.validates_format_of :identifier,
                        :with => /\A#{IDENTIFIER_REGEX}\z/,
                        :message => "may contain only lower case letters, numbers and underscore ('_')", :if => Proc.new { |model| model.identifier.present? }
    base.validates_format_of :identifier,
                        :with => /\A\D/,
                        :message => "may not start with a digit",
                        :if => Proc.new { |model| model.identifier.present? }
    base.validates_uniqueness_of :identifier, :unless => Proc.new { |model| model.is_a?(Objective) }
    base.validates_length_of :identifier, :maximum => IDENTIFIER_MAX_LEN
    base.extend(ClassMethods)
  end

  module ClassMethods
    def unique(find_by_column, name, suffix = '', options = {})
      maxlen = {:name => 255, :identifier => Identifiable::IDENTIFIER_MAX_LEN}[find_by_column]
        name.uniquify_with_succession(maxlen, suffix) do |generated_name|
        can_find(find_by_column, generated_name, options)
      end
    end

    def can_find(find_by_column, column_value, options)
      sql = "LOWER(#{find_by_column}) = LOWER(?)"
      options.each { |option| sql = sql + " AND #{option.first} = ?" }
      query_values = [column_value] + options.values
      sanitized_query = SqlHelper.sanitize_sql_for_conditions([sql,*query_values])
      where(sanitized_query).first
    end
  end

end
