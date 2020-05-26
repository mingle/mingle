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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

# this test will fail if there's residue in the database
# and we are having trouble with transactionality in this test
# let's ensure there's nothing weird there before we start the test
class ImportExportTemplateTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def test_should_not_export_memebership_requestable_flag_to_templates
    @user = login_as_member
    @project = create_project(:users => [@user])
    @project.update_attributes(:membership_requestable => true)
    export_file = create_project_exporter!(@project, User.current, :template => true).export
    imported_project = create_project_importer!(User.current, export_file).process!
    assert_equal false, imported_project.membership_requestable?
  end

  #bug #11239 Create project without cards causes we're sorry error
  def test_template_import_with_group_prerequisit_and_exclude_cards
    login_as_admin
    @project = create_project
    @project.with_active_project do |project|
      setup_property_definitions :status => ['new', 'open', 'fixed']
      group = create_group('group')
      create_transition(@project, 'availble to all in group', :set_properties => {:status => 'fix'}, :group_prerequisites => [group.id])
      create_card!(:name => 'first card')
    end

    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    clone = @project_importer.process!
    assert clone.cards.empty?
    assert_equal 'availble to all in group', clone.transitions.first.name
  end

  def test_exporting_a_project_as_template_sets_its_templatishness_even_if_the_project_is_not_set_as_such_locally
    @user = login_as_member
    @project = create_project

    @export_file = create_project_exporter!(@project, @user, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    assert @project_importer.process!.template?
  end

  # for bug 1597 (platform: jruby windows)
  def test_export_template_should_retain_saved_views
    @user = login_as_member
    @project = with_new_project(:users => [User.current]) do |project|
      @view  = CardListView.find_or_construct(project, {:style => 'list', :columns => 'status,iteration', :filters => ['[status][is][open]']})
      @view.name = 'saved_view'
      @view.save!
      project
    end
    @export_file = create_project_exporter!(@project, @user, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!.reload
    imported_project.with_active_project do
      assert_not_equal @project.id, imported_project.id
      imported_view = imported_project.card_list_views.find_by_name('saved_view')
      assert_not_nil imported_view
      assert_equal @view.to_params, imported_view.to_params
    end
  end

  def test_export_template_should_set_variables_to_not_set_when_its_value_is_user
    @user = login_as_member
    @project = with_new_project(:users => [User.current]) do |project|
      owner = setup_user_definition 'owner'
      project_variable = create_plv!(project, :name => 'team member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @user.id, :property_definitions => [owner])
      project
    end
    @export_file = create_project_exporter!(@project, @user, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    assert_equal nil, imported_project.project_variables.first.value

    @export_file = create_project_exporter!(@project, @user).export
    @project_importer = create_project_importer!(@user, @export_file)
    imported_project = @project_importer.process!

    assert_equal @project.users.first.id.to_s, imported_project.project_variables.find_by_name('team member').value
  end

  def test_export_tempalte_should_not_lose_property_associations_with_project_variable_when_its_value_is_user
    @user = login_as_member
    @project = with_new_project(:users => [User.current]) do |project|
      owner = setup_user_definition 'owner'
      project_variable = create_plv!(project, :name => 'team member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => @user.id, :property_definitions => [owner])
      project
    end
    @export_file = create_project_exporter!(@project, @user, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    imported_owner = imported_project.find_property_definition('owner')

    assert [imported_owner], imported_project.project_variables.find_by_name('team member').property_definitions
  end

  def test_import_template_sets_transition_actions_to_require_user_to_enter_when_they_are_set_to_user_project_variables
    @user = login_as_member
    @project = with_new_project(:users => [User.current]) do |project|
      owner = setup_user_definition 'owner'
      pv = create_plv!(project, :name => 'team member', :data_type => ProjectVariable::USER_DATA_TYPE, :value => project.users.first.id, :property_definitions => [owner])
      transition = create_transition(project, 'set user to team member', :required_properties => {:owner => pv.display_name}, :set_properties => {:owner => pv.display_name})
      project
    end
    @export_file = create_project_exporter!(@project, User.current, :template => true).export

    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    assert imported_project.transitions.first.actions.first.require_user_to_enter
    assert_equal 0, imported_project.transitions.first.prerequisites.size
  end

  def test_should_import_template_with_tree
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      export_file = create_project_exporter!(project, User.current, :template => true).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      assert imported_project.tree_configurations.find_by_name(configuration.name)
    end
  end

  def test_import_template_should_set_plv_that_type_is_card_to_not_set
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration,type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      pv = create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => iteration1.id, :card_type => type_iteration )
      export_file = create_project_exporter!(project, User.current, :template => true).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_pv = imported_project.project_variables.find_by_name('current iteration')
      assert_equal nil, imported_pv.value
    end
  end

  # Bug 5092
  def test_import_template_should_set_card_default_card_relationship_properties_to_not_set
    @user = login_as_member
    @project = with_new_project(:users => [User.current]) do |project|
      related_card_property_definition = setup_card_relationship_property_definition('related card')
      @card = create_card!(:name => 'Exported Card').tag_with(['Exported Tag', 'Another Tag'])
      card_defaults = project.reload.card_types.first.card_defaults
      card_defaults.update_properties related_card_property_definition.name => @card.id
      card_defaults.save
      project
    end

    export_and_reimport(@project, :template => true).with_active_project do |imported_project|
      assert imported_project.card_types.first.card_defaults.actions.empty?
    end
  end

  def test_import_template_should_set_prerequisite_to_any_and_action_to_not_set_if_they_use_card_property_definition
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration,type_story = find_planning_tree_types
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')

      set_to_iteration1 = create_transition(project, 'set to iteration1',
        :card_type => type_story,
        :required_properties => {'Planning release' => release1.id},
        :set_properties => {'Planning iteration' => iteration1.id})

      export_file = create_project_exporter!(project, User.current, :template => true).export

      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_transition = imported_project.transitions.find_by_name('set to iteration1')

      assert imported_transition
      assert imported_transition.prerequisites.empty?
      assert_nil imported_transition.actions.first.value
    end
  end

  def test_import_template_should_set_all_card_property_defintions_to_not_set
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration,type_story = find_planning_tree_types
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story_defaults = type_story.card_defaults

      property_values = PropertyValueCollection.from_params(project, {'Planning release' => release1.id, 'Planning iteration' => iteration1.id})
      story_defaults.actions.create_or_update(property_values.first)

      export_file = create_project_exporter!(project, User.current, :template => true).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_story_defaults = imported_project.card_types.find_by_name('story').card_defaults
      assert imported_story_defaults.actions.empty?
    end
  end

  def test_import_template_should_remove_card_list_view_that_use_card_property_defintion
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      view  = CardListView.find_or_construct(project, {:style => 'list', :filters => ["[planning iteration][is][#{iteration1.id}]"]})
      view.name = 'iteration1'
      view.save!
      imported_project = export_and_reimport(project, :template => true)

      assert imported_project.card_list_views.find_by_name('iteration1').nil?
    end
  end

  def test_import_template_should_not_remove_card_list_view_that_use_card_property_defintion_and_value_is_not_set
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      view  = CardListView.find_or_construct(project, {:style => 'list', :filters => ["[planning iteration][is][]"]})
      view.name = 'iteration1'
      view.save!
      imported_project = export_and_reimport(project, :template => true)

      assert imported_project.card_list_views.find_by_name('iteration1')
     end
  end

  def test_import_template_should_remove_card_list_view_that_use_card_property_defintion_in_tree_workspace
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      view  = CardListView.find_or_construct(project, {:style => 'tree', :tree_name => configuration.name, 'tf_iteration' => ["[planning iteration][is][#{iteration1.id}]"]})
      view.name = 'iteration1'
      view.save!
      imported_project = export_and_reimport(project, :template => true)

      assert imported_project.card_list_views.find_by_name('iteration1').nil?
    end
  end

  def test_import_template_should_remove_card_list_view_that_uses_card_property_definition_in_mql_filter
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      view  = CardListView.find_or_construct(project, {:style => 'list', :filters => { :mql => "'planning iteration' = NUMBER #{iteration1.number}"}})
      view.name = 'iteration1'
      view.save!
      imported_project = export_and_reimport(project, :template => true)

      assert imported_project.card_list_views.find_by_name('iteration1').nil?
    end
  end

  def test_import_template_should_not_remove_card_list_view_that_not_use_card_property_defintion_in_tree_workspace
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      view  = CardListView.find_or_construct(project, {:style => 'tree', :tree_name => configuration.name})
      view.name = 'iteration1'
      view.save!
      export_file = create_project_exporter!(project, User.current, :template => true).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!

      assert imported_project.card_list_views.find_by_name('iteration1')
    end
  end

  # bug 5332
  def test_import_template_should_clear_the_expands_for_all_card_list_views
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      iteration1 = project.cards.find_by_name('iteration1')
      view  = CardListView.find_or_construct(project, {:style => 'tree', :tree_name => configuration.name, :expands => "#{iteration1.number}"})
      view.name = 'iteration1'
      view.save!
      export_file = create_project_exporter!(project, User.current, :template => true).export

      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!

      iteration1_view =  imported_project.card_list_views.find_by_name('iteration1')
      assert iteration1_view.expands.empty?
    end
  end

  def test_export_import_project_structure_as_template
    admin = login_as_admin
    member = User.find_by_login('member')
    imported_project = nil
    with_new_project do |project|
      project.add_member(member)
      story_type = project.card_types.create :name => 'story'
      iteration_type = project.card_types.create :name => 'iteration'
      iteration = setup_card_relationship_property_definition('iteration')
      UnitTestDataLoader.setup_property_definitions :priority => ['high', 'low']
      UnitTestDataLoader.setup_numeric_property_definition 'size', [1, 2, 4, 8]
      UnitTestDataLoader.setup_user_definition('dev')

      project.reload.property_definitions.each do |pd|
        story_type.add_property_definition pd
      end

      c1 = create_card!(:name => 'hello', :card_type => story_type)
      c2 = create_card!(:name => 'world', :dev => member, :card_type => story_type)
      c2.tag_with('tag').save!
      first_page = project.pages.create!(:name => 'First Page',
                                         :content => 'Some content')
      overview_page = project.pages.create!(:name => 'Overview Page',
                                         :content => 'Project Overview')
      Attachment.create!(:file => sample_attachment, :project => project)

      create_plv!(project, :name => 'plv',
                  :data_type => ProjectVariable::CARD_DATA_TYPE,
                  :card_type => story_type,
                  :value => c1.id,
                  :property_definition_ids => [iteration.id])

      export_file = create_project_exporter!(project, User.current,
                                             :template => true).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
    end

    imported_project.with_active_project do |project|
      assert_equal ['Card', 'iteration', 'story'].sort, project.card_types.map(&:name).sort
      assert_equal 4, project.property_definitions.size

      assert_equal 0, project.cards.size
      assert_equal admin, project.overview_page.created_by
      assert_equal 1, project.pages.size
      assert_equal 0, project.attachments.size
      assert_equal 0, project.events_without_eager_loading.size
      assert_equal 0, project.users.size
      assert_equal 1, project.project_variables.size
      assert_equal 1, project.tags.size
      assert_equal 0, project.tags.first.taggings.size
    end
  end
end
