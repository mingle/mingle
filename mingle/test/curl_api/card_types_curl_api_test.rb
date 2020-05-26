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
class CardTypesCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  STATUS = 'Status'
  HIDDEN = 'Hidden'
  STORY = 'Story'
  ITERATION = 'iteration'
  BUG = 'bug'
  CARD = 'Card'
  SIZE = 'size'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'CardTypes', :admins => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
        setup_property_definitions(STATUS => ['new', 'open'])
        setup_numeric_property_definition(SIZE, [2, 4])
        setup_card_type(project, STORY, :properties => [STATUS])
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_position_for_card_types
    output = %x[curl -X POST -d "card_type[name]=#{BUG}" #{card_types_list_url}]
    card_type = @project.card_types.find_by_name(BUG)
    output = %x[curl #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "1", get_element_text_by_xpath(output, "//card_type/position/")
  end

  def test_color_for_card_type_should_be_set_to_a_random_color_by_default
    output = %x[curl -X POST -d "card_type[name]=#{BUG}" #{card_types_list_url}]
    card_type = @project.card_types.find_by_name(BUG)
    output = %x[curl #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert Color.defaults.include?(get_element_text_by_xpath(output, "//card_type/color"))
  end

  def test_no_property_should_be_associated_to_card_type_if_admin_did_not_provide_property_information
    output = %x[curl -X POST -d "card_type[name]=#{BUG}" #{card_types_list_url}]
    card_type = @project.card_types.find_by_name(BUG)
    output = %x[curl #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "\n  ", get_element_text_by_xpath(output, "//card_type/property_definitions/")
  end

  def test_try_to_associate_non_existing_property_when_create_card_type
    output = %x[curl -X POST -i -d "card_type[name]=#{ITERATION}" -d "card_type[property_definitions][][name]=non existing property" #{card_types_list_url}]
    assert_response_code(422, output)
    assert_equal "There is no such property: non existing property", get_element_text_by_xpath(output, "//errors/error")
  end

  def test_associate_properties_when_create_card_type
    xpath_property_names = "//card_type/property_definitions/property_definition/name"

    output = %x[curl -X POST -d "card_type[name]=#{BUG}" -d "card_type[property_definitions][][name]=#{STATUS}" #{card_types_list_url}]
    card_type = @project.card_types.find_by_name(BUG)
    output = %x[curl #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal STATUS, get_element_text_by_xpath(output, xpath_property_names)

    output = %x[curl -X POST -d "card_type[name]=#{ITERATION}" -d "card_type[property_definitions][][name]=#{STATUS}" -d "card_type[property_definitions][][name]=#{SIZE}"  #{card_types_list_url}]
    card_type = @project.card_types.find_by_name(ITERATION)
    output = %x[curl #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    actual = get_elements_text_by_xpath(output, xpath_property_names).sort
    expected = [STATUS, SIZE].sort

    assert_equal expected, actual, "Expected the following #{expected.inspect} at XPATH: #{xpath_property_names}\n\n#{output}"
  end

  def test_error_message_when_create_card_type_without_card_type_name
    output = %x[curl -X POST -i -d "card_type[name]=" #{card_types_list_url}]
    assert_response_code(422, output)
    assert_equal "Name can't be blank", get_element_text_by_xpath(output, "//errors/error")

    output = %x[curl -X POST -i -d 'card_type[name]=Card' #{card_types_list_url}]
    assert_response_code(422, output)
    assert_equal "Name has already been taken", get_element_text_by_xpath(output, "//errors/error")
  end

  def test_only_admin_can_create_card_type
    User.find_by_login('admin').with_current do
      @project.update_attribute(:anonymous_accessible, true)
      @project.save
    end
    change_license_to_allow_anonymous_access

    url= card_types_list_url :user => nil
    output = %x[curl -X POST -i -d "card_type[name]=test" #{url}]
    assert_response_code(403, output)

    url= card_types_list_url :user => "member"
    output = %x[curl -X POST -i -d "card_type[name]=test" #{url}]
    assert_response_code(403, output)

    url= card_types_list_url :user => "read_only_user"
    output = %x[curl -X POST -i -d "card_type[name]=test" #{url}]
    assert_response_code(403, output)

    url= card_types_list_url :user => "proj_admin"
    output = %x[curl -X POST -i -d "card_type[name]=test" #{url}]
    assert_response_code(201, output)
  end

  def test_mingle_admin_and_project_admin_can_create_card_type
    output = %x[curl -X POST -i -d "card_type[name]=#{BUG}" #{card_types_list_url}]
    card_type = @project.card_types.find_by_name(BUG)
    assert_response_code 201, output
    assert_response_includes "Location: #{card_type_url_for card_type, :user => nil}", output

    output = %x[curl -X GET #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "#{card_type.id}", get_element_text_by_xpath(output, "//card_type/id")
    assert_equal BUG, get_element_text_by_xpath(output, "//card_type/name")
    assert Color.defaults.include?(get_element_text_by_xpath(output, "//card_type/color"))
    assert_equal "1", get_element_text_by_xpath(output, "//card_type/position")
    assert_equal "\n  ", get_element_text_by_xpath(output, "//card_type/property_definitions")
  end

  def test_all_user_can_get_card_type_resource
    card_type = @project.card_types.find_by_name(CARD)

    User.find_by_login('admin').with_current do
      @project.update_attribute(:anonymous_accessible, true)
      @project.save
    end
    change_license_to_allow_anonymous_access

    users = %w(proj_admin member read_only_user) << nil
    users.each do |user|
      output = %x[curl -i -X GET #{card_types_list_url :user => user}]
      assert_response_code(200, output)
      assert_response_includes('<name>Card</name>', output)
      assert_response_includes('property_definition url', output)

      output = %x[curl -i -X GET #{card_type_url_for card_type, :user => user}]
      assert_response_code(200, output)
      assert_response_includes('<name>Card</name>', output)
      assert_response_includes('property_definition url', output)
    end
  end

  def test_get_resource_for_per_card_type
    card_type = @project.card_types.find_by_name(CARD)

    url = "#{card_type_url_for card_type}"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<id type="integer">'+"#{card_type.id}</id>", output)
    assert_response_includes('<name>Card</name>', output)
    assert_response_includes('<color>', output)
    assert_response_includes('<position type="integer">'+"#{card_type.position}</position>", output)
    assert_response_includes('<property_definitions type="array">', output)
  end

  # bug 9984
  def test_get_all_card_types_and_order_of_card_types
    card=@project.card_types.find_by_name(CARD)
    story=@project.card_types.find_by_name(STORY)

    output = %x[curl -X GET #{card_types_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<card_types type="array">', output)
    card_type_1 = output.index("#{card.id}</id>")
    card_type_2 = output.index("#{story.id}</id>")
    assert card_type_2 > card_type_1
  end

  def test_should_return_all_properties_for_per_card_type
    card_type = @project.card_types.find_by_name(CARD)
    status = @project.find_property_definition(STATUS)
    size = @project.find_property_definition(SIZE)

    output = %x[curl -X GET #{card_type_url_for card_type} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes(property_definition_url_for(size, :user => nil), output)
    assert_response_includes("<name>#{size.name}</name>", output)
    assert_response_includes('<position nil="true"/>', output)
    assert_response_includes('<data_type>numeric</data_type>', output)
    assert_response_includes('<is_numeric type="boolean">true</is_numeric>', output)

    status_location = output.index("property_definitions/#{status.id}.xml")
    size_location = output.index("property_definitions/#{size.id}.xml")
    assert size_location > status_location
  end

  def test_get_card_types_should_include_hidden_property_via_api_v2_format
    property = @project.find_property_definition(STATUS)
    User.find_by_login('admin').with_current do
      property.update_attributes(:hidden => true)
    end

    output = %x[curl -X GET #{card_types_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /Status/ && output =~ /size/, "Expected properties are not listed."
  end

end
