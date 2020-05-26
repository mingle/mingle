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

module SqlHelper
  extend self

  def sanitize_sql(sql, *values)
    ActiveRecord::Base.send :sanitize_sql, [sql, *values]
  end

  def sanitize_sql_for_conditions(condition)
    ActiveRecord::Base.send :sanitize_sql_for_conditions, condition
  end

  def concat_columns(*column_names)
    column_names.join(' || ')
  end

  module_function :sanitize_sql, :concat_columns
end
