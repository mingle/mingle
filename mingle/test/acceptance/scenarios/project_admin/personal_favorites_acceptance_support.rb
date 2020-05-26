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

module PersonalFavoritesAcceptanceSupport

  PERSONAL_FAV_1 = "personal favorite 1"
  PERSONAL_FAV_2 = "personal favorite 2"
  PERSONAL_FAV_3 = "personal favorite 3"
  PERSONAL_FAV_4 = "personal favorite 4"
  PERSONAL_FAV_5 = "personal favorite 5"
  PERSONAL_FAV_6 = "fav with properties"
  FAVORITE = 'favorite'
  PAGE_NAME = 'wikipage'
  SPACE = ' '

  PLV_NAME = "plv"
  MANAGED_NUMBER = 'managed number'
  FREE_NUMBER = 'free_number'

  MANAGED_TEXT_TYPE = "Managed text list"
  FREE_TEXT_TYPE = "Allow any text"
  MANAGED_NUMBER_TYPE = "Managed number list"
  FREE_NUMBER_TYPE = "Allow any number"
  USER_TYPE = "team"
  DATE_TYPE = "date"
  CARD_TYPE = "card"

  MANAGED_TEXT = 'managed text'
  FREE_TEXT = 'free_text'
  MANAGED_NUMBER = 'managed number'
  FREE_NUMBER = 'free_number'
  USER = 'user'
  DATE = 'date'
  RELATED_CARD = 'related_card'

  TRANSITION_ONLY = "transition_only"

  RELEASE = 'Release'
  ITERATION = 'Iteration'
  STORY = 'Story'
  TASK = 'Task'

  PLANNING_TREE = "planning_tree"
  RELEASE_ITERATION = "release-iteration"
  ITERATION_TASK = "iteration-task"
  TASK_STORY = "task-story"

  def create_team_page_favorite(page_name)
    @project.favorites.of_team.create(:favorited => @project.pages.find_or_create_by_name(page_name))
  end

  def create_personal_page_favorite(user, page_name)
    @project.favorites.personal(user).create(:favorited => @project.pages.find_or_create_by_name(page_name))
  end

  def should_see_personal_favorite_on_profile_page(row, project_name, favorite_name, style)
    assert_table_values("global_personal_views", row+1, 0, project_name)
    assert_table_values("global_personal_views", row+1, 1, favorite_name)
    assert_table_values("global_personal_views", row+1, 2, style)
    assert_table_values("global_personal_views", row+1, 3, "Delete")
  end

  def create_personal_favorite_using_numeric_plv(project, personal_favorite_name)
    project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :filters => ["[Type][is][(any)]", "[#{MANAGED_NUMBER}][is][#{plv_display_name(PLV_NAME)}]"], :style => "list", :user_id => User.current.id)
  end

  def create_personal_favorite_using_card_type_property(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :filters => ["[#{RELATED_CARD}][is][#{@release_1.number}]"], :style => "list", :user_id => User.current.id)
    end
  end

  def create_personal_favorite_using_tree_filter(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :tf_release=>["[#{RELEASE_ITERATION}][is][#{@release_1.number}]"], :style=>"tree", :expands=>"1,3,5", :tree_name=>PLANNING_TREE, :user_id => User.current.id)
    end
  end

  def create_team_favorite_on_card_list_view_with_card_filter(project, team_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => team_favorite_name}, :filters => ["[Type][is][Release]"], :style => "list", :user_id => nil)
    end
  end

  def create_personal_favorite_on_card_tree_view(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :tree_name => PLANNING_TREE, :style=>"tree", :expands=>"1,3,5", :user_id => User.current.id)
    end
  end

  def create_personal_favorite_on_card_grid_view_with_card_filter(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :filters => ["[Type][is][Release]"], :style => "grid", :user_id => User.current.id)
    end
  end

  def create_personal_favorite_on_card_grid_view_with_mql_filter(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :filters => {:mql => "type = release"}, :style => "grid", :user_id => User.current.id)
    end
  end

  def create_personal_favorite_on_card_list_view_with_mql_filter(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :filters => {:mql => "type = story"}, :style => "list", :user_id => User.current.id)
    end
  end

  def create_personal_favorite_on_card_list_view_with_card_filter(project, personal_favorite_name)
    project.with_active_project do
      project.card_list_views.create_or_update(:view => {:name => personal_favorite_name}, :filters => ["[Type][is][Release]"], :style => "list", :user_id => User.current.id)
    end
  end

  def add_tree_and_card_for_project(project)
    @planning_tree = setup_tree(project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story, @type_task], :relationship_names => [RELEASE_ITERATION, ITERATION_TASK, TASK_STORY])
    add_card_to_tree(@planning_tree, @release_1)
    add_card_to_tree(@planning_tree, @iteration_1, @release_1)
    add_card_to_tree(@planning_tree, @story_1, @iteration_1)
  end

  def add_cards_of_different_card_types_for_project(project)
    project.activate
    @release_1 = create_card!(:name => 'release 1', :card_type => RELEASE, MANAGED_NUMBER => 1, FREE_TEXT => 'a', RELATED_CARD => nil, USER => users(:project_member).id)
    @release_2 = create_card!(:name => 'release 2', :card_type => RELEASE, MANAGED_NUMBER => 1, FREE_TEXT => 'a', RELATED_CARD => @release_1, USER => users(:project_member).id)
    @iteration_1 = create_card!(:name => 'iteration 1', :card_type => ITERATION, MANAGED_NUMBER => 2, FREE_TEXT => 'b', USER => users(:project_member).id)
    @iteration_2 = create_card!(:name => 'iteration 2', :card_type => ITERATION, MANAGED_NUMBER => 2, FREE_TEXT => 'b', USER => users(:project_member).id)
    @story_1 = create_card!(:name => 'story 1', :card_type => STORY, MANAGED_NUMBER => 3, FREE_TEXT => 'c', USER => users(:read_only_user).id)
    @story_2 = create_card!(:name => 'story 2', :card_type => STORY, MANAGED_NUMBER => 3, FREE_TEXT => 'c', USER => users(:read_only_user).id)
    @tasks_1 = create_card!(:name => 'task 1', :card_type => TASK, MANAGED_NUMBER => 4, FREE_TEXT => 'd', USER => users(:read_only_user).id)
    @tasks_2 = create_card!(:name => 'task 2', :card_type => TASK, MANAGED_NUMBER => 4, FREE_TEXT => 'd', USER => users(:read_only_user).id)
    @special_card = project.cards.create!(:name => 'xyz', :card_type => @type_story, :cp_related_card => @release_1, :cp_free_text => "abcdefg")
  end

  def add_card_types_for_project(project)
    @type_release = setup_card_type(project, RELEASE, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    @type_iteration = setup_card_type(project, ITERATION, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    @type_task = setup_card_type(project, TASK, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
    @type_story = setup_card_type(project, STORY, :properties => [MANAGED_NUMBER, MANAGED_TEXT, FREE_NUMBER, FREE_TEXT, DATE, RELATED_CARD, USER, TRANSITION_ONLY])
  end

  def add_properties_for_project(project)
    project.activate
    create_property_for_card(MANAGED_TEXT_TYPE, MANAGED_TEXT)
    create_property_for_card(FREE_TEXT_TYPE, FREE_TEXT)
    create_property_for_card(MANAGED_NUMBER_TYPE, MANAGED_NUMBER)
    create_property_for_card(FREE_NUMBER_TYPE, FREE_NUMBER)
    create_property_for_card(USER_TYPE, USER)
    create_property_for_card(DATE_TYPE, DATE)
    create_property_for_card(CARD_TYPE, RELATED_CARD)
    @transition_only = create_property_for_card(MANAGED_NUMBER_TYPE, TRANSITION_ONLY)
    @transition_only.update_attribute(:transition_only, true)
  end
end
