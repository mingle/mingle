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

class TransitionWorkflowsHelperTest < ActiveSupport::TestCase
  include TransitionWorkflowsHelper

  def setup
    login_as_proj_admin
  end

  def test_card_type_properties
    with_three_level_tree_project do |project|
      @card_types = project.card_types # setup helper instance variable
      assert_equal [], self.card_type_properties[project.card_types.find_by_name('release').id]
      assert_equal ["size", "status"], self.card_type_properties[project.card_types.find_by_name('story').id].collect { |property| property[:name] }.sort
    end
  end

  def test_previewing_transitions_information_messsage_returns_correctly_pluralized_messages
    project = create_project
    card_type = project.card_types.first
    cp_single_value = setup_managed_text_definition('foo', [1])

    workflow = TransitionWorkflow.new(project, :card_type_id => card_type.id, :property_definition_id => cp_single_value.id)
    workflow.build
    assert_equal 1, workflow.transitions.size
    expected_message = "You are previewing the transition that is about to get generated. The transition below will be created #{'only if'.bold} you complete the process by clicking on &#39;Generate transition workflow&#39;. Also note that the listed hidden date property will be created along with the transition."
    assert_include expected_message, previewing_transitions_information_messsage(workflow)

    cp_multiple_values = setup_managed_text_definition('bar', [1, 2])
    workflow = TransitionWorkflow.new(project, :card_type_id => card_type.id, :property_definition_id => cp_multiple_values.id)
    workflow.build
    assert_equal 2, workflow.transitions.size
    expected_message = "You are previewing the transitions that are about to get generated. The transitions below will be created #{'only if'.bold} you complete the process by clicking on &#39;Generate transition workflow&#39;. Also note that the listed hidden date properties will be created along with the transitions."
    assert_include expected_message, previewing_transitions_information_messsage(workflow)
  end

  def test_existing_transitions_warning_message_returns_correctly_pluralized_messages
    project = create_project
    project.add_member(User.current, :project_admin)
    card_type = project.card_types.first
    property_definition = setup_managed_text_definition('foo', [1])
    create_transition project, 'Persisted Transition Uno', :card_type => card_type, :set_properties => { :foo => '1' }

    workflow = TransitionWorkflow.new(project, :card_type_id => card_type.id, :property_definition_id => property_definition.id)
    workflow.build
    assert_equal 1, workflow.transitions.size
    assert_include "There is already #{'1'.bold} transition using #{'Card'.bold} and #{'foo'.bold}.", existing_transitions_warning_message(workflow)

    property_definition = setup_managed_text_definition('foo', [2])
    create_transition project, 'Persisted Transition Dos', :card_type => card_type, :set_properties => { :foo => '2' }
    project.reload
    workflow = TransitionWorkflow.new(project, :card_type_id => card_type.id, :property_definition_id => property_definition.id)
    workflow.build
    assert_equal 2, workflow.transitions.size
    assert_include "<p>There are already #{'2'.bold} transitions using #{'Card'.bold} and #{'foo'.bold}.", existing_transitions_warning_message(workflow)
  end

  def test_card_type_name_should_be_html_escaped_in_warning_message
    property_name_with_html_tag = '<h1>foo</h1>'
    card_type_name_with_html_tag = '<h1>bar</h1>'
    project = create_project
    project.add_member(User.current, :project_admin)
    card_type = project.card_types.first
    card_type.update_attribute(:name, card_type_name_with_html_tag)
    property_definition = setup_managed_text_definition(property_name_with_html_tag, [1])
    create_transition project, 'Persisted Transition Uno', :card_type => card_type, :set_properties => { property_name_with_html_tag => '1' }

    workflow = TransitionWorkflow.new(project, :card_type_id => card_type.id, :property_definition_id => property_definition.id)
    workflow.build
    assert_equal 1, workflow.transitions.size
    assert_include property_name_with_html_tag.escape_html, existing_transitions_warning_message(workflow)
    assert_include card_type_name_with_html_tag.escape_html, existing_transitions_warning_message(workflow)
  end

  def url_for(options)
    FakeViewHelper.new.url_for(options)
  end

  # allows us to use content_tag_with_user_access, etc without a real controller
  def on_options_authorized(options)
    # always authorized
    yield
  end
end
