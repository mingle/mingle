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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class PropertyDefinitionXmlTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_enumerated_property_def_xml_should_have_the_enumeration_values
    status = @project.find_property_definition('status')        
    assert_equal status.enumeration_values.collect(&:value), get_elements_by_xpath(status.to_xml, "/property_definition/property_value_details/property_value/value").collect(&:text)
  end
  
  def test_enumerated_property_def_data_type_in_xml
    pd = @project.find_property_definition('Assigned')
    assert_equal 'string', get_element_text_by_xpath(pd.to_xml, "/property_definition/data_type")
    
    pd = @project.find_property_definition('Release')
    assert_equal 'numeric', get_element_text_by_xpath(pd.to_xml, "/property_definition/data_type")
  end
  
  
  def test_enumerated_property_def_should_be_managed
    pd = @project.find_property_definition('Assigned')
    assert_equal 'true', get_element_text_by_xpath(pd.to_xml, "/property_definition/is_managed")
    
    pd = @project.find_property_definition('Release')
    assert_equal 'true', get_element_text_by_xpath(pd.to_xml, "/property_definition/is_managed")
  end

  def test_enumerated_property_def_should_be_managed
    pd = @project.find_property_definition('id')
    assert_equal 'false', get_element_text_by_xpath(pd.to_xml, "/property_definition/is_managed")
  end
    
  def test_user_property_def_should_not_have_the_enumeration_values
    dev = @project.find_property_definition("dev")
    assert_equal 0, get_number_of_elements(dev.to_xml, "/property_definition/enumeration_values")
  end
  
  def test_user_property_def_should_not_have_is_managed
    dev = @project.find_property_definition("dev")
    assert_equal 0, get_number_of_elements(dev.to_xml, "/property_definition/is_managed")
  end
  
  def test_user_property_def_should_have_user_as_data_type
    dev = @project.find_property_definition("dev")
    assert_equal 'user', get_element_text_by_xpath(dev.to_xml, "/property_definition/data_type")
  end
  
  def test_should_include_general_attributes    
    pd = @project.find_property_definition('Assigned')

    xml = REXML::Document.new(pd.to_xml)
    root = xml.root
    assert_equal 'property_definition', root.name
    assert_equal '', root.text.strip_all
    
    elements = root.elements
    
    assert_xml_element_properties elements['column_name'],     :text => 'cp_assigned'
    assert_xml_element_properties elements['description'],     :text => nil,          :attributes => { 'nil' => 'true' }
    assert_xml_element_properties elements['hidden'],          :text => 'false',      :attributes => { 'type' => 'boolean' }
    assert_xml_element_properties elements['id'],              :text => pd.id.to_s,   :attributes => { 'type' => 'integer' }
    assert_xml_element_properties elements['is_numeric'],      :text => 'false',      :attributes => { 'type' => 'boolean' }
    assert_xml_element_properties elements['name'],            :text => 'Assigned'
    assert_xml_element_properties elements['position'],        :text => nil,          :attributes => { 'nil' => 'true' }
    assert_xml_element_properties elements['restricted'],      :text => 'false',      :attributes => { 'type' => 'boolean' }
    assert_xml_element_properties elements['transition_only'], :text => 'false',      :attributes => { 'type' => 'boolean' }
    assert_xml_element_properties elements['data_type'],       :text => 'string'
  end
  
  def test_formula_property_def_should_has_formular
    with_new_project do |project|
      one_third = setup_formula_property_definition('one third', '1/3')
      assert_equal one_third.formula.to_s, get_element_text_by_xpath(one_third.to_xml, "/property_definition/formula")
    end    
  end
  
  def test_v2_to_xml_should_include_compact_project
    pd = @project.find_property_definition('Assigned')
    xml = pd.to_xml(:version => 'v2')
    assert_equal pd.project.identifier, get_element_text_by_xpath(xml, "//property_definition/project/identifier")
    document = REXML::Document.new(xml)
    assert_equal ['identifier', 'name'], document.elements_at("//property_definition/project/*").map(&:name).sort
  end
  
  def assert_xml_element_properties(element, options)
    options = { :elements_size => 0, :attributes => {} }.merge(options)
    assert_equal options[:elements_size], element.elements.size
    attributes_as_hash = element.attributes.inject({}) { |acc, (name, value)| acc[name] = value; acc }
    assert_equal options[:attributes], attributes_as_hash
    assert_equal options[:text], element.text if options[:text]
  end
  
end
