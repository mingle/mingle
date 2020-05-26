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

class TransitionApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  STATUS = 'Status'
  SIZE = 'size'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)

    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Transitions_API', :admins => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
        @text_property = setup_managed_text_definition(STATUS, %w(new open))
        @numeric_property = setup_numeric_property_definition(SIZE, [2, 4])
        @card_1 = create_card!(:name => "card_1")
        @card_2 = create_card!(:name => "card_2")
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  # bug 10584
  def test_response_when_no_transtions
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_include('<transitions type="array"/>', output)
  end

  def test_should_include_groups_in_transition
    ba_group = Project.current.groups.create!(:name => "BAs")
    qa_group = Project.current.groups.create!(:name => "QAs")
    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'not set'}, :group_prerequisites => [ba_group.id, qa_group.id])

    output = %x[curl -X GET #{transition_url_for(new_transition)} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    groups_in_response = get_all_groups_in_transition(output)
    assert_equal 2, groups_in_response.size
    expected_groups = [ba_group, qa_group]
    expected_groups.each do |group|
      assert_group_returned_in_response(groups_in_response, group)
    end
  end

  def test_newly_assigned_groups_should_be_displayed_in_transition
    ba_group = create_group_and_add_its_members('BAs', [@team_member])
    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'open'}, :group_prerequisites => [ba_group.id])
    qa_group = create_group_and_add_its_members('QAs', [@project_admin])
    new_transition.add_group_prerequisites([qa_group.id])
    new_transition.reload

    output = %x[curl -X GET #{transition_url_for(new_transition)} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    groups_in_response = get_all_groups_in_transition(output)
    assert_equal 2, groups_in_response.size

    assert_group_returned_in_response(groups_in_response, qa_group)
  end

  def test_deleted_group_should_be_removed_from_transition
    ba_group = create_group_and_add_its_members('BAs', [@team_member])
    qa_group = create_group_and_add_its_members('QAs', [@project_admin])
    create_transition(@project, 'sample transition', :set_properties => {STATUS => 'open'}, :group_prerequisites => [ba_group.id, qa_group.id])
    ba_group.destroy

    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    groups_in_response = get_all_groups_in_transition(output)
    assert_equal 1, groups_in_response.size
    assert_group_returned_in_response(groups_in_response, qa_group)
  end

  def test_updated_groups_should_be_reflected_in_transiton
    ba_group = create_group_and_add_its_members('BAs', [@team_member])
    ba_group_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups/#{ba_group.id}.xml"

    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'open'}, :group_prerequisites => [ba_group.id])
    @mingle_admin.with_current do
      ba_group.update_attributes(:name => 'QAs')
      @project.save!
    end
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'QAs', get_element_text_by_xpath(output, "//transitions/transition/only_available_for_groups/group/name")
    assert_equal ba_group_url, get_attribute_by_xpath(output, "//transitions/transition/only_available_for_groups/group/@url")
  end


  def test_should_include_groups_when_get_transitions_avaliable_for_card
    ba_group = create_group_and_add_its_members('BAs', [@team_member])
    ba_group_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups/#{ba_group.id}.xml"

    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'open'}, :group_prerequisites => [ba_group.id])
    output = %x[curl -X GET http://#{@team_member.login}:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1/transitions.xml | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal ba_group.name, get_element_text_by_xpath(output, "//transitions/transition/only_available_for_groups/group/name")
    assert_equal ba_group_url, get_attribute_by_xpath(output, "//transitions/transition/only_available_for_groups/group/@url")
  end

  def test_should_include_groups_when_get_all_transitions
    ba_group = Project.current.groups.create!(:name => "BAs")
    ba_group_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups/#{ba_group.id}.xml"

    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'not set'}, :group_prerequisites => [ba_group.id])
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal ba_group.name, get_element_text_by_xpath(output, "//transitions/transition/only_available_for_groups/group/name")
    assert_equal ba_group_url, get_attribute_by_xpath(output, "//transitions/transition/only_available_for_groups/group/@url")
  end


  def test_should_be_able_to_get_transition_when_property_is_set_to_a_special_value
    new_transition = create_transition(@project, 'transition_avatar', :required_properties => {STATUS => "(set)"}, :set_properties => {STATUS => "(not set)"})

    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")

    assert_equal new_transition.id, get_element_text_by_xpath(output, "//transitions/transition/id").to_i
    assert_equal 'transition_avatar', get_element_text_by_xpath(output, "//transitions/transition/name")
    assert_equal 'false', get_element_text_by_xpath(output, "//transitions/transition/require_comment")
    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties_set/property_definition/name")
    assert_equal 'new', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties_set/property_definition/property_value_details/property_value[1]/value")
    assert_equal 'open', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties_set/property_definition/property_value_details/property_value[2]/value")

    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/name")
    assert_equal "(not set)", get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value")
  end

  def test_should_be_able_to_get_transition_when_using_text_property
    new_transition = create_transition(@project, 'transition_avatar', :required_properties => {STATUS => 'open'}, :set_properties => {STATUS => 'new'})
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal new_transition.id, get_element_text_by_xpath(output, "//transitions/transition/id").to_i
    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/name")
    assert_equal 'open', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/value")

    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/name")
    assert_equal 'new', get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value")
  end

  def test_should_be_able_to_get_transition_when_using_number_property
    new_transition = create_transition(@project, 'transition_avatar', :required_properties => {SIZE => 2}, :set_properties => {SIZE => 4})
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal new_transition.id, get_element_text_by_xpath(output, "//transitions/transition/id").to_i
    assert_equal SIZE, get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/name")
    assert_equal "2", get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/value")

    assert_equal SIZE, get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/name")
    assert_equal "4", get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value")
  end

  def test_should_be_able_to_get_transition_when_using_user_property
    user_property = setup_user_definition("owner")

    new_transition = create_transition(@project, 'transition_avatar', :required_properties => {"owner" => @team_member.id}, :set_properties => {"owner" => '(current user)'})
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal new_transition.id, get_element_text_by_xpath(output, "//transitions/transition/id").to_i

    assert_equal "owner", get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/name")
    assert_equal @team_member.name, get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/value/name")
    assert_equal @team_member.login, get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/value/login")

    assert_equal "owner", get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/name")
    assert_equal @mingle_admin.name, get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value/name")
    assert_equal @mingle_admin.login, get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value/login")
  end

  def test_should_be_able_to_get_transition_when_using_date_property
    date_property = setup_date_property_definition('expiration_date')
    new_transition = create_transition(@project, 'transition_avatar', :required_properties => {'expiration_date' => '2008-09-30'}, :set_properties => {'expiration_date' => '2012-09-30'})
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal new_transition.id, get_element_text_by_xpath(output, "//transitions/transition/id").to_i

    assert_equal 'expiration_date', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/name")

    assert_equal '2008-09-30', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/value")
    assert_equal 'expiration_date', get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/name")
    assert_equal '2012-09-30', get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value")
  end

  def test_should_be_able_to_get_transition_when_using_card_type_property
    card_property = setup_card_relationship_property_definition('card_related')

    new_transition = create_transition(@project, 'transition_avatar', :required_properties => {'card_related' => @card_1.id}, :set_properties => {'card_related' => @card_2.id})
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal new_transition.id, get_element_text_by_xpath(output, "//transitions/transition/id").to_i

    assert_equal 'card_related', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/name")
    assert_equal "#{@card_1.number}", get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/value/number")

    assert_equal 'card_related', get_element_text_by_xpath(output, "//transitions/transition/if_card_has_properties/property/name")
    assert_equal "#{@card_2.number}", get_element_text_by_xpath(output, "//transitions/transition/will_set_card_properties/property/value/number")
  end

  def test_should_be_able_to_get_transition_when_using_plv
    user_property = setup_user_definition("owner")
    date_property = setup_date_property_definition('expiration_date')
    card_property = setup_card_relationship_property_definition('card_related')

    create_plv!(@project, :name => "number_plv", :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => "2", :property_definition_ids => [@numeric_property.id])
    create_plv!(@project, :name => 'text_plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'open', :property_definition_ids => [@text_property.id.to_s])
    create_plv!(@project, :name => 'user_plv', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @team_member.id, :property_definition_ids => [user_property.id])
    create_plv!(@project, :name => 'date_plv', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '2008-09-30', :property_definition_ids => [date_property.id])
    create_plv!(@project, :name => 'card_plv', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => @card_1.id, :property_definition_ids => [card_property.id])
    transition_1 = create_transition(@project, "aa", :required_properties => {SIZE => "(number_plv)"}, :set_properties => {SIZE => "2"})
    transition_2 = create_transition(@project, "bb", :required_properties => {STATUS => "(text_plv)"}, :set_properties => {STATUS => 'new'})
    transition_3 = create_transition(@project, "cc", :required_properties => {"owner" => "(user_plv)"}, :set_properties => {"owner" => @project_admin.id})
    transition_4 = create_transition(@project, "dd", :required_properties => {'expiration_date' => "(date_plv)"}, :set_properties => {'expiration_date' => '2012-09-30'})
    transition_5 = create_transition(@project, "ee", :required_properties => {'card_related' => "(card_plv)"}, :set_properties => {'card_related' => @card_2.id})

    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal transition_1.id, get_element_text_by_xpath(output, "//transitions/transition[1]/id").to_i
    assert_equal transition_2.id, get_element_text_by_xpath(output, "//transitions/transition[2]/id").to_i
    assert_equal transition_3.id, get_element_text_by_xpath(output, "//transitions/transition[3]/id").to_i
    assert_equal transition_4.id, get_element_text_by_xpath(output, "//transitions/transition[4]/id").to_i
    assert_equal transition_5.id, get_element_text_by_xpath(output, "//transitions/transition[5]/id").to_i

    assert_equal SIZE, get_element_text_by_xpath(output, "//transitions/transition[1]/if_card_has_properties/property/name")
    assert_equal "2", get_element_text_by_xpath(output, "//transitions/transition[1]/if_card_has_properties/property/value")

    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition[2]/if_card_has_properties/property/name")
    assert_equal 'open', get_element_text_by_xpath(output, "//transitions/transition[2]/if_card_has_properties/property/value")

    assert_equal @team_member.name, get_element_text_by_xpath(output, "//transitions/transition[3]/if_card_has_properties/property/value/name")
    assert_equal @team_member.login, get_element_text_by_xpath(output, "//transitions/transition[3]/if_card_has_properties/property/value/login")

    assert_equal 'expiration_date', get_element_text_by_xpath(output, "//transitions/transition[4]/if_card_has_properties/property/name")
    assert_equal '2008-09-30', get_element_text_by_xpath(output, "//transitions/transition[4]/if_card_has_properties/property/value")

    assert_equal 'card_related', get_element_text_by_xpath(output, "//transitions/transition[5]/if_card_has_properties/property/name")
    assert_equal "#{@card_1.number}", get_element_text_by_xpath(output, "//transitions/transition[5]/if_card_has_properties/property/value/number")
  end

  def test_should_be_able_to_get_transition_when_specify_card_type_in_transtions
    User.find_by_login('admin').with_current do
      user_property = setup_user_definition("owner")
      date_property = setup_date_property_definition('expiration_date')
      card_property = setup_card_relationship_property_definition('card_related')

      @story_card_type = setup_card_type(@project, 'Story', :properties => [STATUS, SIZE, "owner", 'expiration_date', 'card_related'])
    end

    card_type = @project.card_types.find_by_name("Card")
    transition_1 = create_transition(@project, "aa", :card_type => card_type, :required_properties => {STATUS => 'open', SIZE => 2}, :set_properties => {STATUS => 'new', SIZE => 4})
    transition_2 = create_transition(@project, "bb", :card_type => @story_card_type, :required_properties => {"owner" => @team_member.id}, :set_properties => {"owner" => '(current user)'}, :require_comment => true)
    transition_3 = create_transition(@project, "cc", :card_type => @story_card_type, :required_properties => {'expiration_date' => '2008-09-30'}, :set_properties => {'expiration_date' => '2012-09-30'})
    transition_4 = create_transition(@project, "dd", :card_type => @story_card_type, :required_properties => {'card_related' => @card_1.id}, :set_properties => {'card_related' => @card_2.id}, :user_prerequisites => [@team_member.id])
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal transition_1.id, get_element_text_by_xpath(output, "//transitions/transition[1]/id").to_i
    assert_equal transition_1.name, get_element_text_by_xpath(output, "//transitions/transition[1]/name")

    assert_equal 'false', get_element_text_by_xpath(output, "//transitions/transition[1]/require_comment")
    required_propoerty_names = get_elements_text_by_xpath(output, "//transitions/transition[1]/if_card_has_properties/property/name")
    required_propoerty_values = get_elements_text_by_xpath(output, "//transitions/transition[1]/if_card_has_properties/property/value")
    assert_equal 2, required_propoerty_names.size
    assert_equal 2, required_propoerty_values.size
    assert_equal required_propoerty_names.index(STATUS), required_propoerty_values.index('open')
    assert_equal required_propoerty_names.index(SIZE), required_propoerty_values.index('2')

    assert_equal 'Card', get_element_text_by_xpath(output, "//transitions/transition[1]/card_type/name")
    assert_equal transition_2.id, get_element_text_by_xpath(output, "//transitions/transition[2]/id").to_i
    assert_equal transition_2.name, get_element_text_by_xpath(output, "//transitions/transition[2]/name")
    assert_equal 'true', get_element_text_by_xpath(output, "//transitions/transition[2]/require_comment")

    assert_equal "owner", get_element_text_by_xpath(output, "//transitions/transition[2]/if_card_has_properties/property/name")
    assert_equal @team_member.name, get_element_text_by_xpath(output, "//transitions/transition[2]/if_card_has_properties/property/value/name")
    assert_equal @team_member.login, get_element_text_by_xpath(output, "//transitions/transition[2]/if_card_has_properties/property/value/login")

    assert_equal "owner", get_element_text_by_xpath(output, "//transitions/transition[2]/will_set_card_properties/property/name")
    assert_equal @mingle_admin.name, get_element_text_by_xpath(output, "//transitions/transition[2]/will_set_card_properties/property/value/name")
    assert_equal @mingle_admin.login, get_element_text_by_xpath(output, "//transitions/transition[2]/will_set_card_properties/property/value/login")
    assert_equal 'Story', get_element_text_by_xpath(output, "//transitions/transition[2]/card_type/name")

    assert_equal transition_3.id, get_element_text_by_xpath(output, "//transitions/transition[3]/id").to_i
    assert_equal transition_3.name, get_element_text_by_xpath(output, "//transitions/transition[3]/name")
    assert_equal 'expiration_date', get_element_text_by_xpath(output, "//transitions/transition[3]/if_card_has_properties/property/name")
    assert_equal '2008-09-30', get_element_text_by_xpath(output, "//transitions/transition[3]/if_card_has_properties/property/value")

    assert_equal 'expiration_date', get_element_text_by_xpath(output, "//transitions/transition[3]/will_set_card_properties/property/name")
    assert_equal '2012-09-30', get_element_text_by_xpath(output, "//transitions/transition[3]/will_set_card_properties/property/value")
    assert_equal 'Story', get_element_text_by_xpath(output, "//transitions/transition[3]/card_type/name")

    assert_equal transition_4.id, get_element_text_by_xpath(output, "//transitions/transition[4]/id").to_i
    assert_equal transition_4.name, get_element_text_by_xpath(output, "//transitions/transition[4]/name")
    assert_equal 'card_related', get_element_text_by_xpath(output, "//transitions/transition[4]/if_card_has_properties/property/name")
    assert_equal "#{@card_1.number}", get_element_text_by_xpath(output, "//transitions/transition[4]/if_card_has_properties/property/value/number")

    assert_equal 'card_related', get_element_text_by_xpath(output, "//transitions/transition[4]/will_set_card_properties/property/name")
    assert_equal "#{@card_2.number}", get_element_text_by_xpath(output, "//transitions/transition[4]/will_set_card_properties/property/value/number")
    assert_equal 'Story', get_element_text_by_xpath(output, "//transitions/transition[4]/card_type/name")
    assert_equal @team_member.name, get_element_text_by_xpath(output, "//transitions/transition[4]/only_available_for_users/user/name")
    assert_equal @team_member.login, get_element_text_by_xpath(output, "//transitions/transition[4]/only_available_for_users/user/login")
  end

  def test_should_be_get_transtion_when_set_value_to_user_input_required
    transition_1 = create_transition(@project, "aa", :required_properties => {STATUS => 'open', SIZE => 2}, :set_properties => {STATUS => Transition::USER_INPUT_REQUIRED})
    transition_1 = create_transition(@project, "bb", :required_properties => {STATUS => 'open', SIZE => 2}, :set_properties => {STATUS => Transition::USER_INPUT_OPTIONAL})
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition[1]/user_input_required/property_definition/name")
    assert_equal "string", get_element_text_by_xpath(output, "//transitions/transition[1]/user_input_required/property_definition/data_type")

    assert_equal STATUS, get_element_text_by_xpath(output, "//transitions/transition[2]/user_input_optional/property_definition/name")
    assert_equal "string", get_element_text_by_xpath(output, "//transitions/transition[2]/user_input_optional/property_definition/data_type")
  end

  def test_should_be_get_transtion_when_set_value_to_tree_property
    type_release = setup_card_type(@project, 'Release', :properties => [STATUS, SIZE])
    type_iteration = setup_card_type(@project, 'Iteration', :properties => [STATUS, SIZE])
    type_task = setup_card_type(@project, 'Task', :properties => [SIZE, STATUS])
    planning_tree = setup_tree(@project, 'planning tree', :types => [type_release, type_iteration, type_task], :relationship_names => ['release-iteration', 'iteration-task', 'task-story'])

    transition_1 = create_transition(@project, "aa", :card_type => type_iteration, :remove_from_trees => [planning_tree])
    transition_2 = create_transition(@project, "bb", :card_type => type_iteration, :remove_from_trees_with_children => [planning_tree])
    output = %x[curl -X GET #{transitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//transitions")
    assert_equal transition_1.id, get_element_text_by_xpath(output, "//transitions/transition[1]/id").to_i
    assert_equal transition_1.name, get_element_text_by_xpath(output, "//transitions/transition[1]/name")
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/transition_executions/#{transition_1.id}.xml", get_element_text_by_xpath(output, "//transitions/transition[1]/transition_execution_url")
    assert_equal 'false', get_element_text_by_xpath(output, "//transitions/transition[1]/require_comment")
    assert_equal 'Iteration', get_element_text_by_xpath(output, "//transitions/transition[1]/card_type/name")
    assert_equal 'planning tree', get_element_text_by_xpath(output, "//transitions/transition[1]/to_remove_from_trees_without_children/tree_name")

    assert_equal transition_2.id, get_element_text_by_xpath(output, "//transitions/transition[2]/id").to_i
    assert_equal transition_2.name, get_element_text_by_xpath(output, "//transitions/transition[2]/name")
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/transition_executions/#{transition_2.id}.xml", get_element_text_by_xpath(output, "//transitions/transition[2]/transition_execution_url")
    assert_equal 'false', get_element_text_by_xpath(output, "//transitions/transition[2]/require_comment")
    assert_equal 'Iteration', get_element_text_by_xpath(output, "//transitions/transition[2]/card_type/name")
    assert_equal 'planning tree', get_element_text_by_xpath(output, "//transitions/transition[2]/to_remove_from_trees_with_children/tree_name")
  end

  def test_should_be_able_to_get_transition_by_its_id
    transition = create_transition(@project, "aa", :required_properties => {STATUS => 'open', SIZE => 2}, :set_properties => {STATUS => 'new', SIZE => 4})
    output = %x[curl -X GET #{transition_url_for(transition)} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_equal 1, get_number_of_elements(output, "//transition")
    assert_equal transition.id, get_element_text_by_xpath(output, "//transition/id").to_i
    assert_equal transition.name, get_element_text_by_xpath(output, "//transition/name")
    assert_equal "false", get_element_text_by_xpath(output, "//transition/require_comment")

    expected_url = transition_execution_url_for transition, :user => nil
    actual_url = get_element_text_by_xpath(output, "//transition/transition_execution_url")

    assert_equal expected_url, actual_url
  end

  private

  def get_all_groups_in_transition(output)
    groups = {}
    number_of_groups_in_response = get_number_of_elements(output, "//transition/only_available_for_groups/group")

    if number_of_groups_in_response > 1
      number_of_groups_in_response.downto(1) do |count|
        group_name = get_element_text_by_xpath(output, "//transition/only_available_for_groups/group[#{count}]/name")
        group_url = get_attribute_by_xpath(output, "//transition/only_available_for_groups/group[#{count}]/@url")
        groups[group_name] = group_url
      end
    else
      group_name = get_element_text_by_xpath(output, "//transition/only_available_for_groups/group/name")
      group_url = get_attribute_by_xpath(output, "//transitions/transition/only_available_for_groups/group/@url")
      groups[group_name] = group_url
    end
    groups
  end

  def assert_group_returned_in_response(groups_in_response, expected_group)
    expected_group_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/groups/#{expected_group.id}.xml"

    unless groups_in_response.index(expected_group_url)
      raise "#{expected_group.name} is not listed in transition response"
    end

    assert_equal expected_group.name, groups_in_response.index(expected_group_url)
  end

end
