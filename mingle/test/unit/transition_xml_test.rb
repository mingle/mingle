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

#Tags: transition, xmlserialize
class TransitionXmlTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, TreeFixtures::FeatureTree

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_transition_to_xml_should_include_name_and_id
    xml, transition = card_transition_xml(@project, 'close', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    assert_equal transition.name, get_element_text_by_xpath(xml, "//transition/name")
    assert_equal transition.id.to_s, get_element_text_by_xpath(xml, "//transition/id")
  end

  def test_transition_to_xml_should_include_require_comment_property
    require_none_comment_xml, _ = card_transition_xml(@project, 'require no comment', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    assert_equal 'false', get_element_text_by_xpath(require_none_comment_xml, "//transition/require_comment")

    require_comment_xml, _ = card_transition_xml(@project, 'require comment', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL}, :require_comment => true)
    assert_equal 'true', get_element_text_by_xpath(require_comment_xml, "//transition/require_comment")
  end

  def test_transition_to_xml_should_include_requires_user_to_enter_properties
    xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    assert_equal 'Status', get_element_text_by_xpath(xml, "//transition/user_input_required/property_definition/name")
  end

  def test_transition_to_xml_should_include_optionally_requires_user_to_enter_properties
    xml, _ = card_transition_xml(@project, 'change status', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    assert_equal 'Status', get_element_text_by_xpath(xml, "//transition/user_input_optional/property_definition/name")
  end

  def test_transition_to_xml_should_include_transition_execution_url
    xml, transition = card_transition_xml(@project, 'change status', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    expected_execution_url = "http://example.com/api/v2/projects/#{@project.identifier}/transition_executions/#{transition.id}.xml"
    assert_equal expected_execution_url, get_element_text_by_xpath(xml, "//transition/transition_execution_url")
  end

  def test_should_include_enumeration_values
    xml, _ = card_transition_xml(@project, 'change status', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    status = @project.find_property_definition('status')
    assert_equal status.enumeration_values.size, get_number_of_elements(xml, "//transition/user_input_optional/property_definition[name='Status']/property_value_details/property_value")
  end

  def test_enumeration_values_should_be_compact
    xml, _ = card_transition_xml(@project, 'change status', :set_properties => {:status => Transition::USER_INPUT_OPTIONAL})
    open = @project.find_property_definition('status').find_enumeration_value('open')
    enum_url_xpath = "//transition/user_input_optional/property_definition[name='Status']/property_value_details/property_value[value='open']"
    expected_url = "http://example.com/api/v2/projects/#{@project.identifier}/enumeration_values/#{open.id}.xml"

    assert_not_nil get_element_text_by_xpath(xml, enum_url_xpath)
  end

  def test_plain_xml_serialization_should_include_basic_transition_info
    transition_xml, transition = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'})
    [:id, :name, :require_comment?].each do |attr_name|
      assert_equal transition.send(attr_name).to_s, get_element_text_by_xpath(transition_xml, "//transition/#{attr_name}")
    end
  end

  def test_should_not_serialize_only_available_for_users_when_transition_is_available_for_all_team_member
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'})
    assert_equal 0, get_number_of_elements(transition_xml, "//transition/only_available_for_users")
  end

  def test_xml_serialization_when_transition_is_only_available_for_some_team_members
    member = User.find_by_login('member')
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'}, :user_prerequisites => [member.id])
    assert_equal 1, get_number_of_elements(transition_xml, "//transition/only_available_for_users/user")
    assert_equal 1, get_number_of_elements(transition_xml, "//transition/only_available_for_users/user[@url='http://example.com/api/v2/users/#{member.id}.xml']")
  end

  def test_serialization_without_card_type_specified
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'})
    assert_equal 0, get_number_of_elements(transition_xml, "//transition/card_type")
  end

  pending "wait to reintroduce as story #9035"
  def test_should_serialize_display_value
    logout_as_nil
    type = @project.card_types.first
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'}, :required_properties => {:status => 'open', :dev => "(current user)"}, :card_type => type)
    assert_equal '(current user)', get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/display_value")
  end

  def test_should_serialize_anonymous_users
    logout_as_nil
    type = @project.card_types.first
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'}, :required_properties => {:status => 'open', :dev => "(current user)"}, :card_type => type)

    assert_equal nil, get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/value/name")
    assert_equal "true", get_attribute_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/value/name/@nil")
    assert_equal nil, get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/value/login")
    assert_equal "true", get_attribute_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/value/login/@nil")
  end

  def test_serialization_with_prerequisites
    member = User.find_by_login('member')
    type = @project.card_types.first
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'}, :required_properties => {:status => 'open', :dev => member.id}, :card_type => type)

    assert_equal type.name, get_element_text_by_xpath(transition_xml, "//transition/card_type/name")

    assert_equal 2, get_number_of_elements(transition_xml, "//transition/if_card_has_properties/property")
    assert_equal 'Status', get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Managed text list']/name")
    assert_equal 'open',   get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Managed text list']/value")
    assert_equal 'dev', get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/name")
    assert_equal "http://example.com/api/v2/users/#{member.id}.xml",   get_attribute_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Automatically generated from the team list']/value/@url")
  end

  def test_serialization_with_card_property_prerequisite
    login_as_admin
    with_new_project do |project|
      setup_card_relationship_property_definition('iteration')
      iteration_1 = create_card!(:name => "iteration 1")
      transition_xml, _ = card_transition_xml(project, 'close', :set_properties => {:iteration => nil}, :required_properties => {:iteration => iteration_1.id})

      assert_equal 1, get_number_of_elements(transition_xml, "//transition/if_card_has_properties/property")
      assert_equal 'iteration', get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Card']/name")
      assert_equal "http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration_1.number}.xml",   get_attribute_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Card']/value/@url")
    end
  end

  def test_serialization_of_set_properties
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'})
    assert_equal 1, get_number_of_elements(transition_xml, "//transition/will_set_card_properties/property")
    assert_equal 'Status', get_element_text_by_xpath(transition_xml, "//transition/will_set_card_properties/property[@type_description='Managed text list']/name")
    assert_equal 'closed',   get_element_text_by_xpath(transition_xml, "//transition/will_set_card_properties/property[@type_description='Managed text list']/value")
  end

  def test_serialization_of_property_set_prerequisite
    transition_xml, _ = card_transition_xml(@project, 'close', :set_properties => {:status => 'closed'}, :required_properties => {:status => '(set)', :dev => '(set)'})
    assert_equal 1, get_number_of_elements(transition_xml, "//transition/if_card_has_properties_set")
    assert_equal 2, get_number_of_elements(transition_xml, "//transition/if_card_has_properties_set/property_definition")
  end

  def test_serialization_of_set_properties_should_not_include_require_user_input_property
    xml, _ = card_transition_xml(@project, 'close', :set_properties => {
      :status => Transition::USER_INPUT_REQUIRED,
      :iteration => Transition::USER_INPUT_OPTIONAL
    })
    assert_equal 0, get_number_of_elements(xml, "//transition/will_set_card_properties/property")
  end

  def test_serialization_of_removing_from_tree_with_children
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')

      transition_xml, _ = card_transition_xml(project, 'tree belongings with children', :card_type => iteration_type, :remove_from_trees_with_children => [tree])

      assert_equal 1, get_number_of_elements(transition_xml, "//transition/to_remove_from_trees_with_children")
      assert_equal 1, get_number_of_elements(transition_xml, "//transition/to_remove_from_trees_with_children/tree_name")
      assert_equal 'three level tree', get_element_text_by_xpath(transition_xml, "//transition/to_remove_from_trees_with_children/tree_name")
    end
  end

  def test_serialization_of_removing_from_tree_without_children
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')

      transition_xml, _ = card_transition_xml(project, 'tree belongings without children', :card_type => iteration_type, :remove_from_trees => [tree])

      assert_equal 1, get_number_of_elements(transition_xml, "//transition/to_remove_from_trees_without_children")
      assert_equal 1, get_number_of_elements(transition_xml, "//transition/to_remove_from_trees_without_children/tree_name")
      assert_equal 'three level tree', get_element_text_by_xpath(transition_xml, "//transition/to_remove_from_trees_without_children/tree_name")
    end
  end

  def test_should_not_have_to_remove_from_trees_when_no_remove_from_tree_action
    with_three_level_tree_project do |project|
      iteration_type = project.card_types.find_by_name('iteration')

      transition_xml, _ = card_transition_xml(@project, 'simple', :card_type => iteration_type, :set_properties => {:status => 'closed'})

      assert_equal 0, get_number_of_elements(transition_xml, "//transition/to_remove_from_trees_with_children")
      assert_equal 0, get_number_of_elements(transition_xml, "//transition/to_remove_from_trees_without_children")
    end
  end

  def test_serialization_of_tree_relationship_property
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.find_by_name('three level tree')
      iteration_type = project.card_types.find_by_name('iteration')
      iteration1 = project.cards.find_by_name("iteration1")

      transition_xml, _ = card_transition_xml(@project, 'transition', :card_type => iteration_type, :set_properties => { 'Planning iteration' => iteration1.id})
      assert_equal 'Planning iteration', get_element_text_by_xpath(transition_xml, "//transition/will_set_card_properties/property/name")
      assert_equal "http://example.com/api/v2/projects/three_level_tree_project/cards/#{iteration1.number}.xml", get_attribute_by_xpath(transition_xml, "//transition/will_set_card_properties/property/value/@url")
    end
  end

  def test_serialization_of_plv
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '5')
    current_release.property_definitions = [@project.find_property_definition('Release')]
    current_release.save!
    next_release = create_plv!(@project, :name => 'next release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '6')
    next_release.property_definitions = [@project.find_property_definition('Release')]
    next_release.save!
    @project.reload
    transition_xml, _ = card_transition_xml(@project, 'Deferr',
                                              :required_properties => {:release => current_release.display_name},
                                              :set_properties => {:release => next_release.display_name})

    assert_equal 1, get_number_of_elements(transition_xml, "//transition/if_card_has_properties/property")
    assert_equal 'Release', get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Managed number list']/name")
    assert_equal '5',   get_element_text_by_xpath(transition_xml, "//transition/if_card_has_properties/property[@type_description='Managed number list']/value")

    assert_equal 1, get_number_of_elements(transition_xml, "//transition/will_set_card_properties/property")
    assert_equal 'Release', get_element_text_by_xpath(transition_xml, "//transition/will_set_card_properties/property[@type_description='Managed number list']/name")
    assert_equal '6',   get_element_text_by_xpath(transition_xml, "//transition/will_set_card_properties/property[@type_description='Managed number list']/value")
  end

  def card_transition_xml(*args)
    transition = create_transition(*args)
    view_helper.default_url_options  = {:project_id => Project.current.identifier, :host => 'example.com' }
    xml = transition.to_xml(:version => 'v2', :view_helper => view_helper)
    return xml, transition
  end

end
