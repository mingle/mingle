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

class Aggregator
  attr_reader :identifier, :display_name
  
  def initialize(identifier, display_name)
    @identifier, @display_name = identifier, display_name
  end
end

class Sum < Aggregator
  def result(values)
    values.inject(0) { |sum, value| sum + value }
  end
end

class Count < Aggregator
  def result(values)
    values.size
  end
end

class Average < Aggregator
  def result(values)
    return BigDecimal.new('0') if values.empty?
    sum = Sum.new('SUM', 'Sum').result(values)
    count = Count.new('COUNT', 'Count').result(values)
    BigDecimal.new(sum.to_s) / BigDecimal.new(count.to_s)
  end
end

class Minimum < Aggregator
  def result(values)
    values.min
  end
end

class Maximum < Aggregator
  def result(values)
    values.max
  end
end

class AggregateType
  attr_reader :identifier, :display_name
  
  def initialize(identifier, display_name)
    @identifier = identifier
    @display_name = display_name
  end
  
  SUM = Sum.new('SUM', 'Sum')
  AVG = Average.new('AVG', 'Average')
  MIN = Minimum.new('MIN', 'Minimum')
  MAX = Maximum.new('MAX', 'Maximum')
  COUNT = Count.new('COUNT', 'Count')
  
  TYPES = [SUM, AVG, MIN, MAX, COUNT]
  
  def self.find_by_identifier(identifier)
    return AggregateType.new(nil, '') unless identifier
    TYPES.detect { |type| type.identifier.downcase == identifier.downcase }
  end
end


