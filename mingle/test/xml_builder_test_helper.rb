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

module XMLBuilderTestHelper
  def get_elements_by_xpath(xml, xpath)
    REXML::Document.new(xml).elements_at(xpath)
  end
  
  def get_number_of_elements(xml, xpath)
    REXML::Document.new(xml).element_count_at(xpath)
  end
  
  def get_element_text_by_xpath(xml, xpath)
    REXML::Document.new(xml).element_text_at(xpath)
  end
  
  def get_element_cdata_by_xpath(xml, xpath)
    REXML::Document.new(xml).element_cdata_at(xpath).value
  end
  
  def get_elements_text_by_xpath(xml, xpath)
    get_elements_by_xpath(xml, xpath).map(&:text)
  end
  
  def get_attribute_by_xpath(xml, xpath)
    REXML::Document.new(xml).attribute_value_at(xpath)
  end

  def get_attributes_by_xpath(xml, xpath)
    REXML::Document.new(xml).attribute_values_at(xpath)
  end
  
  def get_root_element_name(xml)
    REXML::Document.new(xml).root.name
  end

  def elements_children_count_at(xml, xpath)
    REXML::Document.new(xml).elements_children_count_at(xpath)
  end
end
