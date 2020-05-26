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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')

# Tags: properties, api_version_2
class ApiPropertyDefinitionTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  include TreeFixtures::FeatureTree

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :identifier => 'zebra', :users => [User.find_by_login('member')]) do |project|
        setup_property_definitions :status => ['new', 'open', 'close'], :iteration => ['1']
        prop = setup_numeric_property_definition('Hidden', [1, 2])
        prop.update_attributes(:hidden => true)
        create_cards(project, 3)
      end
    end
    @version="v2"
    API::PropertyDefinition.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    API::PropertyDefinition.prefix = "/api/#{@version}/projects/#{@project.identifier}/"
    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
  end

  def teardown
    disable_basic_auth
    logout_as_nil
  end

  protected

  def get_property_definition(property_definition)
    get("#{url_prefix(property_definition.project)}/property_definitions/#{property_definition.id}.#{format}", {}).body
  end

  def get_project_property_definitions(project)
    get("#{url_prefix(project)}/property_definitions.#{format}", {}).body
  end

  def format
    ''
  end

  def url_prefix(project)
    "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{project.identifier}"
  end
end

class ApiPropertyDefinitionsVersion2Test < ApiPropertyDefinitionTest
  def test_get_single_property_definition
    xml = get_property_definition(@project.find_property_definition("status"))
    assert_equal "status", get_element_text_by_xpath(xml, "//#{element_name}/name")
  end

  def test_can_get_list_of_property_definitions
    xml = get_project_property_definitions(@project)
    assert_equal ['Hidden', 'iteration', 'status'], get_elements_text_by_xpath(xml, "//#{element_name}s/#{element_name}/name")
  end

  def test_can_get_data_type_of_property_definitions
    xml = get_project_property_definitions(@project)
    assert_equal ['numeric', 'string', 'string'], get_elements_text_by_xpath(xml, "//#{element_name}s/#{element_name}/data_type")
  end

  def test_should_be_able_to_get_tree_properties
    login_as_admin
    create_three_level_feature_tree
    logout

    xml = get_project_property_definitions(@project)
    property_names = get_elements_text_by_xpath(xml, "//#{element_name}s/#{element_name}/name")

    assert_include 'System breakdown module', property_names
    assert_include 'System breakdown feature', property_names
  end

  def test_formula_property_should_include_formula
    with_new_project do |project|
      cp_one_plus_one = setup_formula_property_definition 'one_plus_one', '1 + 1'
      xml = get_property_definition(cp_one_plus_one)
      assert_equal '(1 + 1)', get_element_text_by_xpath(xml, "//#{element_name}/formula")
    end
  end

  #when there is no card type related with formula_property, we can always create the formula, this is current behaviour, and seems need a story/bug to change it later
  # ---- xli
  def test_should_not_create_formula_property_definition_when_used_property_does_not_related_with_card_types_that_formula_property_related
    hello_response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "hello", 'property_definition[data_type]' => 'numeric', 'property_definition[is_managed]' => true)
    assert_equal "201", hello_response.code

    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "hello_plus_one", "property_definition[data_type]" => 'formula', 'property_definition[formula]' => 'hello + 1', "property_definition[card_types][][name]" => "Card")
    end

    assert_equal "422", response.code
    assert_match /The component property should be available to all card types that formula property is available to./, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_give_422_error_when_no_body_given_for_creating_property_definition
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", {})
    end

    assert_equal "422", response.code
    assert_match /You must provide the type of the property to create a card property./, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_not_create_property_definition_without_data_type
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "FooStatus", "property_definition[description]" => "describe status")
    end
    assert_equal "422", response.code
    assert_match /You must provide the type of the property to create a card property/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_give_422_error_when_given_a_property_type_not_exists
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[data_type]" => "non-type", "property_definition[name]" => "FooStatus", "property_definition[description]" => "describe status")
    end
    assert_equal "422", response.code
    assert_match /There is no such data type: non-type/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_not_create_property_definition_for_numeric_data_type_without_is_managed_flag
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "FooStatus", "property_definition[description]" => "describe status", "property_definition[data_type]" => "numeric", "property_definition[is_managed]" => nil)
    end
    assert_equal "422", response.code
    assert_match /is_managed/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_not_create_property_definition_for_string_data_type_without_is_managed_flag
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "FooStatus", "property_definition[description]" => "describe status", "property_definition[data_type]" => "string", "property_definition[is_managed]" => nil)
    end
    assert_equal "422", response.code
    assert_match /is_managed/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_give_error_when_create_non_numeric_non_text_property_definition_with_is_managed_flag
    %w{ user date card formula}.each do |data_type|
      assert_no_difference "PropertyDefinition.count" do
        response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "FooStatus", "property_definition[description]" => "describe status", "property_definition[data_type]" => data_type, "property_definition[is_managed]" => true)
        assert_equal "422", response.code
        assert_match /is_managed/, get_element_text_by_xpath(response.body, '//errors/error')
      end
    end
  end

  def test_should_not_allow_a_anon_user_to_create_a_property_definition
    login_as_admin
    @project.update_attribute(:anonymous_accessible, true)
    url_prefix = "http://localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    assert_no_difference "PropertyDefinition.count" do
      response = post(url_prefix + "/property_definitions.xml", "property_definition[name]" => "AnotherStatus", "property_definition[description]" => "describe status", "property_definition[data_type]" => "string", "property_definition[is_managed]" => true)
      assert_equal "401", response.code
    end
  end

  def test_should_not_allow_a_project_member_to_create_a_property_definition
    url_prefix = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    assert_no_difference "PropertyDefinition.count" do
      response = post(url_prefix + "/property_definitions.xml", "property_definition[name]" => "AnotherStatus", "property_definition[description]" => "describe status", "property_definition[data_type]" => "string", "property_definition[is_managed]" => true)
      assert_equal "403", response.code
    end
  end

  def test_should_be_able_to_create_managed_text_property_definition
    response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "AnotherStatus", "property_definition[description]" => "describe status", "property_definition[data_type]" => "string", "property_definition[is_managed]" => 'true')
    assert_equal "201", response.code
    assert_match /property_definitions\/\d+.xml/, response.header["location"]
    response = follow_link_to_created_resource(response)
    assert_equal 'AnotherStatus', get_element_text_by_xpath(response.body, '//property_definition/name')
    assert_equal 'describe status', get_element_text_by_xpath(response.body, '//property_definition/description')
    assert_equal 'true', get_element_text_by_xpath(response.body, '//property_definition/is_managed')
    assert_not_nil @project.reload.find_property_definition("AnotherStatus")
  end

  def test_should_be_able_to_create_unmanaged_text_property_definition
    response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "Any kind of text", "property_definition[description]" => "describe any text", "property_definition[data_type]" => "string", "property_definition[is_managed]" => false)
    assert_equal "201", response.code
    response = follow_link_to_created_resource(response)
    assert_equal 'Any kind of text', get_element_text_by_xpath(response.body, '//property_definition/name')
    assert_equal 'false', get_element_text_by_xpath(response.body, '//property_definition/is_managed')
    assert_not_nil @project.reload.find_property_definition("Any kind of text")
  end

  def test_create_user_property_definition
    response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "owner", "property_definition[data_type]" => "user")
    assert_equal "201", response.code
    response = follow_link_to_created_resource(response)
    assert_equal 'owner', get_element_text_by_xpath(response.body, '//property_definition/name')
    assert_equal 'user', get_element_text_by_xpath(response.body, '//property_definition/data_type')
    assert_not_nil @project.reload.find_property_definition("owner")
  end

  def test_create_formula_property_definition
    assert_difference "FormulaPropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "one plus one", "property_definition[data_type]" => 'formula', "property_definition[formula]" => "HIDDEN+hidden")
      assert_equal "201", response.code
      assert_match /property_definitions\/\d+.xml/, response.header["location"]
      response = follow_link_to_created_resource(response)
      assert_equal 'one plus one', get_element_text_by_xpath(response.body, '//property_definition/name')
      assert_equal '(HIDDEN + hidden)', get_element_text_by_xpath(response.body, '//property_definition/formula')
    end
  end

  def test_create_formula_property_definition_specifying_how_to_handle_not_set
    assert_difference "FormulaPropertyDefinition.count", +2 do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "one plus one", "property_definition[data_type]" => 'formula', "property_definition[formula]" => "HIDDEN+hidden")
      assert_equal "201", response.code
      assert_match /property_definitions\/\d+.xml/, response.header["location"]
      response = follow_link_to_created_resource(response)
      assert_equal 'false', get_element_text_by_xpath(response.body, '//property_definition/null_is_zero')

      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "one plus one v2", "property_definition[data_type]" => 'formula', "property_definition[formula]" => "HIDDEN+hidden", "property_definition[null_is_zero]" => "true")
      response = follow_link_to_created_resource(response)
      assert_equal 'true', get_element_text_by_xpath(response.body, '//property_definition/null_is_zero')
    end
  end

  def test_creating_property_definition_does_not_associate_card_types_by_default
    type_story = @project.card_types.create!(:name => 'Story')
    response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "hackintosh", "property_definition[data_type]" => "user")
    assert_equal "201", response.code
    user_pd = @project.reload.find_property_definition("hackintosh")
    assert_equal [], user_pd.card_types
  end

  def test_can_create_property_definition_with_associated_card_types
    type_story = @project.card_types.create!(:name => 'Story')
    response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "hackintosh", "property_definition[data_type]" => "user", "property_definition[card_types][][name]" => "Story")
    assert_equal "201", response.code
    response = follow_link_to_created_resource(response)
    assert_equal "Story", get_element_text_by_xpath(response.body, "//property_definition/card_types/card_type/name")
  end

  def test_can_create_property_definition_with_associated_card_types_regardless_of_casing
    type_story = @project.card_types.create!(:name => 'StoRiE')
    response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "hackintosh", "property_definition[data_type]" => "user", "property_definition[card_types][][name]" => "storie")
    assert_equal "201", response.code
    user_pd = @project.reload.find_property_definition("hackintosh")
    assert_equal [type_story], user_pd.card_types
  end

  def test_should_give_validation_errors_if_name_is_blank
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "", "property_definition[data_type]" => "user")
    end
    assert_equal "422", response.code
    assert_match /Name can't be blank/, get_element_text_by_xpath(response.body, '//errors/error')

    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[data_type]" => "user")
    end
    assert_equal "422", response.code
    assert_match /Name can't be blank/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_give_validation_errors_if_name_contains_and_char
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "&", "property_definition[data_type]" => "user")
    end
    assert_equal "422", response.code
    assert_match /Name should not contain '&', '=', '#', '"', ';', '\[' and '\]' characters/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_give_validation_errors_if_name_is_long
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "1234567890 1234567890 1234567890 1234567890", "property_definition[data_type]" => "user")
    end
    assert_equal "422", response.code
    assert_match /Name is too long \(maximum is 40 characters\)/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  #our implementation of creating property definition need to be done successfully before card_types related could be
  #associated, this test is making sure that there is no error with creating (actually, should be 'ignoring creating')
  #property_definition card_types mapping when there is error creating property definition.
  def test_should_give_validation_errors_if_name_is_long_and_also_give_a_card_type_related
    response = nil
    assert_no_difference "PropertyDefinition.count" do
      response = post(@url_prefix + "/property_definitions.xml", "property_definition[name]" => "1234567890 1234567890 1234567890 1234567890", "property_definition[data_type]" => "user", "property_definition[card_types][][name]" => 'Card')
    end
    assert_equal "422", response.code
    assert_match /Name is too long \(maximum is 40 characters\)/, get_element_text_by_xpath(response.body, '//errors/error')
  end

  def test_should_be_able_to_update_hidden_properties
    card = @project.cards.first
    put("#{@url_prefix}/cards/#{card.number}.xml", 'card[properties][][name]' => 'hidden', 'card[properties][][value]' => '1')
    assert_equal "1", card.reload.cp_hidden
    put("#{@url_prefix}/cards/#{card.number}.xml", 'card[properties][][name]' => 'hidden', 'card[properties][][value]' => '2')
    assert_equal "2", card.reload.cp_hidden
  end

  def test_error_from_member_updatung_located_property_should_not_contain_escaped_html
    prop = setup_numeric_property_definition('Iteration', [1, 2])
    prop.update_attributes(:restricted => true)
    card = @project.cards.first
    @url_prefix = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    response = put("#{@url_prefix}/cards/#{card.number}.xml", 'card[properties][][name]' => 'Iteration', 'card[properties][][value]' => '5')
    assert_equal "iteration is restricted to 1 and 2", get_element_text_by_xpath(response.body, "/errors/error")
  end

  def test_non_formula_properties_should_not_include_formula
    xml = get_property_definition(@project.find_property_definition("status"))
    element_names = get_elements_by_xpath(xml, '//property_definition/property_value_details/property_value/*').map(&:name)
    assert_not element_names.empty? # sanity check
    assert_not_include 'formula', element_names
  end

  def test_managed_text_property_should_include_values
    xml = get_property_definition(@project.find_property_definition("status"))
    values = get_elements_text_by_xpath(xml, '//property_definition/property_value_details/property_value/value')
    assert_equal %w{new open close}, values
  end

  def test_managed_numeric_property_should_include_values
    with_new_project do |project|
      cp_estimate = setup_managed_number_list_definition('estimate', [1, 2])
      xml = get_property_definition(cp_estimate)
      values = get_elements_text_by_xpath(xml, '//property_definition/property_value_details/property_value/value')
      assert_equal %w{1 2}, values
    end
  end

  protected

  def element_name
    'property_definition'
  end

  def format
    'xml'
  end
end

class ApiPropertyDefinitionsJsonTest < ApiPropertyDefinitionTest
  def test_can_get_list_of_property_definitions_as_json
    json = get_project_property_definitions(@project)
    property_definitions = JSON.parse(json)

    assert_equal %w(Hidden iteration status), property_definitions.map { |pd| pd['name'] }
    assert_equal [true, false, false], property_definitions.map { |pd| pd['isNumeric'] }
  end

  def test_can_get_property_definition_as_json
    property_def = @project.property_definitions.first
    json = get_property_definition(property_def)

    assert_equal property_def.name, JSON.parse(json)['name']
  end
  protected

  def format
    'json'
  end
end
