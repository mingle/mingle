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

require File.expand_path('../unit_test_helper', File.dirname(__FILE__))
require File.expand_path('renderable_test_helper', File.dirname(__FILE__))

class CardDefaultsTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include ::RenderableTestHelper

  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def teardown
    logout_as_nil
  end

  def test_new_card_defaults_does_not_create_with_redcloth
    card_type = @project.card_types.create!(:name => "another card type")
    card_type.create_card_defaults_if_missing
    defaults = card_type.card_defaults

    assert_not_nil defaults.redcloth
    assert_false defaults.redcloth
  end

  def test_create_card_from_defaults_preserves_macros
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    card_defaults.update_attributes :description => "{{ project }}", :redcloth => false
    card = @project.cards.create!(:name => "from default", :card_type_name => card_type.name)
    card_defaults.update_card(card)
    assert_equal "{{ project }}", card.description
    assert_equal "first_project", card.formatted_content(view_helper)
  end

  def test_convert_redcloth_to_html_works_for_card_defaults
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    card_defaults.update_attributes :description => "h1. header", :redcloth => true
    assert card_defaults.redcloth

    card_defaults.convert_redcloth_to_html!
    assert_false card_defaults.redcloth
    assert_equal "<h1>header</h1>", card_defaults.description
  end

  def test_create_card_from_defaults_adds_checklists
    with_new_project do |project|
      card_type = project.card_types.create!(:name => 'Story')
      default_checklists = ["first", "second"]
      card_type.card_defaults.set_checklist_items(default_checklists)
      card = project.cards.create!(:name => "from default", :card_type_name => card_type.name)
      card_type.card_defaults.update_card(card)
      assert_equal default_checklists, card.reload.incomplete_checklist_items.map(&:text)
    end
  end

  def test_should_update_card_from_defaults
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    status_default = 'new'
    dev_default = @project.users.first.id
    id_default = 'some free text'
    start_date_default = '03 Nov 2006'
    description_default = "the description"

    card_defaults.description = description_default
    card_defaults.update_properties :Status => status_default, :dev => dev_default, :id => id_default, 'start date' => start_date_default
    card_defaults.save!

    card = @project.cards.new
    card.cp_material = 'gold'
    card_defaults.update_card(card)
    assert_equal 'gold', card.cp_material
    assert_equal status_default, card.cp_status
    assert_equal dev_default, card.cp_dev_user_id
    assert_equal id_default, card.cp_id
    assert_equal Date.parse(start_date_default), card.cp_start_date
    assert_equal description_default, card.description
  end

  def test_should_update_card_description
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    card = @project.cards.new
    card.description = 'original description'
    card_defaults.update_card(card)
    assert_nil card.description
  end

  def test_should_save_hidden_property_defaults
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    status = @project.find_property_definition(:Status)
    status.hidden = true
    status.save!

    card_defaults.update_properties :Status => 'closed'
    card_defaults.save!

    card = @project.cards.new
    card_defaults.update_card(card)
    assert_equal 'closed', card.cp_status
  end

  def test_actions_create_or_update
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    assert_equal 0, card_defaults.actions.count

    property_values = PropertyValueCollection.from_params(@project, {:Status => 'new'}, {:include_hidden => true})
    card_defaults.actions.create_or_update(property_values.first)

    assert_equal 1, card_defaults.actions.count
    assert_equal 'new', card_defaults.actions.first.target_property.db_identifier

    property_values = PropertyValueCollection.from_params(@project, {:Status => 'old'}, {:include_hidden => true})
    card_defaults.actions.create_or_update(property_values.first)

    assert_equal 1, card_defaults.actions.count
    assert_equal 'old', card_defaults.actions.first.reload.target_property.db_identifier
  end

  def test_should_update_only_hidden_properties_when_hidden_only_option_passed_in
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    status_default = 'new'
    dev_default = @project.users.first.id
    id_default = 'some free text'
    start_date_default = '03 Nov 2006'
    description_default = "the description"

    dev_property_def = @project.find_property_definition('dev')
    dev_property_def.hidden = true
    dev_property_def.save!

    card_defaults.description = description_default
    card_defaults.update_properties :Status => status_default, :dev => dev_default, :id => id_default, 'start date' => start_date_default
    card_defaults.save!

    card = @project.cards.new
    card.cp_material = 'gold'
    card_defaults.update_card(card, :hidden_only => true)
    assert_equal 'gold', card.cp_material
    assert_equal nil, card.cp_status
    assert_equal dev_default, card.cp_dev_user_id
    assert_equal nil, card.cp_id
    assert_equal nil, card.cp_start_date
    assert_equal nil, card.description
  end

  def test_should_not_consider_special_values_as_specific_usages
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    card_defaults.update_properties :dev => PropertyType::UserType::CURRENT_USER
    card_defaults.save!

    login_as_member
    assert !card_defaults.reload.uses?(PropertyValue.create_from_db_identifier(@project.find_property_definition('dev'), User.current.id))
  end

  def test_should_not_allow_multiple_relationship_default_properties_per_tree
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      release1 = project.cards.find_by_name('release1')

      cp_iteration = project.find_property_definition('planning iteration')
      cp_release = project.find_property_definition('planning release')

      card_defaults = type_release.card_defaults

      card_defaults.update_properties cp_iteration.name => iteration1.id, cp_release.name => release1.id
      card_defaults.save

      assert !card_defaults.errors.empty?
      assert_equal ['Defaults cannot set more than one relationship property per tree.'], card_defaults.errors.full_messages

      card_defaults.reload
      card_defaults.update_properties cp_iteration.name => iteration1.id, cp_release.name => ''
      card_defaults.save

      assert card_defaults.errors.empty?
    end
  end

  def test_appropriate_tree_path_should_be_applied_to_card_on_update
    with_filtering_tree_project do |project|
      type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types
      iteration3 = project.cards.find_by_name('iteration3')
      task2 = project.cards.find_by_name('task2')
      release2 = project.cards.find_by_name('release2')
      minutia1 = project.cards.find_by_name('minutia1')

      cp_story = project.find_property_definition('planning story')
      cp_iteration = project.find_property_definition('planning iteration')
      cp_release = project.find_property_definition('planning release')

      card_defaults = type_release.card_defaults
      card_defaults.update_properties cp_iteration.name => iteration3.id
      card_defaults.save

      card_defaults.update_card(task2)
      assert_equal iteration3.name, cp_iteration.value(task2).name
      assert_equal release2.name, cp_release.value(task2).name
      assert_nil cp_story.value(task2)

      task2.save!
      assert_equal iteration3.name, cp_iteration.value(minutia1.reload).name
    end
  end

  def test_should_validate_plv_properties_existing_before_save
    dev_prop = @project.find_property_definition('dev')
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    card_defaults.update_properties :dev => '(bla)'
    card_defaults.validate
    assert_equal "dev: #{'(bla)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property.", card_defaults.errors['base']
  end

  def test_should_validate_plv_property_types_are_matched_before_save
    dev_prop = @project.find_property_definition('dev'); dev_prop.name = '<h1>dev</h1>'; dev_prop.save!
    id_prop = @project.find_property_definition('id')
    create_plv!(@project, :name => 'string plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'some text', :property_definition_ids => [id_prop.id])
    create_plv!(@project, :name => 'user plv', :data_type => ProjectVariable::USER_DATA_TYPE, :value => User.find_by_login('member').id, :property_definition_ids => [dev_prop.id])

    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults

    dev_default = '(user plv)'
    id_default = '(string plv)'

    card_defaults.update_properties '<h1>dev</h1>' => dev_default, :id => id_default
    card_defaults.validate

    assert card_defaults.errors.empty?

    dev_default = '(string plv)'
    id_default = '(user plv)'

    card_defaults.update_properties '<h1>dev</h1>' => dev_default, :id => id_default
    card_defaults.validate
    assert_equal [
        "&lt;h1&gt;dev&lt;/h1&gt;: #{'(string plv)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property.",
        "id: #{'(user plv)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."].sort,
      card_defaults.errors['base'].sort
  end

  def test_should_update_card_when_using_plv_in_card_defaults
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    id_prop = @project.find_property_definition('id')

    create_plv!(@project, :name => 'string plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'some text', :property_definition_ids => [id_prop.id])
    card_defaults.update_properties :id => '(string plv)'
    card_defaults.save!

    card = @project.cards.new
    card_defaults.update_card(card)

    assert_equal 'some text', card.cp_id
  end

  def test_should_set_card_default_to_not_set_after_delete_a_plv
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    id_prop = @project.find_property_definition('id')

    plv = create_plv!(@project, :name => 'string plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'some text', :property_definition_ids => [id_prop.id])
    card_defaults.update_properties :id => '(string plv)'
    card_defaults.save!

    plv.destroy

    card_defaults.reload
    card = @project.cards.new
    card_defaults.update_card(card)

    assert_equal nil, card.cp_id
  end

  # bug 6894
  def test_update_properties_should_set_action_variable_binding_to_nil_when_updating_from_a_plv_value_to_not_set
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    id_prop = @project.find_property_definition('id')

    plv = create_plv!(@project, :name => 'string plv', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'some text', :property_definition_ids => [id_prop.id])
    card_defaults.update_properties :id => '(string plv)'
    card_defaults.save!

    card_defaults.reload.update_properties :id => ''
    card_defaults.save!
    card_defaults.reload
    assert_nil card_defaults.actions.first.value
    assert_nil card_defaults.actions.first.variable_binding
  end

  def test_destroy_unused_actions_should_remove_actions_with_property_definitions_not_referenced_in_the_card_type
    priority = @project.find_property_definition('priority')
    iteration = @project.find_property_definition('iteration')
    status = @project.find_property_definition('status')

    card_type = @project.card_types.create!(:name => 'new_card_type')
    status.card_types = [card_type]
    status.save!
    card_type.card_defaults.update_properties(:status => 'open')
    card_type.card_defaults.save!

    # Faking card default still using such disassociated property definitions
    options = { :executor_type => 'CardDefaults', :executor_id => card_type.card_defaults.id, :type => 'PropertyDefinitionTransitionAction', :value => nil }
    [iteration, priority].each { |pd| card_type.card_defaults.actions.create!(options.merge(:target_id => pd.id)) }
    assert card_type.card_defaults.uses_property_definition?(status)
    assert card_type.card_defaults.uses_property_definition?(iteration)
    assert card_type.card_defaults.uses_property_definition?(priority)

    card_type.reload
    card_type.card_defaults.destroy_unused_actions(card_type.property_definitions)

    assert card_type.card_defaults.uses_property_definition?(status)
    assert_false card_type.card_defaults.uses_property_definition?(iteration)
    assert_false card_type.card_defaults.uses_property_definition?(priority)
  end

end
