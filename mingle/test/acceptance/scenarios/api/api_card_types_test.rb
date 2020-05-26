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

# Tags: api_version_2
class ApiCardTypesTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')], :users => [User.find_by_login('member')]) do |project|
        create_cards(project, 3)
        project.card_types.create :name => 'Bug'
      end
    end

    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    API::CardType.site = @url_prefix
    API::CardType.prefix = "/api/#{version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def version
    "v2"
  end

  def test_should_list_all_card_types
    assert_equal ['Bug', 'Card'], API::CardType.find(:all).collect(&:name).sort
  end

  def test_should_show_card_type
    card_type = @project.card_types.first
    assert_equal card_type.name, API::CardType.find(card_type.id).name
  end

  def test_should_allow_anonymous_user_access
    API::CardType.site = "http://localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"

    assert_equal ['Bug', 'Card'], API::CardType.find(:all).collect(&:name).sort
    card_type = @project.card_types.first

    assert_equal card_type.name, API::CardType.find(card_type.id).name
  end

  def test_should_be_able_to_create_card_type
    new_type = "story"
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => new_type})
    assert_equal new_type, @project.card_types.find_by_name(new_type).name
  end

  def test_create_card_type_returns_location_of_new_card_type_in_header
    new_type = "story"
    result = post(@url_prefix + "/card_types.xml", {"card_type[name]" => new_type})
    new_card_type = @project.card_types.find_by_name(new_type)
    assert_match /http:\/\/localhost:\d+\/api\/v\d\/projects\/#{@project.identifier}\/card_types\/#{new_card_type.id}.xml/, result.header['location']
  end

  def test_creating_card_type_should_not_associate_any_properties
    setup_text_property_definition('status')
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => "new type"})
    created_card_type = @project.card_types.find_by_name('new type')
    assert_equal [], created_card_type.property_definitions
  end

  def test_should_be_able_to_create_card_type_with_color
    color = "#000000"
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => "new type", "card_type[color]" => color})
    assert_equal color, @project.card_types.find_by_name('new type').color
  end

  def test_can_create_card_type_with_associated_property
    status_property = setup_text_property_definition('status')
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => "new type", "card_type[property_definitions][][name]" => 'status'})
    assert_equal ['status'], @project.card_types.find_by_name('new type').property_definitions.map(&:name)
  end

  def test_can_create_card_type_with_associated_property_using_property_name_with_different_casing
    status_property = setup_text_property_definition('status')
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => "new type", "card_type[property_definitions][][name]" => 'STAtus'})
    assert_equal ['status'], @project.card_types.find_by_name('new type').property_definitions.map(&:name)
  end

  def test_should_give_error_when_trying_to_create_duplicate_card_types
    body = post(@url_prefix + "/card_types.xml", {"card_type[name]" => "Bug"}).body
    assert_equal 'Name has already been taken', get_element_text_by_xpath(body, '/errors/error')
  end

  def test_should_give_error_when_trying_to_create_card_type_with_non_existing_property_definitions
    non_exist_prop = "non-existing property"
    body = post(@url_prefix + "/card_types.xml", {"card_type[name]" => "new type", "card_type[property_definitions][][name]" => non_exist_prop}).body
    assert_equal "There is no such property: #{non_exist_prop}", get_element_text_by_xpath(body, '/errors/error')
    assert_nil @project.card_types.find_by_name('new type')
  end

  def test_should_put_new_card_type_in_position_alphabetically
    @project.card_types.create :name => 'Zoo'
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => "Gong"})
    assert_equal ['Bug', 'Card', 'Gong', 'Zoo'], @project.card_types.reload.map(&:name)
  end

  def test_should_not_take_position_parameter_when_creating_new_card_type
    @project.card_types.create :name => 'Zoo'
    post(@url_prefix + "/card_types.xml", {"card_type[name]" => "Gong", "card_type[position]" => 1})
    assert_equal ['Bug', 'Card', 'Gong', 'Zoo'], @project.card_types.reload.map(&:name)
  end

  def test_read_only_users_cannot_create_card_type
    response = post("http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}" + "/card_types.xml", {"card_type[name]" => "Gong"})
    assert_nil @project.card_types.find_by_name('Gong')
    assert_equal "403", response.code
  end

  def test_non_admin_project_members_cannot_create_card_type
    response = post("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}" + "/card_types.xml", {"card_type[name]" => "Gong"})
    assert_nil @project.card_types.find_by_name('Gong')
    assert_equal "403", response.code
  end

  # bug 9046
  def test_should_give_error_when_trying_to_create_card_type_with_no_card_type_parameters
    body = post(@url_prefix + "/card_types.xml", {}).body
    assert_equal "Name can't be blank", get_element_text_by_xpath(body, '/errors/error')
  end

  #bug 9984
  def test_should_have_a_root_element_of_card_types
    body = get(@url_prefix + "/card_types.xml", {}).body
    assert_not_nil get_element_text_by_xpath(body, "/card_types")
  end

end


class ApiCardTypeJsonTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')], :users => [User.find_by_login('member')]) do |project|
        create_cards(project, 3)
        project.card_types.create :name => 'Bug'
      end
    end

    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
  end

  def teardown
    disable_basic_auth
  end

  def version
    "v2"
  end

  def test_should_respond_as_json_for_list
    body = get(@url_prefix + '/card_types.json', {}).body
    expected_card_types =  @project.card_types.collect { |card_type| {'id' => card_type.id, 'name' => card_type.name, 'color' => card_type.color, 'position' => card_type.position, 'propertyDefinitions' =>[]} }

    assert_equal(expected_card_types.sort_by { |ct| ct['id'] }, JSON.parse(body).sort_by { |ct| ct['id'] })
  end

  def test_should_respond_as_json_for_show
    card_type = @project.card_types.first
    body = get(@url_prefix + "/card_types/#{card_type.id}.json", {}).body
    expected_card_type = {'id' => card_type.id, 'name' => card_type.name, 'color' => card_type.color, 'position' => card_type.position, 'propertyDefinitions' =>[]}

    assert_equal(expected_card_type, JSON.parse(body))
  end

  def test_should_have_property_value_details_when_include_property_value_flag_is_set
    card_type = @project.card_types.first
    property_definition = @project.create_text_list_definition!(:name => 'Status')
    card_type.add_property_definition property_definition
    property_definition.save!
    property_values = ['To Do','Doing','Done'].map do |value|
      EnumerationValue.create!(:nature_reorder_disabled => true, :value => value, :property_definition_id => property_definition.id)
    end
    expected_property_values = property_values.collect {|pv| {'id' => pv.id, 'value' => pv.value, 'color' => pv.color, 'position' => pv.position}}

    body = get(@url_prefix + "/card_types/#{card_type.id}.json", {include_property_values: true}).body

    assert_equal(expected_property_values, JSON.parse(body)['propertyDefinitions'][0]['propertyValueDetails'])
  end

  def test_should_have_project_level_variables_when_include_property_value_flag_is_set
    user_property_definition =  setup_user_definition 'dev'
    card_type = user_property_definition.card_types.first
    plv = '(current user)'
    create_plv!(@project, :name => plv, :data_type => ProjectVariable::USER_DATA_TYPE)

    body = get(@url_prefix + "/card_types/#{card_type.id}.json", {include_property_values: true}).body

    assert_equal([[plv, plv]], JSON.parse(body)['propertyDefinitions'][0]['projectLevelVariableOptions'])
  end
end
