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

class ProjectCreatorTest < ActiveSupport::TestCase
  def setup
    @creator = ProjectCreator.new
    login_as_admin
  end

  def test_create_empty_project
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'})
    assert_equal 's', project.name
    assert_equal 't', project.identifier

    project.with_active_project do
      assert_equal 0, project.users.size
      assert_equal 0, project.cards.count
      assert_equal 0, project.card_types.count
      assert_equal 0, project.pages.count
    end
  end

  def test_create_project_sets_current_user_as_team_member_when_specified
    project = @creator.create('project' => {'name' => 'as_member', 'identifier' => 'as_member', 'current_user_as_member' => true})
    assert project.member?(User.current)
  end

  def test_create_project_with_card_type
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'])
    assert_equal 1, project.card_types.size
    assert project.card_types.find_by_name('Story').present?
  end

  def test_create_project_with_property_definition
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'property_definitions' => [{ 'name' => 'Reaction',
                                                           'is_managed' => 'false',
                                                           'data_type' => 'string',
                                                           'card_types' => [{'name' => 'Story'}]}])
    status_prop = project.reload.find_property_definition('Reaction')
    assert status_prop

    assert_equal status_prop, project.card_types.find_by_name('Story').property_definitions.first
  end

  def test_create_project_with_enum_property_definition
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'property_definitions' => [{ 'name' => 'Status',
                                                           'is_managed' => 'true',
                                                           'data_type' => 'string',
                                                           'card_types' => [{'name' => 'Story'}],
                                                           'property_value_details' => [{'value' => 'New'},
                                                                                        {'value' => 'In progress'},
                                                                                        {'value' => 'Complete'}]}])
    status_prop = project.reload.find_property_definition('Status')
    assert status_prop
    assert_equal ['New', 'In progress', 'Complete'], status_prop.values.collect(&:name)
  end

  def test_create_project_with_card
    project = @creator.create('project' => {'name' => 'test_name', 'identifier' => 'test_id'},
                              'card_types' => ['name' => 'Story'],
                              'cards' => [{ 'name' => 'card name',
                                            'description' => 'card desc',
                                            'card_type_name' => 'Story'}])
    project.with_active_project do |project|
      assert_equal 1, project.cards.size
      card = project.cards.first

      assert_equal 'card name', card.name
      assert_equal 'card desc', card.description
      assert_equal 'Story', card.card_type_name
    end
  end

  def test_create_project_with_card_with_property
    project = @creator.create('project' => {'name' => 'test_name', 'identifier' => 'test_id'},
                              'card_types' => ['name' => 'Story'],
                              'property_definitions' => [{ 'name' => 'Status',
                                                           'is_managed' => 'true',
                                                           'data_type' => 'string',
                                                           'card_types' => [{'name' => 'Story'}],
                                                           'property_value_details' => [{'value' => 'New'},
                                                                                        {'value' => 'In progress'},
                                                                                        {'value' => 'Complete'}]}],
                              'cards' => [{ 'name' => 'card name',
                                            'description' => 'card desc',
                                            'card_type_name' => 'Story',
                                            'properties' => {:status => 'New'}}])
    project.with_active_project do |project|
      assert_equal 1, project.cards.size
      card = project.cards.first

      assert_equal 'card name', card.name
      assert_equal 'card desc', card.description
      assert_equal 'Story', card.card_type_name
      assert_equal 'New', card.cp_status
    end
  end

  def test_create_project_with_card_with_tag
    tags = {'blue tag' => 'blue', 'red tag' => 'red'}
    project = @creator.create('project' => {'name' => 'test_name', 'identifier' => 'test_id'},
                              'card_types' => ['name' => 'Story'],
                              'cards' => [{ 'name' => 'card name',
                                            'description' => 'card desc',
                                            'card_type_name' => 'Story',
                                            'tags' => tags}])

    project.with_active_project do |project|
      assert_equal 1, project.cards.size
      card = project.cards.first

      assert_equal 'card name', card.name
      assert_equal 'card desc', card.description
      assert_equal 'Story', card.card_type_name
      tags.each do |name, color|
        tag = card.tags.select{|t| t.name == name}.first
        assert_equal color, tag.color
      end
    end
  end

  def test_create_project_with_overview_page
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'pages' => [{'name' => 'Overview Page', 'content' => 'this is overview page'}])
    assert overview_page = project.overview_page
    assert_equal 'Overview Page', overview_page.name
    assert_equal 'this is overview page', overview_page.content
  end

  def test_create_project_with_card_grid_tab
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'tabs' => [{'name' => 'story wall',
                                            "filters"=>["[Type][is][Story]"],
                                            "style"=>"grid"}])
    assert_equal 1, project.card_list_views.size
    view = project.card_list_views.first
    view_as_params = view.to_params
    assert_equal ["[Type][is][Story]"], view_as_params[:filters]
    assert_equal 'grid', view_as_params[:style]
    assert_equal 'story wall', view.name
    assert view.tab_view?
  end

  def test_create_project_with_card_grid_tab_and_reporting_page
    ordered_tab_identifiers = ['story wall', 'Another Page', 'Reporting Page']
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'ordered_tab_identifiers' => ordered_tab_identifiers,
                              'card_types' => ['name' => 'Story'],
                              'tabs' => [{'name' => 'story wall',
                                             "filters"=>["[Type][is][Story]"],
                                             "style"=>"grid",
                                             "project_landing_tab" => "true"}],
                              'pages' => [{'name' => 'Reporting Page', 'content' => 'this is full of charts', 'favorite' => 'true'}, {'name' => 'Another Page', 'content' => 'this is full of charts', 'favorite' => 'true'}])

    project.ordered_tab_identifiers.each_with_index do |id, index|
      tab_name = project.tabs.find_by_id(id).name
      assert_equal ordered_tab_identifiers[index], tab_name
    end
  end

  def test_create_project_with_ordered_overview
    ordered_tab_identifiers = ['Overview', 'Another Page', 'Another Tab', 'History']
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'ordered_tab_identifiers' => ordered_tab_identifiers,
                              'tabs' => [{'name' => 'Another Tab'}],
                              'pages' => [{'name' => 'Another Page', 'favorite' => 'true'}])
    tab_names = project.ordered_tab_identifiers.map do |identifier|
      if ordered_tab_identifiers.include?(identifier)
        identifier
      else
        project.tabs.find_by_id(identifier).name
      end
    end
    assert_equal ordered_tab_identifiers, tab_names
  end

  def test_create_project_with_invalid_card_grid_tab_ignores_tab
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'tabs' => [{'name' => 'story wall',
                                            "filters"=>["[Type][is][Story]"],
                                            "style"=>"grid"}])
    assert_equal 0, project.card_list_views.size
  end

  def test_create_project_with_card_grid_tab_marked_as_landing_tab
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'tabs' => [{'name' => 'story wall',
                                           "project_landing_tab" => "true",
                                           "filters"=>["[Type][is][Story]"],
                                           "style"=>"grid"}])
    assert_equal 1, project.card_list_views.size
    view = project.card_list_views.first
    view_as_params = view.to_params
    assert_equal ["[Type][is][Story]"], view_as_params[:filters]
    assert_equal 'grid', view_as_params[:style]
    assert_equal 'story wall', view.name
    assert view.tab_view?
    assert view.favorite.to_params, project.landing_tab.to_params
  end

  def test_merge_updates_project_with_specs
    project = create_project :name => 'test project', :identifier => 'test_project'
    @creator.merge!(project, {'project' => {'name' => 'spec project', 'identifier' => 'spec_project'},
                             'card_types' => [{:name => 'Story'}],
                             'cards' => [{:name => 'card in spec', :card_type_name => 'Story'}],
                             'property_definitions' => [{ 'name' => 'Status',
                                   'is_managed' => 'true',
                                   'data_type' => 'string',
                                   'card_types' => [{'name' => 'Story'}],
                                   'property_value_details' => [{'value' => 'New'},
                                                                {'value' => 'In progress'},
                                                                {'value' => 'Complete'}]}],
                             'card_defaults' => [{ :card_type_name => 'Story', :description => 'Test description', :properties => {:status => 'New'}}]})

    assert_equal 'test project', project.reload.name
    assert_equal 'test_project', project.identifier

    project.with_active_project do
      assert_equal 1, project.cards.size
      assert_equal 'card in spec', project.cards.first.name
      assert_equal 1, project.card_types.size
      assert_equal 'Story', project.card_types.first.name
      assert_equal 1, project.card_defaults.size
      assert_equal 'Test description', project.card_defaults.first.description

    end
  end

  def test_merge_updates_project_card_defaults
    project = create_project :name => 'test project', :identifier => 'test_project'
    @creator.merge!(project, {'project' => {'name' => 'spec project', 'identifier' => 'spec_project'},
                             'card_types' => [{:name => 'Story'}],
                             'cards' => [{:name => 'card in spec', :card_type_name => 'Story'}]})

    assert_equal 'test project', project.reload.name
    assert_equal 'test_project', project.identifier

    project.with_active_project do
      assert_equal 1, project.cards.size
      assert_equal 'card in spec', project.cards.first.name
    end
  end

  def test_merge_honors_include_cards_and_include_pages_option
    project = create_project :name => 'test project', :identifier => 'test_project'
    spec = {'project' => {'name' => 'spec project', 'identifier' => 'spec_project'},
      'card_types' => [{:name => 'Story'}],
      'cards' => [{:name => 'card in spec', :card_type_name => 'Story'}],
      'pages' => [{:name => 'page1', :content => 'hello there!! in page 1'}]}

    @creator.merge!(project, spec, :include_cards => false, :include_pages => false)

    assert_equal 'test project', project.reload.name
    assert_equal 'test_project', project.identifier

    project.with_active_project do
      assert_equal 0, project.cards.size
      assert_equal 0, project.pages.size
    end
  end

  def test_create_project_sets_the_card_type_defaults
    spec = {'project' => {'name' => 'spec project', 'identifier' => 'spec_project'},
      'card_types' => [{:name => 'Story'}],
      'property_definitions' => [{ 'name' => 'Status',
                                   'is_managed' => 'true',
                                   'data_type' => 'string',
                                   'card_types' => [{'name' => 'Story'}],
                                   'property_value_details' => [{'value' => 'New'},
                                                                {'value' => 'In progress'},
                                                                {'value' => 'Complete'}]}],
      'card_defaults' => [{ :card_type_name => 'Story', :properties => {:status => 'New'}}]
    }
    project = @creator.create(spec)

    project.with_active_project do
      story_defaults = project.card_types.first.card_defaults
      assert_equal 1, story_defaults.property_definitions.size
      assert_equal "New", story_defaults.property_value_for('Status').value
    end
  end

  def test_create_project_with_tree
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Branch'}, {'name' => 'Ornament'}],
      'property_definitions' => [{ 'name' => 'cheer', 'data_type' => 'numeric', 'is_managed' => 'false', 'card_types' => [{'name' => 'ornament'}]}],
      'trees' => [{ 'name' => 'christmas tree',
                    'description' => 'christmas tree with colorful ornaments',
                    'configuration' => [{'card_type_name' => 'Branch', 'position' => 0, 'relationship_name' => 'branch'},
                                        {'card_type_name' => 'Ornament', 'position' => 1}],
                  }]
    }
    project = @creator.create(spec)
    project.reload.with_active_project do
      assert_equal 1, project.tree_configurations.size
      christmas_tree = project.tree_configurations.first
      assert_equal "christmas tree", christmas_tree.name
      assert_equal "christmas tree with colorful ornaments", christmas_tree.description
      assert_equal 1, christmas_tree.relationships.size
      assert_equal 'Branch', christmas_tree.relationships.first.valid_card_type.name
      assert_equal ['Ornament'], christmas_tree.relationships.first.card_types.map(&:name)

      assert_include "branch", project.property_definitions.map(&:name)
    end
  end

  def test_create_project_with_aggregate_property
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Branch'}, {'name' => 'Ornament'}],
      'property_definitions' => [{ 'name' => 'cheer', 'data_type' => 'numeric', 'is_managed' => 'false', 'card_types' => [{'name' => 'ornament'}]}],
      'trees' => [{ 'name' => 'christmas tree',
                    'description' => 'christmas tree with colorful ornaments',
                    'configuration' => [{'card_type_name' => 'Branch', 'position' => 0, 'relationship_name' => 'branch'},
                                        {'card_type_name' => 'Ornament', 'position' => 1}],
                    'aggregate_properties' => [{'name' => 'joy', 'type' => 'SUM', 'target_property_name' => 'cheer', 'card_type_name' => 'Branch', 'scope' => 'ALL_DESCENDANTS'}]
                  }],
      'cards' => [{ 'name' => 'top branch', 'card_type_name' => 'Branch'}]
    }
    project = @creator.create(spec)
    project.reload.with_active_project do
      assert_include "joy", project.property_definitions.map(&:name)

      #make sure card schema is updated with aggregate property
      assert_nothing_raised do
        assert_equal 1, Card.count(:conditions => ['cp_joy IS NULL and card_type_name = ?', 'Branch'])
      end
    end
  end

  def test_create_project_with_card_associations
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Branch'}, {'name' => 'Ornament'}],
      'property_definitions' => [{ 'name' => 'cheer', 'data_type' => 'numeric', 'is_managed' => 'false', 'card_types' => [{'name' => 'ornament'}]}],
      'trees' => [{ 'name' => 'christmas tree',
                    'description' => 'christmas tree with colorful ornaments',
                    'configuration' => [{'card_type_name' => 'Branch', 'position' => 0, 'relationship_name' => 'branch'},
                                        {'card_type_name' => 'Ornament', 'position' => 1}],
                  }],
      'cards' => [{ 'name' => 'top branch', 'card_type_name' => 'Branch', 'number' => '1'}, { 'name' => 'red bulb', 'card_type_name' => 'Ornament', 'number' => '2', 'card_relationships' => {'branch' => '1'}}]

    }
    project = @creator.create(spec)
    project.reload.with_active_project do
      branch_card = project.cards.find_by_number(1)
      ornament_card = project.cards.find_by_number(2)

      assert_equal branch_card, ornament_card.cp_branch
      christmas_tree = project.tree_configurations.first

      assert_equal 1, christmas_tree.containings_count_of(branch_card)
    end
  end

  def test_create_project_with_favorite_view
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'favorites' => [{'name' => 'story wall',
                                            "filters"=>["[Type][is][Story]"],
                                                "style"=>"grid"}])
    assert_equal 1, project.favorites.size
    favorite = project.favorites.first
    assert favorite.favorite?

    view = favorite.favorited
    view_as_params = view.to_params
    assert_equal ["[Type][is][Story]"], view_as_params[:filters]
    assert_equal 'grid', view_as_params[:style]
    assert_equal 'story wall', view.name
  end

  def test_create_project_with_tab_view_and_colored_by_type
    project = @creator.create('project' => {'name' => 'with_tab_view', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'tabs' => [{'name' => 'card wall',
                                          'filters'=>["[Type][is][Story]"],
                                          'style'=>'grid',
                                          'color_by' =>'Type'}])
    assert_equal 1, project.tabs.size
    tab = project.tabs.first

    view = tab.favorited
    view_as_params = view.to_params
    assert_equal ["[Type][is][Story]"], view_as_params[:filters]
    assert_equal 'grid', view_as_params[:style]
    assert_equal 'card wall', view.name
    assert_equal 'Type', view_as_params[:color_by]
  end

  def test_create_project_from_template_with_numbered_cards_and_create_a_new_card_will_use_the_next_available_number
    project = @creator.create('project' => {'name' => 'with_tab_view', 'identifier' => 't'},
                              'card_types' => ['name' => 'Story'],
                              'cards' => [{ 'number' => 1, 'name' => 'top banana', 'card_type_name' => 'Story'}])
    project.with_active_project do
      new_card = create_card! :name => 'lesser banana'
      assert_equal 2, new_card.number
    end

  end

  def test_create_project_with_aggregate_property_having_aggregate_condition
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Branch'}, {'name' => 'Ornament'}],
      'property_definitions' => [{ 'name' => 'cheer', 'data_type' => 'numeric', 'is_managed' => 'false', 'card_types' => [{'name' => 'ornament'}]}],
      'trees' => [{ 'name' => 'christmas tree',
                    'description' => 'christmas tree with colorful ornaments',
                    'configuration' => [{'card_type_name' => 'Branch', 'position' => 0, 'relationship_name' => 'branch'},
                                        {'card_type_name' => 'Ornament', 'position' => 1}],
                    'aggregate_properties' => [{'name' => 'joy', 'type' => 'SUM', 'target_property_name' => 'cheer', 'card_type_name' => 'Branch', 'scope' => 'CONDITION', 'condition' => 'Type = Ornament'}]
                  }],
      'cards' => [{ 'name' => 'top branch', 'card_type_name' => 'Branch'}]
    }
    project = @creator.create(spec)
    project.reload.with_active_project do
      assert_include "joy", project.property_definitions.map(&:name)
      joy = project.property_definitions.detect{|pd| pd.name == 'joy'}
      assert_equal 'Type = Ornament', joy.aggregate_condition

      #make sure card schema is updated with aggregate property
      assert_nothing_raised do
        assert_equal 1, Card.count(:conditions => ['cp_joy IS NULL and card_type_name = ?', 'Branch'])
      end
    end
  end

  def test_create_project_with_project_level_variables
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Greetings'}],
      'property_definitions' => [{ 'name' => 'message', 'data_type' => 'string', 'is_managed' => 'false', 'card_types' => [{'name' => 'Greetings'}]}],
      'plvs' => [{'name' => 'wishes', 'data_type' => 'STRING_DATA_TYPE', 'value' => 'Happy holidays', 'property_definitions' => ['message']}]
    }
    project = @creator.create(spec)

    assert_equal 1, project.project_variables.size
    wishes_plv = project.project_variables.first
    assert_equal 'wishes', wishes_plv.name
    assert_equal 'Happy holidays', wishes_plv.value

    message = project.property_definitions.first
    wishes_plv.all_available_property_definitions.include?(message)
  end

  def test_create_project_with_project_level_variable_of_type_card
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Greetings'}],
      'property_definitions' => [{ 'name' => 'occassion', 'data_type' => 'card', 'card_types' => [{'name' => 'Greetings'}]}],
      'cards' => [{'name' => 'thanks giving', 'card_type_name' => 'greetings', 'number' => '1'}],
      'plvs' => [{'name' => 'current occassion', 'data_type' => 'CARD_DATA_TYPE', 'value' => '1', 'property_definitions' => ['occassion']}]
    }
    project = @creator.create(spec)

    assert_equal 1, project.project_variables.size
    project.with_active_project do
      assert_equal project.cards.first.id, project.project_variables.first.value.to_i
    end
  end

  def test_create_project_with_project_level_variable_of_type_card_without_any_cards
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Greetings'}],
      'property_definitions' => [{ 'name' => 'occassion', 'data_type' => 'card', 'card_types' => [{'name' => 'Greetings'}]}],
      'plvs' => [{'name' => 'current occassion', 'data_type' => 'CARD_DATA_TYPE', 'value' => '1', 'property_definitions' => ['occassion']}]
    }
    project = @creator.create(spec)

    assert_equal 1, project.project_variables.size
    assert_nil project.project_variables.first.value
  end

  def test_create_project_with_plv_pointing_to_property_definition_from_tree
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project'},
      'card_types' => [{'name' => 'Branch'}, {'name' => 'Ornament'}],
      'property_definitions' => [{ 'name' => 'cheer', 'data_type' => 'numeric', 'is_managed' => 'false', 'card_types' => [{'name' => 'ornament'}]}],
      'trees' => [{ 'name' => 'christmas tree',
                    'description' => 'christmas tree with colorful ornaments',
                    'configuration' => [{'card_type_name' => 'Branch', 'position' => 0, 'relationship_name' => 'branch_relationship'},
                                        {'card_type_name' => 'Ornament', 'position' => 1}],
                  }],
      'plvs' => [{'name' => 'current branch', 'data_type' => 'CARD_DATA_TYPE', 'value' => '1', 'property_definitions' => ['branch_relationship'], 'card_type' => 'Branch'}]
    }

    project = @creator.create(spec)
    current_branch = project.project_variables.first
    branch_pd = project.find_property_definition('branch_relationship')

    assert current_branch.all_available_property_definitions.include?(branch_pd)
  end

  def test_create_project_with_user_property_set_to_current_user
    spec = {
      'project' => {'name' => 'Holiday project', 'identifier' => 'holiday_project', 'current_user_as_member' => true},
      'card_types' => [{'name' => 'Greetings'}],
      'property_definitions' => [{ 'name' => 'greeter', 'data_type' => 'user', 'card_types' => [{'name' => 'Greetings'}]}],
      'cards' => [{'name' => 'thanks giving', 'card_type_name' => 'greetings', 'number' => '1', 'properties' => { 'greeter' => '(current user)' }}]
    }
    project = @creator.create(spec)
    greeter_property = project.find_property_definition('greeter')
    assert_equal User.current, greeter_property.value(project.cards.first)
  end

  def test_create_project_with_date_property_definition
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                            'card_types' => ['name' => 'Story'],
                            'property_definitions' => [{ 'name' => 'Due Date',
                                                       'data_type' => 'date',
                                                       'card_types' => [{'name' => 'Story'}]}])
    due_date_prop = project.reload.find_property_definition('Due Date')
    assert due_date_prop
    assert_equal "DatePropertyDefinition", due_date_prop.type
  end

  def test_create_project_with_murmurs
    project = @creator.create('project' => {'name' => 's', 'identifier' => 't'},
                              'murmurs' => [{'body' => "hello", 'author' => User.current.login}])
    assert_equal 1, project.murmurs.count
    assert_equal 'hello', project.murmurs.first.body({})
    assert_equal User.current.login, project.murmurs.first.author.login
  end
end
