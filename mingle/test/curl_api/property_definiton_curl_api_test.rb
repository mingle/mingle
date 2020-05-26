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

require File.expand_path(File.dirname(__FILE__) + '/curl_api_test_helper')

# Tags: api, cards
class PropertyDefinitonCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  SIZE = 'Size'
  STATUS = 'status'
  ITERATION = 'iteration'
  RELEASE = 'release'
  TREE_PROPERTY = 'tree property'

  ANY_TEXT = 'any text'
  ANY_NUMBER = 'any number'
  DATE = 'date'
  USER = 'user'
  CARD_TYPE = 'card type'
  FORMULA = 'formula'
  AGGREGATE = 'aggregate'

  CARD = 'Card'
  BUG = 'Bug'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)

    User.find_by_login('admin').with_current do
      @project = with_new_project(:admins => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
        setup_numeric_property_definition(SIZE, [2, 4])
        setup_property_definitions(STATUS => %w(new open))
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_create_any_text_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{ANY_TEXT}" -d "property_definition[data_type]=string" -d "property_definition[is_managed]=false" -d "property_definition[description]=this is an any text property" -d "property_definition[card_types][][name]=card" #{property_definitions_list_url}]
    any_text_property = @project.all_property_definitions.find_by_name(ANY_TEXT)
    assert_response_code(201, output)
    assert_response_includes(property_definition_url_for(any_text_property, :user => nil), output)

    output = %x[curl -i "#{property_definition_url_for(any_text_property)}"]
    assert_equal ANY_TEXT, get_element_text_by_xpath(output, "//property_definition/name/")
    assert_equal "string", get_element_text_by_xpath(output, "//property_definition/data_type/")
    assert_equal "false", get_element_text_by_xpath(output, "//property_definition/is_managed/")
    assert_equal "Any text", get_element_text_by_xpath(output, "//property_definition/property_values_description/")
    assert_equal "false", get_element_text_by_xpath(output, "//property_definition/is_numeric/")
  end

  def test_should_not_be_able_to_create_property_for_non_exising_project
    url = base_api_url_for "projects", "non_existing_project", "property_definitions.xml"
    output = %x[curl -i -X POST -d "property_definition[name]=start on" -d "property_definition[data_type]=date" "#{url}"]
    assert_response_code(404, output)
  end

  def test_can_not_use_formula_in_another_formula
    setup_formula_property_definition(FORMULA, 'size*2/9')

    output = %x[curl -i -X POST -d "property_definition[name]=another formula" -d "property_definition[data_type]=formula" -d "property_definition[formula]=#{FORMULA}/size" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "Property #{FORMULA} is a formula property and cannot be used within another formula.", get_element_text_by_xpath(output, "//errors/error")

    setup_formula_property_definition("formula 2", 'size-9')

    output = %x[curl -i -X POST -d "property_definition[name]=another formula" -d "property_definition[data_type]=formula" -d "property_definition[formula]=#{FORMULA}*'formula 2'" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "Properties #{FORMULA} and formula 2 are formula properties and cannot be used within another formula.", get_element_text_by_xpath(output, "//errors/error")
  end

  def test_error_message_for_ivalid_formula_when_create_formula_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{FORMULA}" -d "property_definition[data_type]=formula" -d "property_definition[formula]=size/estimate-'pre estimate'" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "The formula is not well formed. No such property: estimate.", get_element_text_by_xpath(output, "//errors/error")
  end

  def test_error_message_for_assigning_formula_to_card_types_its_component_not_avaliable_to
    setup_card_type(@project, BUG)

    output = %x[curl -i -X POST -d "property_definition[name]=#{FORMULA}" -d "property_definition[data_type]=formula" -d "property_definition[formula]=size%2B1" -d "property_definition[card_types][][name]=#{BUG}" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "The component property should be available to all card types that formula property is available to.", get_element_text_by_xpath(output, "//errors/error")
  end

  # bug 9109
  def test_error_message_for_providing_invalid_value_for_is_managed_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{ANY_TEXT}" -d "property_definition[data_type]=string" -d "property_definition[is_managed]=invalid" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "An is_managed value of true or false is required for string", get_element_text_by_xpath(output, "//errors/error")

    output = %x[curl -i -X POST -d "property_definition[name]=#{ANY_NUMBER}" -d "property_definition[data_type]=numeric" -d "property_definition[is_managed]=invalid" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "An is_managed value of true or false is required for numeric", get_element_text_by_xpath(output, "//errors/error")
  end

  # bug 9110
  def test_should_ignore_is_managed_if_property_is_not_text_or_numeric
    data_type = ['card', 'date', 'user', 'formula']
    formula = '-d "property_definition[formula]=size*2"' if data_type=='formula'

    data_type.each do |data_type|
      output = %x[curl -i -X POST -d "property_definition[name]=a property" -d "property_definition[data_type]=#{data_type}" -d "property_definition[is_managed]=true" #{formula} #{property_definitions_list_url}]
      assert_equal "is_managed is not applicable for #{data_type} property", get_element_text_by_xpath(output, "//errors/error")
      assert_response_code(422, output)
    end
  end

  def test_is_managed_is_required_for_text_and_numeric_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{ANY_TEXT}" -d "property_definition[data_type]=string" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "An is_managed value of true or false is required for string", get_element_text_by_xpath(output, "//errors/error")

    output = %x[curl -i -X POST -d "property_definition[name]=#{ANY_NUMBER}" -d "property_definition[data_type]=numeric" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "An is_managed value of true or false is required for numeric", get_element_text_by_xpath(output, "//errors/error")
  end

  def test_error_message_when_associate_invalid_card_types_with_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{RELEASE}" -d "property_definition[data_type]=card" -d "property_definition[card_types][][name]=invalid card type 1" -d "property_definition[card_types][][name]=invalid card type 2" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "There is no such card type: invalid card type 1", get_element_text_by_xpath(output, "//errors/error[1]")
    assert_equal "There is no such card type: invalid card type 2", get_element_text_by_xpath(output, "//errors/error[2]")
  end

  def test_assign_multiple_card_types_when_create_property
    User.find_by_login('admin').with_current do
      setup_card_type(@project, BUG)
    end
    output = %x[curl -i -X POST -d "property_definition[name]=#{RELEASE}" -d "property_definition[data_type]=card" -d "property_definition[card_types][][name]=#{CARD}" -d "property_definition[card_types][][name]=#{BUG}" #{property_definitions_list_url}]
    release_property = @project.all_property_definitions.find_by_name(RELEASE)
    release_property_url = property_definition_url_for release_property

    output = %x[curl #{release_property_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal BUG, get_element_text_by_xpath(output, "//property_definition/card_types/card_type[1]/name")
    assert_equal CARD, get_element_text_by_xpath(output, "//property_definition/card_types/card_type[2]/name")
  end

  def test_property_should_not_be_assigned_to_any_card_type_by_default
    %x[curl -i -X POST -d "property_definition[name]=#{RELEASE}" -d "property_definition[data_type]=card" #{property_definitions_list_url}]
    release_property = @project.all_property_definitions.find_by_name(RELEASE)
    output = %x[curl #{property_definition_url_for release_property} | xmllint --format -].tap { |t| raise t.to_s unless $?.success? }
    assert_equal 0, get_number_of_elements(output, "//property_definition/card_types/card_type/").to_i
  end

  def test_property_description_should_be_blank_if_not_provided_during_creation
    %x[curl -i -X POST -d "property_definition[name]=#{RELEASE}" -d "property_definition[data_type]=card" #{property_definitions_list_url}]
    release_property = @project.all_property_definitions.find_by_name(RELEASE)

    output = %x[curl -i #{property_definition_url_for release_property}]
    assert_equal "true", get_attribute_by_xpath(output, "//property_definition/description/@nil")
  end

  def test_should_provide_data_type_when_create_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{STATUS}" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "You must provide the type of the property to create a card property.", get_element_text_by_xpath(output, "//errors/error/")
  end

  def test_error_message_when_provide_invalid_data_type
    output = %x[curl -i -X POST -d "property_definition[name]=#{STATUS}" -d "property_definition[data_type]=invalid" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "There is no such data type: invalid", get_element_text_by_xpath(output, "//errors/error/")
  end

  def test_name_of_property_should_not_contain_special_characters
    names_contain_special_chars = ['%26', '=', '#', '[', ']', 'hi%26combine]']
    names_contain_special_chars.each do |property_name|
      output = %x[curl -i -X POST -d "property_definition[name]=#{property_name}" -d "property_definition[data_type]=date" #{property_definitions_list_url}]
      assert_response_code(422, output)
      assert_equal "Name should not contain '&', '=', '#', '\"', ';', '[' and ']' characters", get_element_text_by_xpath(output, "//errors/error/")
    end
  end

  def test_can_not_create_property_with_name_belongs_to_existing_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{STATUS}" -d "property_definition[data_type]=date" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "Name has already been taken", get_element_text_by_xpath(output, "//errors/error/")
  end

  def test_length_of_property_name_should_be_no_more_than_40_characters
    long_name = 'h'*41
    output = %x[curl -i -X POST -d "property_definition[name]=#{long_name}" -d "property_definition[data_type]=date" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "Name is too long (maximum is 40 characters)", get_element_text_by_xpath(output, "//errors/error/")
  end

  def test_name_is_required_when_create_property
    output = %x[curl -i -X POST #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "You must provide the type of the property to create a card property.", get_element_text_by_xpath(output, "//errors/error/")

    output = %x[curl -i -X POST -d "property_definition[data_type]=date" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "Name can't be blank", get_element_text_by_xpath(output, "//errors/error/")

    output = %x[curl -i -X POST -d "property_definition[name]=" -d "property_definition[data_type]=date" #{property_definitions_list_url}]
    assert_response_code(422, output)
    assert_equal "Name can't be blank", get_element_text_by_xpath(output, "//errors/error/")
  end

  def test_only_mingle_and_proj_admin_can_create_property
    User.find_by_login('admin').with_current do
      @project.update_attribute(:anonymous_accessible, true)
      @project.save
    end

    change_license_to_allow_anonymous_access
    users = %w(member read_only_user) << nil

    users.each do |user|
      url = property_definitions_list_url :user => user
      output = %x[curl -i -X POST -d "property_definition[name]=owner" -d "property_definition[data_type]=user" #{url}]
      assert_response_code(403, output)
      assert_equal "Either the resource you requested does not exist or you do not have access rights to that resource.", get_element_text_by_xpath(output, "//errors/error")
    end

    url = property_definitions_list_url :user => "proj_admin"
    output = %x[curl -i -X POST -d "property_definition[name]=owner" -d "property_definition[data_type]=user" #{url}]
    assert_response_code(201, output)
  end

  def test_create_formula_property
    output = %x[curl -i -X POST -d "property_definition[name]=#{FORMULA}" -d "property_definition[data_type]=formula" -d "property_definition[formula]=size%2B1" #{property_definitions_list_url}]
    formula_property = @project.all_property_definitions.find_by_name(FORMULA)
    formula_property_url = property_definition_url_for formula_property

    assert_response_code(201, output)
    assert_response_includes(property_definition_url_for(formula_property, :user => nil), output)

    output = %x[curl -i #{formula_property_url}]
    assert_equal FORMULA, get_element_text_by_xpath(output, "//property_definition/name/")
    assert_equal "(size + 1)", get_element_text_by_xpath(output, "//property_definition/formula/")
  end

  def test_should_include_associated_card_types_in_property_resource
    status_property = @project.all_property_definitions.find_by_name(STATUS)
    output = %x[curl #{property_definition_url_for status_property} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    card_type = @project.card_types.find_by_name("Card")
    assert_equal "Card", get_element_text_by_xpath(output, "//property_definition/card_types/card_type/name")
    assert_equal card_type_url_for(card_type, :user => nil), get_attribute_by_xpath(output, "//property_definition/card_types/card_type/@url")
  end

  def test_all_user_can_get_property_definition_resource
    size = @project.find_property_definition(SIZE)
    User.find_by_login('admin').with_current do
      @project.update_attribute(:anonymous_accessible, true)
      @project.save
    end
    change_license_to_allow_anonymous_access

    users = %w(proj_admin member read_only_user) << nil
    users.each do |user|
      url = property_definitions_list_url :user => user
      output = %x[curl -i -X GET #{url}]
      assert_response_code(200, output)
      assert_response_includes('<property_definitions type="array">', output)
      assert_response_includes('<name>Size</name>', output)
      assert_response_includes('<name>status</name>', output)

      url = property_definition_url_for size, :user => user
      output = %x[curl -i -X GET #{url}]
      assert_response_code(200, output)
      assert_response_includes('<property_definition>', output)
      assert_response_includes('<name>Size</name>', output)
    end
  end

  def test_get_all_property_definition_resource
    output = %x[curl -X GET #{property_definitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal SIZE, get_element_text_by_xpath(output, "//property_definitions/property_definition[1]/name")
    assert_equal STATUS, get_element_text_by_xpath(output, "//property_definitions/property_definition[2]/name")
  end

  def test_get_per_property_definition_resource
    size = @project.find_property_definition(SIZE)
    size.update_attribute(:description, "this property indicates size of each card")

    url = property_definition_url_for size
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal SIZE, get_element_text_by_xpath(output, "//property_definition/name")
    assert_equal "this property indicates size of each card", get_element_text_by_xpath(output, "//property_definition/description")
    assert_equal "numeric", get_element_text_by_xpath(output, "//property_definition/data_type")
    assert_equal "true", get_element_text_by_xpath(output, "//property_definition/is_numeric")
    assert_equal "false", get_element_text_by_xpath(output, "//property_definition/hidden")
    assert_equal "false", get_element_text_by_xpath(output, "//property_definition/restricted")
    assert_equal "false", get_element_text_by_xpath(output, "//property_definition/transition_only")
    assert_equal "Managed number list", get_element_text_by_xpath(output, "//property_definition/property_values_description")
    assert_equal project_url(:user => nil), get_attribute_by_xpath(output, "//property_definition/project/@url")
    assert_equal @project.name, get_element_text_by_xpath(output, "//property_definition/project/name")
    assert_equal @project.identifier, get_element_text_by_xpath(output, "//property_definition/project/identifier")
    assert_equal size.id, get_element_text_by_xpath(output, "//property_definition/id").to_i
    assert_equal "true", get_attribute_by_xpath(output, "//property_definition/position/@nil")
  end

  def test_get_property_value_details_for_property
    # need to test id
    size = @project.find_property_definition(SIZE)
    url = property_definition_url_for size
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "2", get_element_text_by_xpath(output, "//property_definition/property_value_details/property_value[1]/value")
    assert Color.defaults.include?(get_element_text_by_xpath(output, "//property_definition/property_value_details/property_value[1]/color"))
    assert_equal "1", get_element_text_by_xpath(output, "//property_definition/property_value_details/property_value[1]/position")
  end

  def test_property_values_description_for_all_kinds_of_properties
    create_all_kinds_of_properties
    @project.reload
    properties={STATUS => "Managed text list", DATE => "Any date", SIZE => "Managed number list", TREE_PROPERTY => "Any card used in tree", ANY_TEXT => "Any text",
                USER => "Automatically generated from the team list", CARD_TYPE => "Any card", FORMULA => "Formula", ANY_NUMBER => "Any number", Aggregate => "Aggregate"}

    properties.each do |property_name, description|
      prop = @project.find_property_definition(property_name)
      url = property_definition_url_for prop
      output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_equal description, get_element_text_by_xpath(output, "/property_definition/property_values_description")
    end
  end

  def test_order_of_values_for_managed_text_and_number_property
    size = @project.find_property_definition(SIZE)
    url_size = property_definition_url_for size
    output_size = %x[curl -X GET #{url_size} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "2", get_element_text_by_xpath(output_size, "/property_definition/property_value_details/property_value/value[1]")
    assert_equal "4", get_element_text_by_xpath(output_size, "/property_definition/property_value_details/property_value/value[2]")

    status = @project.find_property_definition(STATUS)
    url_status = property_definition_url_for status
    output_status = %x[curl -X GET #{url_status} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "new", get_element_text_by_xpath(output_status, "/property_definition/property_value_details/property_value/value[1]")
    assert_equal "open", get_element_text_by_xpath(output_status, "/property_definition/property_value_details/property_value/value[2]")
  end

  def test_should_get_hidden_property
    property = @project.find_property_definition(STATUS)
    property.update_attributes(:hidden => true)

    property_url = property_definition_url_for property
    output = %x[curl -X GET #{property_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal STATUS, get_element_text_by_xpath(output, "/property_definition/name/")
    assert_equal "true", get_element_text_by_xpath(output, "/property_definition/hidden/")
  end

  def test_can_create_property_definition_with_associated_card_types
    @project.card_types.create(:name => 'ftory')
    @project.card_types.create(:name => 'gtory')
    %x[curl -X POST -i -d "property_definition[name]=our_new_prop_def" -d "property_definition[data_type]=string" -d "property_definition[is_managed]=true" -d "property_definition[card_types][][name]=ftory" -d "property_definition[card_types][][name]=gtory" #{property_definitions_list_url}]
    new_property_definition = @project.reload.find_property_definition('our_new_prop_def')
    assert_equal %w(ftory gtory), new_property_definition.card_types.map(&:name).sort
  end

  def create_all_kinds_of_properties
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_release = setup_card_type(@project, RELEASE)
    @tree = setup_tree(@project, 'simple tree', :types => [@type_release, @type_iteration], :relationship_names => [TREE_PROPERTY])
    create_allow_any_text_property(ANY_TEXT)
    create_allow_any_number_property(ANY_NUMBER)
    create_date_property(DATE)
    create_formula_property(FORMULA, 'Size*2')
    create_card_type_property(CARD_TYPE)
    create_team_property(USER)
    setup_aggregate_property_definition(AGGREGATE, AggregateType::COUNT, nil, @tree.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
  end

end
