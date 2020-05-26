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

# This is a sample macro that displays a breakdown of values 
# for a given property across cards of a different types using 
# a Google Charts pie chart.

class ValueBreakdown   
  
  attr_reader :card_type, :property

  def initialize(parameters, project, current_user)
    @card_type = parameters['type']
    @property = parameters['property']
    @project = project
  end
    
  def execute    
    begin
      labels, totals, colors = get_data
      params = build_params(labels, totals, colors)
      param_string = params.map{|entry| "#{entry[0]}=#{entry[1]}" }.join('&')     
      "<img src=\"http://chart.apis.google.com/chart?#{param_string}\" />"
    rescue
      puts $!.message
      puts $!.backtrace.join("\n")
      raise $!
    end
  end
  
  def can_be_cached?
    false
  end
  
  private 
  
  # This method executes some mql and generates data that can be used to build a Google Chart API URL
  def get_data
    mql = "SELECT '#{self.property}', COUNT(*) WHERE Type = '#{self.card_type}' GROUP BY '#{self.property}'"
    rows = @project.execute_mql(mql) 
    labels = rows.collect{|row| row.find_ignore_case(self.property)}.map{|l| l.blank? ? '(not set)' : l}
    totals = rows.collect{|row| row.find_ignore_case('Count ')} 
    colors = labels.collect do |label|
      property_definition = @project.property_definitions.detect { |pd| pd.name.downcase == self.property.downcase }
      property_value = property_definition.values.detect { |v| v.display_value.downcase == label.downcase }
      label == '(not set)' ? '111111' : property_value.color
    end
    [labels, totals, colors]   
  end
  
  # This method builds a query string of the form required by the Google Chart API
  def build_params(labels, totals, colors)
    params = {'cht' => 'p3', 'chs' => '350x150'}
    params['chd'] = "t:#{totals.join(',')}"
    params['chl'] = labels.join('|')
    params['chco'] = colors.join(',')
    params
  end
  
end

