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

class CardQuery
  class Results
    include Enumerable
    attr_reader :values
    
    def initialize(values, options)
      @values = values
      @options = options
    end
    
    def each(&block)
      @values.each(&block)
    end
    
    def to_values
      case version
      when 'v1'
        @values.collect{|v| v.transform_keys(&:underscored)}
      else
        transformer = lambda {|str| str.strip.underscored }
        @values.collect{|v| v.transform_keys(&transformer)}
      end
    end
    
    def to_xml
      return  {:results => dashed_keys(values)}.to_xml(:dasherize => false) if version == 'v1'

      results = values.map(&method(:to_result))
      "".tap do |result|
        builder = Builder::XmlMarkup.new(:target => result, :indent => 2)
        builder.instruct!
        builder.results :type => 'array' do
          results.each { |result| result.to_xml(:builder => builder) }
        end
      end
    end
    
    private
    
    def dashed_keys(results)
      results.collect { |r| r.transform_keys(&:dashed) }
    end

    def version
      @options[:api_version]
    end
    
    def to_result(row)
      Result.new(:result => row)
    end

    class Result < OpenStruct
      include API::XMLSerializer
      serializes_as :complete => [:result],
                    :element_name => 'result'
    end
  end
end
