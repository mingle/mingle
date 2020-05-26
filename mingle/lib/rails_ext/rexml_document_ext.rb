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

require 'rexml/document'
class REXML::Document
  def elements_at(xpath)
    REXML::XPath.match(self, xpath)
  end
  
  def element_count_at(xpath)
    elements_at(xpath).size
  end
  
  def element_text_at(xpath)
    assure_element_count_is_1(xpath)
    elements_at(xpath).first.text
  end
  
  def element_cdata_at(xpath)
    assure_element_count_is_1(xpath)
    elements_at(xpath).first.cdatas[0]
  end
  
  def attribute_value_at(xpath)
    assure_element_count_is_1(xpath)
    elements_at(xpath).first.to_s
  end

  def attribute_values_at(xpath)
    elements_at(xpath).map(&:to_s)
  end
  
  def elements_children_count_at(xpath)
    assure_element_count_is_1(xpath)
    elements_at(xpath).first.elements.size
  end

  private
  
  def assure_element_count_is_1(xpath)
    count = element_count_at(xpath)
    raise "No element found at path #{xpath} for document #{self}" if count == 0
    raise "More than one element found at path #{xpath} for document #{self}" if count > 1
  end
end

