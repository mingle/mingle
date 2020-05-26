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

class Array
  def average
    sum.to_f / size.to_f
  end
end

class AverageMacro
  
  def initialize(parameters, project, current_user)
    @parameters = parameters
    @project = project
    @current_user = current_user
    raise "Parameter #{'query'.bold} is required" if query.blank?
  end
    
  def execute
    first_values = @project.execute_mql(query).collect { |record| record.values.first }
    data = first_values.reject(&:blank?).collect(&:to_f) 
    data.empty? ? 'no values found' : @project.format_number_with_project_precision(data.average).to_s
  end
  
  def can_be_cached?
    @project.can_be_cached?(query)
  end
  
  def self.supports_project_group?
    false
  end
  
  private
  
  def query
    @parameters['query']
  end
end
