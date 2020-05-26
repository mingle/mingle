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

class ValueMacro < Macro

  parameter :query, :required => true, :example => "SELECT property_or_aggregate WHERE condition1 AND condition2"
  parameter :project

  def initialize(*args)
    super
    self.query = CardQuery.parse(self.query, card_query_options)
  end

  def can_be_cached?
    self.query.can_be_cached?
  end
  include AsyncMacro

  def generate_data
    result = self.query.single_value
    if self.query.columns.first.numeric?
      project.to_num(result || 0)
    else
      result
    end
  end

  def generate_data?(callback)
    return true if self.query.columns.first.numeric? && self.query.columns.first.name.eql?('Number')
    super
  end

end

Macro.register('value', ValueMacro)
