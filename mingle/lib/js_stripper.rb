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

class JsStripper < HTML::FullSanitizer
  
  alias :strip :sanitize
  
  protected
  
  def process_node(node, result, options)
    options[:parent] ||= []
    
    result << case node
      when HTML::Tag
        if node.closing == :close
          options[:parent].shift
        else
          options[:parent].unshift node.name
        end
        strip_attributes(node)
        node.name == 'script' ? nil : node
      else
        options[:parent].first == 'script' ? nil : node
      end
  end
  
  def strip_attributes(node)
    return unless node.attributes
    node.attributes.keys.each do |key|
      node.attributes.delete(key) if key =~ /^on/i
    end
  end
end
