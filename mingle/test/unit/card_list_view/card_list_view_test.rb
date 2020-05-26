# encoding: UTF-8

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


require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class CardListViewTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def test_should_provide_project_name
    request_params = {:tagged_with => 'status-new,iteration-1', :sort => 'iteration', :order => 'asc', :page => '1', :columns => 'name,status'}
    view = CardListView.find_or_construct(@project, request_params)
    assert_equal @project.name, view.project_name
  end

  def test_should_handle_comma_in_property_name
    with_new_project do |project|
      setup_property_definitions 'story,bug' => ['1', '2'], :status => ['1']
      project.reload.update_card_schema

      request_params = {:columns => 'story\\,bug,status'}
      view = CardListView.find_or_construct(project, request_params)
      assert_equal 'story\\,bug,status', view.to_params[:columns]
      assert_equal 'status', view.remove_column('story,bug').to_params[:columns]
      view = view.remove_column('status')
      assert_equal 'story\\,bug', view.add_column('story,bug').to_params[:columns]
    end
  end

  def test_find_or_construct_should_not_lose_maximized_param
    @project.card_list_views.create_or_update :view => { :name => "team fav" }
    view = CardListView.find_or_construct @project, :view => { :name => 'team fav' }, :maximized => true
    assert_equal true, view.maximized
  end

  def test_cannot_update_a_tabbed_view_to_be_maximized
    login_as_admin do
      view = @project.card_list_views.create_or_update(:view => { :name => "team fav" }, :filters => ['[type][is][card]'])
      assert view.errors.empty?
      view.tab_view = true
      view.save!
      view = @project.card_list_views.create_or_update(:view => { :name => 'team fav' }, :filters => ['[type][is][card]'], :maximized => true)
      assert_equal ['Maximized views cannot be saved as tabs'], view.errors.full_messages
    end
  end

  def test_save_and_find_record
    request_params = {:tagged_with => 'status-new,iteration-1', :sort => 'iteration', :order => 'asc', :page => '1', :columns => 'name,status'}
    view = CardListView.find_or_construct(@project, request_params)
    view.name = 'test name'
    view.save!
    view = CardListView.find_by_name('test name')
    assert_equal request_params[:tagged_with], view.to_params[:tagged_with]
    assert_equal request_params[:sort], view.to_params[:sort]
    assert_equal request_params[:order], view.to_params[:order]
    assert_equal request_params[:columns], view.to_params[:columns]
    assert_nil view.to_params[:page]
  end

  def test_tags_should_be_uniq_and_without_blank
    view = CardListView.find_or_construct(@project, :tagged_with => 'tag, tag, ,')
    assert_equal ['tag'], view.filter_tags
  end

  def test_to_params
    assert_card_list_view_params({}, CardListView.find_or_construct(@project, {}).to_params)
    assert_card_list_view_params({:tagged_with => 'iteration-1,status-fixed'}, CardListView.find_or_construct(@project, {:tagged_with => 'iteration-1,status-fixed'}).to_params)
  end

  def test_tagged_with_can_be_a_list
    assert_equal 'iteration-1,status-fixed',
      CardListView.find_or_construct(@project, {:tagged_with => ['iteration-1', 'status-fixed']}).to_params[:tagged_with]
  end

  def test_can_specify_sort_column_and_order
    assert_card_list_view_params({:sort => 'iteration', :order => 'asc'},
      CardListView.find_or_construct(@project, {:sort => 'iteration'}).to_params)
    assert_card_list_view_params({:sort => 'iteration', :order => 'asc'},
      CardListView.find_or_construct(@project, {:sort => 'iteration', :order => 'asc'}).to_params)
  end

  def test_reset_all_filters
    assert_card_list_view_params({:sort => 'iteration', :order => 'asc'},
      CardListView.find_or_construct(@project, {:tagged_with => ['iteration-1', 'status-fixed'],
        :sort => 'iteration', :order => 'asc'}).reset_all_filters.to_params)
  end

  def test_reset_tab_to_a_view_definition
    open_stories_in_iteration_1 = CardListView.find_or_construct(@project, {:tagged_with => 'iteration-1,status-open,type-story', :sort => 'iteration', :order => 'asc'})
    iteration1 = CardListView.construct_from_params(@project, :tagged_with => 'type-story', :columns => 'status', :sort => 'status', :order => 'desc')
    iteration1.update_attributes(:name => "I1")
    iteration1.tab_view = true
    iteration1.save!

    assert_card_list_view_params({:tagged_with => 'type-story', :columns => 'status', :sort => 'status', :order => 'desc', :tab => 'I1'}, open_stories_in_iteration_1.reset_tab_to("I1").to_params)
  end

  def test_reset_only_filters_to_a_tab_view_definition
    open_stories_in_iteration_1 = CardListView.find_or_construct(@project,
      {:filters => ["[iteration][is][1]", "[status][is][open]", "[old_type][is][story]"],
      :columns => 'status,iteration', :sort => 'iteration', :order => 'desc', :tagged_with => 'rss,foo'})

    iteration1 = CardListView.construct_from_params(@project, {:filters => ["[iteration][is][1]"], :tagged_with => 'rss'})
    iteration1.update_attributes(:name => "I1")
    iteration1.tab_view = true
    iteration1.save!

    @project.reload
    reset_params = open_stories_in_iteration_1.reset_only_filters_to("I1").to_params
    assert_equal 'status,iteration', reset_params[:columns]
    assert_equal 'rss', reset_params[:tagged_with]
    assert_equal(["[Iteration][is][1]"], reset_params[:filters])
    assert_equal 'iteration', reset_params[:sort]
    assert_equal 'desc', reset_params[:order]
  end

  def test_reset_only_filters_to_a_tab_grid_view_definition_should_also_reset_lane_selections
    open_stories_in_iteration_1 = CardListView.find_or_construct(@project,
      {:filters => ["[status][is][open]"],
       :group_by => {:lane => 'status'}, :lanes => 'fixed,new',
       :sort => 'iteration', :order => 'desc',
       :tagged_with => 'rss,foo', :style => 'grid'})
    iteration1 = CardListView.construct_from_params(@project,
      { :filters => ["[iteration][is][1]"],
        :group_by => {:lane => 'status'}, :lanes => 'fixed',
        :tagged_with => 'rss', :style => 'grid'})
    iteration1.update_attributes(:name => "I1")
    iteration1.tab_view = true
    iteration1.save!
    @project.reload
    reset_params = open_stories_in_iteration_1.reset_only_filters_to("I1").to_params
    assert_equal 'fixed', reset_params[:lanes]
  end

  def test_should_clear_normal_filters_when_on_a_tree_tab_with_no_tree_selected
    with_filtering_tree_project do |project|
      tab_view = CardListView.construct_from_params(project,
        {:tf_story => ["[workstream][is][x1]"], :excluded => ['release', 'iteration'], :tagged_with => 'game', :tree_name => tree_name = 'filtering tree',
        :columns => 'Created by', :sort => 'Created by', :order => 'asc'})
      tab_view.update_attributes(:name => 'tree tab view')
      tab_view.tab_view = true
      tab_view.save!
      project.reload

      current_view = CardListView.find_or_construct(project,
        {:filters => ["[Type][is][Story]", "[workstream][is][x1]"], :tagged_with => 'rss', :columns => 'Created by,Modified by', :sort => 'Modified by', :order => 'desc'})
      reset_params = current_view.reset_only_filters_to('tree tab view').to_params
      assert_equal 'Created by,Modified by', reset_params[:columns]
      assert_nil reset_params[:tagged_with]
      assert_nil reset_params[:filters]
      assert_nil reset_params[:tf_story]
      assert_nil reset_params[:excluded]
      assert_nil reset_params[:tree_name]
      assert_equal 'Modified by', reset_params[:sort]
      assert_equal 'desc', reset_params[:order]
    end
  end

  def test_should_clear_tree_filters_when_on_a_non_tree_tab_with_a_tree_selected
    with_filtering_tree_project do |project|
      tab_view = CardListView.find_or_construct(project,
        {:filters => ["[Type][is][Story]", "[workstream][is][x1]"], :tagged_with => 'rss', :columns => 'Created by,Modified by', :sort => 'Modified by', :order => 'desc'})
      tab_view.update_attributes(:name => 'tree tab view')
      tab_view.tab_view = true
      tab_view.save!
      project.reload

      current_view = CardListView.construct_from_params(project,
        {:tf_story => ["[workstream][is][x1]"], :excluded => ['release', 'iteration'], :tagged_with => 'game', :tree_name => tree_name = 'filtering tree',
        :columns => 'Created by', :sort => 'Created by', :order => 'asc'})
      reset_params = current_view.reset_only_filters_to('tree tab view').to_params
      assert_equal 'Created by', reset_params[:columns]
      assert_nil reset_params[:tagged_with]
      assert_nil reset_params[:filters]
      assert_nil reset_params[:tf_story]
      assert_nil reset_params[:excluded]
      assert_equal 'filtering tree', reset_params[:tree_name]
      assert_equal 'Created by', reset_params[:sort]
      assert_equal 'asc', reset_params[:order]
    end
  end

  def test_validates_sort_by_column_based_on_valid_fields
    assert_card_list_view_params({}, CardListView.find_or_construct(@project, {:sort => 'invalid', :order => 'asc'}).to_params)
  end

  def test_can_flip_sort
    assert_card_list_view_params({:sort => 'name', :order => 'asc'},
      CardListView.find_or_construct(@project).flip_sort_params('name'))
    assert_card_list_view_params({:sort => 'name', :order => 'desc'},
      CardListView.find_or_construct(@project, {:sort => 'name'}).flip_sort_params('name'))
    assert_card_list_view_params({:sort => 'name', :order => 'desc'},
      CardListView.find_or_construct(@project, {:sort => 'name', :order => 'asc'}).flip_sort_params('name'))

    assert_card_list_view_params({:sort => 'name', :order => 'desc'},
      CardListView.find_or_construct(@project, CardListView.find_or_construct(@project).flip_sort_params('name')).flip_sort_params('name'))

    assert_card_list_view_params({:sort => 'number', :order => 'asc'},
      CardListView.find_or_construct(@project, CardListView.find_or_construct(@project).flip_sort_params('name')).flip_sort_params('number'))
  end

  def test_consucutive_flipping_of_sort_should_reset_sort_and_order_values
    view = CardListView.find_or_construct(@project, :columns => 'iteration,status')
    view = CardListView.find_or_construct(@project, view.flip_sort_params('iteration'))
    assert_equal CardListView::DEFAULT_ORDER, view.order
    assert_equal 'iteration', view.sort
    assert_equal 'desc', view.flip_sort_params('iteration')[:order]
    assert_equal 'iteration', view.flip_sort_params('iteration')[:sort]
  end

  def test_can_add_columns
    assert_card_list_view_params({:columns => 'iteration'}, CardListView.find_or_construct(@project).add_column('iteration').to_params)
    assert_card_list_view_params({:columns => 'iteration,release'}, CardListView.find_or_construct(@project).add_column('iteration').add_column('release').to_params)
    assert_card_list_view_params({}, CardListView.find_or_construct(@project, :columns => 'invalid').to_params)

    assert CardListView.find_or_construct(@project, :columns => 'iteration').has_column?('iteration')
    assert !CardListView.find_or_construct(@project, :columns => 'invalid').has_column?('invalid')

    view = CardListView.find_or_construct(@project)
    new_view = view.add_column('iteration')
    assert !view.has_column?('iteration')
    assert new_view.has_column?('iteration')
  end

  def test_remove_columns
    view = CardListView.find_or_construct(@project, {:columns => 'iteration'})
    new_view = view.remove_column('iteration')
    assert view.has_column?('iteration')
    assert_equal 'iteration', view.to_params[:columns]
    assert !new_view.has_column?('iteration')
    assert_nil new_view.to_params[:columns]
  end

  def test_can_remove_columns_which_will_reset_sort_if_sorted_on
    assert_card_list_view_params({}, CardListView.find_or_construct(@project, :columns => 'iteration').remove_column('iteration').to_params)
    assert_card_list_view_params({}, CardListView.find_or_construct(@project, :columns => 'iteration', :sort => 'iteration').remove_column('iteration').to_params)
  end

  def test_paginator_sets_last_page_correctly_based_on_page_parameter
    view = CardListView.find_or_construct(project_without_cards, {:page => 5})
    def view.card_search_options
      {:limit => 25}
    end
    def view.card_count
      100
    end
    assert_equal({:limit => 25, :offset => 75}, view.paginator.limit_and_offset)
    assert view.current_page?(4)
  end

  def test_paginator_sets_first_page_correctly_based_on_page_parameter
    view = CardListView.find_or_construct(project_without_cards, {:page => 0})
    def view.card_search_options
      {:limit => 25}
    end
    def view.card_numbers
      (0..100).to_a
    end
    assert_equal({:limit => 25, :offset => 0}, view.paginator.limit_and_offset)
    assert view.current_page?(1)
  end

  def test_paginator_uses_cards_per_page_when_specified
    view = CardListView.find_or_construct(project_without_cards, {:page => 4, :page_size => 10})
    def view.card_count
      100
    end
    assert_equal({:limit => 10, :offset => 30}, view.paginator.limit_and_offset)
    assert view.current_page?(4)
  end

  def test_should_generate_page_links_with_params_if_view_not_saved
    view  = CardListView.find_or_construct(@project, {:tagged_with => 'status-fixed,iteration-1', :page => 2})
    def view.paginator
      Paginator.new(200, 25, 2)
    end
    assert_equal 2, view.next_page_link.size
    assert_equal 3, view.next_page_link[:page]
    assert_equal 'status-fixed,iteration-1', view.next_page_link[:tagged_with]
    assert_equal 1, view.pre_page_link[:page]
    assert_equal 'status-fixed,iteration-1', view.pre_page_link[:tagged_with]
  end

  def test_create_or_update_with_case_insensitive
    down_case_view = @project.card_list_views.create_or_update({:view => {:name => "iteration-1"}, :tagged_with => 'iteration-1'})
    assert_equal @project, down_case_view.project
    assert_equal 'iteration-1', down_case_view.name
    assert_equal 'iteration-1', down_case_view.to_params[:tagged_with]
    assert_equal 1, @project.card_list_views.find(:all).size
    upper_case_view = @project.card_list_views.create_or_update({:view => {:name => 'Iteration-1 '}, :tagged_with => 'iteration-1,type-story'})
    assert_equal "Iteration-1", upper_case_view.name
    assert_equal 'iteration-1,type-story', upper_case_view.to_params[:tagged_with]
    assert_equal 1, @project.card_list_views.find(:all).size
    assert_equal upper_case_view.name, @project.card_list_views.find(:first).name
  end

  # Bug 5315.
  def test_find_or_construct_should_be_case_insensitive
    original_view = @project.card_list_views.create_or_update({:view => {:name => "iteration-1"}, :tagged_with => 'iteration-1'})
    found_view = CardListView.find_or_construct(@project, {:view => {:name => 'Iteration-1'}})
    assert_not_nil(found_view)
    assert_equal(original_view.id, found_view.id)
  end

  def test_page_title_driven_by_named_view
    high_open_bugs = CardListView.find_or_construct(@project, {:tagged_with => 'type-bug,Status-open,priority-high', :tab => 'High Open Bugs'})
    high_open_bugs.name = "High Open Bugs"
    assert_equal "Project One High Open Bugs", high_open_bugs.page_title
  end

  def test_page_title_driven_by_tab_name
    bugs = CardListView.find_or_construct(@project, {:tagged_with => 'type-bug'})
    bugs.name = 'Bugs'
    bugs.save!

    bugs.tab_view = true
    bugs.save!

    unnamed_high_open_bugs = CardListView.find_or_construct(@project.reload, {:tagged_with => 'type-bug,Status-open,priority-high', :tab => 'Bugs'})
    assert_equal 'Project One Bugs', unnamed_high_open_bugs.page_title
  end

  def test_page_title_driven_by_tab_name_escapes_html
    bugs = CardListView.find_or_construct(@project, {:tagged_with => 'type-bug'})
    bugs.name = 'Bugs'
    bugs.save!

    bugs.tab_view = true
    bugs.save!

    unnamed_high_open_bugs = CardListView.find_or_construct(@project.reload, {:tagged_with => 'type-bug,Status-open,priority-high', :tab => 'Bugs<a>'})
    assert_equal 'Project One Bugs&lt;a&gt;', unnamed_high_open_bugs.page_title
  end

  def test_page_title_defaults_to_cards
    unnamed_high_open_bugs = CardListView.find_or_construct(@project, {:tagged_with => 'type-bug,Status-open,priority-high', :tab => 'All'})
    assert_equal 'Project One Cards', unnamed_high_open_bugs.page_title
  end

  def test_validates_view_style
    assert_equal 'list', CardListView.construct_from_params(@project, {:style => 'list'}).style.to_s
    assert_equal 'grid', CardListView.construct_from_params(@project, {:style => 'grid'}).style.to_s
    assert_equal 'list', CardListView.construct_from_params(@project, {:style => 'hackhack'}).style.to_s
    assert_equal 'list',  CardListView.construct_from_params(@project, {}).style.to_s
  end

  def test_can_convert_to_card_query
    view = CardListView.find_or_construct(@project, {})
    assert_equal_ignoring_spaces 'SELECT Number, Name Order by Number DESC', view.as_card_query.to_s

    request_params = {:sort => 'iteration',
      :filters => ["[status][is][new]", "[iteration][is][1]", "[iteration][is][2]"],
      :order => 'asc', :page => '1', :columns => 'status'}
    view = CardListView.find_or_construct(@project, request_params)
    view.name = 'test name'
    view.save!
    view = @project.card_list_views.find_by_name('test name')

    assert_equal_ignoring_order(
      "SELECT Number, Name, Status WHERE ((Iteration is 2 OR Iteration is 1) AND Status is new) ORDER BY Iteration asc, Number desc",
      view.as_card_query.to_s)
    assert view.as_card_query.to_sql
  end

  def test_should_know_equality_between_identical_views
    open_high_bugs = CardListView.construct_from_params(@project, {:tagged_with => 'important', :columns => 'old_type,priority', :sort => 'old_type', :order => 'ASC', :filters => ["[old_type][is][bug]", "[Status][is][open]", "[priority][is][high]"]})
    another_open_high_bugs = CardListView.construct_from_params(@project, {:tagged_with => 'important', :columns => 'priority,old_type', :sort => 'old_Type', :order => 'ASC', :filters => ["[old_type][is][bug]", "[status][is][open]", "[PRIORITY][is][high]"]})
    open_stories = CardListView.construct_from_params(@project, {:tagged_with => 'type-story,status-open'})
    open_high_bug_grid = CardListView.construct_from_params(@project, {:style => 'grid', :tagged_with => 'important', :columns => 'old_type,priority', :sort => 'old_type', :order => 'ASC', :filters => ["[old_type][is][bug]", "[Status][is][open]", "[priority][is][high]"]})
    assert open_high_bugs == another_open_high_bugs
    assert open_high_bugs != open_high_bug_grid
    assert open_high_bugs != open_stories
  end

  def test_equality_between_mql_filter_views
    one = CardListView.construct_from_params(@project, {:style => 'grid', :filters => {:mql => 'type = story'}} )
    two = CardListView.construct_from_params(@project, {:style => 'grid', :filters => {:mql => 'type = story'}} )
    nil_mql = CardListView.construct_from_params(@project, {:style => 'grid', :filters => {:mql => nil}} )
    blank_mql = CardListView.construct_from_params(@project, {:style => 'grid', :filters => {:mql => ""}} )
    assert one == two
    assert one != nil_mql
    assert nil_mql == blank_mql
  end

  def test_list_should_order_by_name_and_not_case_sensitive
    assert_equal 0, @project.card_list_views_with_sort.size
    create_card_list_view("iteration-5", :filters => ["[iteration][is][1]"])
    create_card_list_view("Bugs", :filters => ["[old_type][is][bug]"])
    create_card_list_view("Iteration-14",:filters => ["[iteration][is][2]"])
    create_card_list_view("apple",:filters => ["[system][is][apple]"])

    views = @project.reload.card_list_views_with_sort
    assert_equal 4, views.size
    assert_equal "apple", views[0].name
    assert_equal "Bugs", views[1].name
    assert_equal "iteration-5", views[2].name
    assert_equal "Iteration-14", views[3].name

  end

  def test_should_generate_page_links_with_params_if_view_not_saved
    view  = CardListView.find_or_construct(@project,
                    {:filters => ["[status][is][fixed]", "[iteration][is][1]", "[empty][is][]"],
                     :tagged_with => 'rss',
                     :page => 2})
    assert_equal 'fixed', view.filters.value_for('status')
    assert_equal '1', view.filters.value_for('iteration')
    assert !view.filters.valid_properties.include?('rss')
  end

  def test_should_merge_filter_properties_into_tagged_with
    view  = CardListView.find_or_construct(@project, :filters => ["[status][is][fixed]", "[iteration][is][1]", "[stage][is][]"])
    assert_equal 'fixed', view.filters.value_for('status')
  end

  def test_card_conditions_ands_multiple_conditions
    project = project_without_cards
    project.activate
    property_def = project.find_property_definition('completed in iteration')
    view = CardListView.find_or_construct(project, :filters => ["[Completed In Iteration][is][2]", "[status][is][new]"])
    assert_equal "('Completed in iteration' is 2 AND Status is new)", view.as_card_query.conditions.to_s
  end

  def test_card_conditions_do_not_include_bogus_properties
    view = CardListView.find_or_construct(@project, :filters => ["[Undefined Property][is][2]"])
    assert_nil view.as_card_query.conditions
  end

  def test_card_conditions_ignore_bogus_properties_but_keep_good_properties
    view = CardListView.find_or_construct(@project, :filters => ['[Bogus Property][is][2]', '[Status][is][new]'])
    assert_equal 'Status is new', view.as_card_query.conditions.to_s
  end

  def test_card_conditions_ignore_properties_with_ignored_values
    view = CardListView.find_or_construct(@project, :filters => ["[status][is][#{PropertyValue::IGNORED_IDENTIFIER}]"])
    assert_nil view.as_card_query.conditions
  end

  def test_card_conditions_works_with_properties_that_are_not_finite_valued
    view = CardListView.find_or_construct(@project, :filters => ['[id][is][23]'])
    assert_equal 'id is 23', view.as_card_query.conditions.to_s
  end

  def test_card_conditions_filter_with_empty_values
    view = CardListView.find_or_construct(@project, :filters => ['[Status][is][]'])
    assert_equal('Status IS NULL', view.as_card_query.conditions.to_s)
    assert_equal("#{Project.connection.quote_column_name('cp_status')}.#{Project.connection.quote_column_name('position')} IS NULL", view.as_card_query.conditions.to_sql)
  end

  def test_filter_properties_can_be_saved_to_db
    @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :filters => ["[Status][is][new]"])
    assert_equal 'new', CardListView.find_or_construct(@project, :view => 'view 1').filters.value_for('status')
  end

  def test_create_or_update_saves_maximized_param
    @project.card_list_views.create_or_update(:view => {:name => 'maximized_view'}, :maximized => true)
    assert_equal true, CardListView.find_or_construct(@project, :view => 'maximized_view').params[:maximized]
  end

  def test_to_params_should_not_contain_maximized_parameter_if_not_maximized
    @project.card_list_views.create_or_update(:view => {:name => 'maximized_view'}, :maximized => false)
    assert_nil CardListView.find_or_construct(@project, :view => 'maximized_view').to_params[:maximized]
  end

  def test_rename_property_updates_all_filters_columns_and_sort_fileds_in_list_views
    with_new_project do |p|
      setup_property_definitions :feeture => ['cards']
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'list',
        :filters => ["[Feeture][is][cards]"], :columns => ['feeture'], :sort => 'FEETURE')

      view.rename_property('feeture', 'Feature')
      assert_equal(["[Feature][is][cards]"], view.filters.to_params)
      assert_equal(['Feature'], view.columns)
      assert_equal('Feature', view.sort)
    end
  end

  def test_rename_property_updates_all_filters_columns_and_sort_fileds_in_list_views
    with_new_project do |p|
      setup_property_definitions :feeture => ['cards']
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'list',
        :filters => ["[Feeture][is][cards]"], :columns => ['feeture'], :sort => 'FEETURE')

      view.rename_property('feeture', 'Feature')
      assert_equal(["[Feature][is][cards]"], view.filters.to_params)
      assert_equal(['Feature'], view.columns)
      assert_equal('Feature', view.sort)
    end
  end

  def test_rename_property_should_update_lanes_group_by_color_by_and_aggregate_properties_in_grid_views
    with_new_project do |p|
      setup_numeric_property_definition('feeture', [1, 2, 3])
      view = p.card_list_views.create_or_update(:view => {:name => 'view 2'}, :style => 'grid',
        :group_by => 'feeture', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'feeture'})

      view.rename_property('feeture', 'Feature')
      assert_equal({:lane => 'Feature'}, view.to_params[:group_by])
      assert_equal('Feature', view.aggregate_property)
    end
  end

  def test_rename_property_does_not_set_nil_fields
    with_new_project do |p|
      setup_property_definitions :feeture => ['cards'],:iteration => ['1']
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :filters => ["[iteration][is][1]"])
      view.rename_property('Feeture', 'Feature')
      assert 1, view.filters.size
      assert view.columns.empty?
      assert_nil view.sort
      assert_nil view.to_params[:group_by]
      assert_nil view.color_by
      assert_nil view.aggregate_property
    end
  end

  def test_change_tree_names
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      view = project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'tree', :tree_name => 'planning')
      view.change_tree_config_name('Planning', 'Release planning')
      assert_equal 'Release planning', view.reload.tree_name
    end
  end

  def test_should_update_filter_properties_when_rename_property_value
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :filters => ["[stage][is][cerds]", "[stage][is][cerds]"])
    view.rename_property_value('stage', 'cerds', 'cards')
    assert_equal(['[Stage][is][cards]', '[Stage][is][cards]'], view.reload.filters.to_params)
  end

  def test_should_update_tree_filter_properties_when_rename_card_type
    with_filtering_tree_project do |project|
      tree_config = project.tree_configurations.find_by_name('filtering tree')

      view = project.card_list_views.create_or_update(:view => {:name => 'the man in the capri pants'}, :tf_reLease => ['[workstream][is][X1]'], :tf_iteration => ['[workstream][is][x2]'], :excluded => ['rELEAse', 'task'], :tree_name => tree_config.name)
      view.rename_card_type('release', 'capture')
      assert_equal({:tf_capture => ['[workstream][is][X1]'], :tf_iteration => ['[workstream][is][x2]'], :excluded => ['capture', 'task']}, view.reload.filters.to_params)
    end
  end

  # bug 4671
  def test_should_tree_filter_params_should_always_come_out_with_downcased_card_type_name
    with_filtering_tree_project do |project|
      tree_config = project.tree_configurations.find_by_name('filtering tree')

      view = project.card_list_views.create_or_update(:view => {:name => 'zing!'}, :tf_release => ['[workstream][is][X1]'], :tree_name => tree_config.name)
      view.rename_card_type('release', 'Release')
      assert_equal({:tf_release => ['[workstream][is][X1]']}, view.reload.filters.to_params)
      assert_equal ['[workstream][is][X1]'], view.params_for_current_page[:tf_release]

      view.rename_card_type('release', 'Zinga')
      assert_equal({:tf_zinga => ['[workstream][is][X1]']}, view.reload.filters.to_params)
    end
  end

  def test_should_update_tree_filter_properties_when_rename_property_definition
    with_filtering_tree_project do |project|
      tree_config = project.tree_configurations.find_by_name('filtering tree')

      view = project.card_list_views.create_or_update(:view => {:name => 'the man in the capri pants'}, :tf_reLease => ['[workStrEAM][is][x1]'], :tf_iteRATion => ['[worksTrEAM][is][x2]'], :tf_sTOrY => ['[WORkstreaM][is][x3]'], :excluded => ['task', 'minutia'], :tree_name => tree_config.name)
      view.rename_property('workstream', 'playriver')
      assert_equal({:tf_release => ['[playriver][is][x1]'], :tf_iteration => ['[playriver][is][x2]'], :tf_story => ['[playriver][is][x3]'], :excluded => ['task', 'minutia']}, view.reload.filters.to_params)
    end
  end

  def test_should_update_tree_filter_properties_when_rename_property_value
    with_filtering_tree_project do |project|
      tree_config = project.tree_configurations.find_by_name('filtering tree')

      view = project.card_list_views.create_or_update(:view => {:name => 'the man in the capri pants'}, :tf_reLease => ['[workstream][is][X1]'], :tf_iteRATion => ['[workstream][is][x1]'], :tf_sTOrY => ['[workstream][is][x3]'], :excluded => ['task', 'minutia'], :tree_name => tree_config.name)
      view.rename_property_value('workstream', 'x1', 'superfly')
      assert_equal({:tf_release => ['[workstream][is][superfly]'], :tf_iteration => ['[workstream][is][superfly]'], :tf_story => ['[workstream][is][x3]'], :excluded => ['task', 'minutia']}, view.reload.filters.to_params)
    end
  end

  def test_should_update_lanes_when_rename_property_value
    with_new_project do |p|
      setup_property_definitions :feature => ['cerds']
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :lanes => 'cerds', :group_by => 'feature')
      assert view.rename_property_value('feature', 'cerds', 'cards')
      assert_equal('cards', view.reload.to_params[:lanes])
    end
  end

  def test_should_update_group_by_after_rename_property_definition
    with_new_project do |project|
      setup_property_definitions :feature => ['cards']
      view = project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => 'feature')
      view.rename_property('feature', 'feeer')
      assert_equal({:lane => 'feeer'}, view.reload.to_params[:group_by])
    end
  end

  def test_should_update_date_format_after_project_date_format_is_changed
    @project.date_format = Date::DAY_LONG_MONTH_YEAR
    @project.save!
    view = @project.card_list_views.find_or_construct(@project, :filters => ["[Type][is][Card]", "[start date][is][03 Feb 2003]", "[start date][is][(TODay)]"])
    view.name = "Date Check"
    view.save!

    @project.reload

    assert_equal ["[Type][is][Card]", "[start date][is][03 Feb 2003]", "[start date][is][(TODay)]"], view.reload.filters.to_params
    @project.date_format = Date::MONTH_DAY_YEAR
    @project.save!

    view = @project.card_list_views.find_by_name('Date Check')
    assert_equal ["[Type][is][Card]", "[start date][is][02/03/2003]", "[start date][is][(TODay)]"], view.filters.to_params

    @project.date_format = Date::DAY_MONTH_YEAR
    @project.save!

    view = @project.card_list_views.find_by_name('Date Check')
    assert_equal ["[Type][is][Card]", "[start date][is][03/02/2003]", "[start date][is][(TODay)]"], view.filters.to_params
  end

  def test_update_date_format_ignores_special_values
    @project.date_format = Date::DAY_LONG_MONTH_YEAR
    @project.save!

    view = @project.card_list_views.find_or_construct(@project, :filters => ["[Type][is][Card]", "[start date][is][]"])
    view.name = "No Start Date"
    view.save!

    view.update_date_format(Date::DAY_LONG_MONTH_YEAR, Date::MONTH_DAY_YEAR)
    assert_equal "", view.filters.detect{|f| f.property_definition.name == 'start date'}.value

    view = @project.card_list_views.find_or_construct(@project, :filters => ["[Type][is][Card]", "[start date][is][(today)]"])
    view.name = "Starts today"
    view.save!

    view.update_date_format(Date::DAY_LONG_MONTH_YEAR, Date::MONTH_DAY_YEAR)
    assert_equal "(today)", view.filters.detect{|f| f.property_definition.name == 'start date'}.value
  end

  def test_column_property_definitions_only_contains_specified_columns
    view = CardListView.find_or_construct(@project, :columns => 'Release')
    assert_equal 1, view.column_property_definitions.size
    assert_equal 'Release', view.column_property_definitions.first.name
  end

  def test_add_remove_column_should_remember_page
    view = CardListView.find_or_construct(@project, :columns => 'Release,Status', :page => '18')
    assert_equal "18", view.page
    assert_equal "18", view.remove_column('Status').page
    assert_equal "18", view.remove_column('Status').add_column('Status').page
  end

  def test_remove_column_should_not_contains_page_if_removing_a_sort_column
    view = CardListView.find_or_construct(@project, :columns => 'Release,Status', :page => '18', :sort => 'Status')
    assert_equal "1", view.remove_column('Status').page
  end

  def test_if_definition_of_any_filter_property_do_not_exists_view_should_return_no_cards
    create_card!(:name => 'first card', :release => '1', :status => 'open')
    create_card!(:name => 'second card', :release => '1', :status => 'open')
    create_card!(:name => 'last card', :release => '1')
    assert_equal [], create_card_list_view("open cards", :filters => ["[release][is][1]", "[states][is][open]"]).cards
  end

  def test_can_add_created_by_column
    view = CardListView.find_or_construct(@project, {}).add_column('Created by')
    assert_card_list_view_params({:columns => 'Created by'}, view.to_params)
    assert_equal ['Created by'], view.columns
    assert_equal ['Created by'], view.column_property_definitions.collect(&:name)
  end

  def test_any_project_member_can_update_tab_view
    login_as_admin
    view = @project.card_list_views.create_or_update(:view => { :name => "team fav" }, :filters => ['[type][is][card]'])
    view.tab_view = true
    view.save!
    login_as_member
    view = @project.card_list_views.create_or_update(:view => { :name => 'team fav' }, :filters => ['[status][is][new]'])
    assert view.errors.none?
  end

  def test_cards_should_be_sorted
    member = User.find_by_login('member')
    admin = User.find_by_login('admin')
    proj_admin = User.find_by_login('proj_admin')
    create_project(:users => [member, admin, proj_admin]) do |project|
      setup_property_definitions :old_type => ['bug', 'risk', 'story']
      dev_column_name = setup_user_definition('dev').column_name.to_sym
      type_column_name = project.find_property_definition(:old_type).column_name.to_sym
      card1 = create_card!(:name => 'card 1', :dev => member.id, :old_type => 'story')
      card2 = create_card!(:name => 'card 2', :dev => proj_admin.id, :old_type => 'bug')
      card3 = create_card!(:name => 'card 3', :dev => admin.id, :old_type => 'risk')

      view = CardListView.find_or_construct(project, {:sort => 'old_type'})
      assert_equal [card2, card3, card1].collect(&type_column_name), view.cards.collect(&type_column_name)

      sorted_user_names = project.users.collect(&:name).sort
      view = CardListView.find_or_construct(project, {:sort => 'dev'})
      assert_equal sorted_user_names, user_names(view.cards, dev_column_name)

      view = CardListView.find_or_construct(project, {:sort => 'dev', :order => 'desc'})
      assert_equal sorted_user_names.reverse, user_names(view.cards, dev_column_name)
    end
  end

  def test_params_for_current_page_drops_grid_specific_params_when_list
    view = CardListView.find_or_construct(@project, {:columns => 'status', :filters => ['[release][is][1]'],
      :tagged_with => 'rss', :sort => 'status', :order => 'asc', :group_by => 'release', :color_by => 'priority',
      :lanes => '1,2', :page => '3', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'size'}})
    params = view.params_for_current_page

    assert_equal 'status', params.find_ignore_case('columns')
    assert_equal(['[Release][is][1]'], params.find_ignore_case('filters'))
    assert_equal 'rss', params.find_ignore_case('tagged_with')
    assert_equal 'status', params.find_ignore_case('sort')
    assert_equal 'asc', params.find_ignore_case('order')
    assert !params.key?(:group_by)
    assert !params.key?(:color_by)
    assert !params.key?(:lanes)
    assert !params.key?(:aggregate_type)
    assert !params.key?(:aggregate_property)
    assert_equal '3', params.find_ignore_case('page')
    assert_equal 'list', params.find_ignore_case('style')
  end

  def test_params_for_current_page_drops_list_specific_params_when_grid
    view = CardListView.find_or_construct(@project, {:columns => 'status', :filters => ['[release][is][1]'],
      :tagged_with => 'rss', :sort => 'status', :order => 'asc', :group_by => 'release', :color_by => 'priority',
      :lanes => '1,2', :page => '3', :style => 'grid'})
    params = view.params_for_current_page

    assert !params.key?(:columns)
    assert_equal(['[Release][is][1]'], params.find_ignore_case('filters'))
    assert_equal 'rss', params.find_ignore_case('tagged_with')
    assert !params.key?(:sort)
    assert !params.key?(:order)
    assert_equal({:lane => 'release'}, params.find_ignore_case('group_by'))
    assert_equal 'priority', params.find_ignore_case('color_by')
    assert_equal '1,2', params.find_ignore_case('lanes')
    assert !params.key?(:page)
    assert_equal 'grid', params.find_ignore_case('style')
  end

  # bug 1574
  def test_filter_card_list_by_user_property
    project = create_project(:prefix => 'filter project', :users => [User.find_by_login('first'), User.find_by_login('member')])
    setup_user_definition('owner')
    first_user = project.users.find_by_login('first')
    card1 = create_card!(:name => 'first card', :owner => first_user.id)
    card2 = create_card!(:name => 'second card', :owner => first_user.id)
    card3 = create_card!(:name => 'third card', :owner => project.users.find_by_login('member').id)
    view = CardListView.find_or_construct(project.reload, {:filters => ["[owner][is][#{first_user.login}]"]})
    assert_equal [card1, card2].sort_by(&:number).collect(&:name), view.cards.sort_by(&:number).collect(&:name)
  end

  def test_should_be_able_to_filter_by_empty_properties
    view = CardListView.find_or_construct(@project, {:filters => ['[status][is][]']})
    assert_equal(['[Status][is][]'], view.filters.to_params)
    assert_card_list_view_params({:action=>"list", :filters=>["[Status][is][]"]}, view.to_params)
    assert_equal @project.cards.reject { |card| card.cp_status }.size, view.cards.size
  end

  def test_should_find_all_cards_with_either_value_if_filter_contains_multiple_values_for_a_property
    card1 = @project.cards.create!(:name => 'card name', :card_type_name => 'Card', :cp_status => 'fixed', :cp_iteration => '1' )
    card2 = @project.cards.create!(:name => 'card name', :card_type_name => 'Card', :cp_status => 'new', :cp_iteration => '1' )
    card3 = @project.cards.create!(:name => 'card name', :card_type_name => 'Card', :cp_status => 'open', :cp_iteration => '1' )
    card4 = @project.cards.create!(:name => 'card name', :card_type_name => 'Card', :cp_status => 'fixed', :cp_iteration => '2' )

    view = CardListView.find_or_construct(@project, {:filters => ['[iteration][is][1]', '[status][is][fixed]', '[status][is][new]']})
    assert_equal 2, view.cards.size
    assert view.cards.include?(card1)
    assert view.cards.include?(card2)

    view = CardListView.find_or_construct(@project, {:filters => ['[iteration][is][1]', '[status][is][fixed]', '[iteration][is][2]']})
    assert_equal 2, view.cards.size
    assert view.cards.include?(card1)
    assert view.cards.include?(card4)
  end

  def test_error_message_when_using_a_completely_rubbish_filter_property
    with_new_project do |project|
      view = CardListView.find_or_construct(project, :filters => ["[Bogus][is][rubbish]", "[Bogus][is][really rubbish]"])
      assert_equal "Property #{'Bogus'.bold} does not exist.", view.filters.validation_errors.join
    end
  end

  def test_error_message_when_using_an_existing_property_which_is_invalid_for_current_type_filter
    with_new_project do |project|
      story_type = project.card_types.create(:name => 'story')
      bug_type = project.card_types.create(:name => 'bug')

      setup_property_definitions 'Story size' => ['4']
      setup_property_definitions 'Bug status' => ['open']

      story_size = project.find_property_definition('story size')
      bug_status = project.find_property_definition('bug status')

      story_size.card_types = [story_type]
      story_size.save!

      bug_status.card_types = [bug_type]
      bug_status.save!

      view = CardListView.find_or_construct(project, :filters => ["[Type][is][story]", "[bug status][is][open]"])
      assert_equal "Property #{'Bug status'.bold} is not valid for card type #{'story'.bold}.", view.filters.validation_errors.join
    end
  end

  def test_error_message_when_using_multiple_values_for_a_card_property_should_not_show_duplicates_in_error_messages
    with_new_project do |project|
      story_type = project.card_types.create(:name => 'story')
      bug_type = project.card_types.create(:name => 'bug')

      setup_property_definitions 'Story size' => ['1', '2', '4']
      setup_property_definitions 'Bug status' => ['open']

      story_size = project.find_property_definition('story size')
      bug_status = project.find_property_definition('bug status')

      story_size.card_types = [story_type]
      story_size.save!

      bug_status.card_types = [bug_type]
      bug_status.save!

      project.reload

      view = CardListView.find_or_construct(project, :filters => ["[Type][is][bug]", "[Type][is][bug]", "[Story size][is][1]", "[Story size][is][4]"])
      assert_equal "Property #{'Story size'.bold} is not valid for card type #{'bug'.bold}.", view.filters.validation_errors.join
    end
  end

  def test_error_message_when_using_type_specific_property_without_a_type_filter
    with_new_project do |project|
      story_type = project.card_types.create(:name => 'story')
      setup_property_definitions 'feature' => ['type specific properties']
      setup_property_definitions 'Story status' => ['open', 'closed']

      feature = project.find_property_definition('feature')
      story_size = project.find_property_definition('story status')

      feature.card_types = project.reload.card_types
      feature.save!

      story_size.card_types = [story_type]
      story_size.save!

      view = CardListView.find_or_construct(project, :filters => ["[Story status][is][open]", "[Story status][is][closed]"])
      assert_equal "Please filter by appropriate card type in order to filter by property #{'Story status'.bold}.", view.filters.validation_errors.join

      view = CardListView.find_or_construct(project, :filters => ["[feature][is][type specific properties]"])
      assert view.filters.validation_errors.blank?
    end
  end

  def test_error_message_when_using_not_set_values_with_incorrect_operators
    with_new_project do |project|
      setup_date_property_definition 'started on'
      view = CardListView.find_or_construct(project, :filters => ["[stARted ON][is before][]"])
      assert_equal "#{'(not set)'.bold} is not a valid filter for operator #{'is before'.bold}", view.filters.validation_errors.join
      view = CardListView.find_or_construct(project, :filters => ["[stARted ON][is GREATER than][]"])
      assert_equal "#{'(not set)'.bold} is not a valid filter for operator #{'is after'.bold}", view.filters.validation_errors.join
    end
  end

  # bug 5646
  def test_describe_current_filters_has_spaces_and_periods_between_sentences
    with_filtering_tree_project do |project|
      tab_view = CardListView.construct_from_params(project,
        { :tf_story => ["[workstream][is][x1]"], :tf_iteration => ["[quick_win][is][yes]"], :excluded => ['release', 'iteration'], :tagged_with => 'game', :tree_name => tree_name = 'filtering tree',
          :columns => 'Created by', :sort => 'Created by', :order => 'asc' })

      assert_equal tab_view.describe_current_filters, "Current cards: Do not show #{'release'.bold} and #{'iteration'.bold} cards. iteration filter: quick_win is #{'yes'.bold}. story filter: workstream is #{'x1'.bold}."
    end
  end
  # bug 5059
  def test_describe_current_filters_should_be_all_when_the_filter_is_empty
    with_filtering_tree_project do |project|
      view = CardListView.construct_from_params(project, {})
      assert_equal "Current cards: All", view.describe_current_filters
    end
  end

  def test_card_list_view_should_not_store_unapplicable_params
    list_view = CardListView.find_or_construct(@project, :style => 'list', :group_by => 'status', :color_by => 'priority', :lanes =>'open,close', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'size'} )
    list_view.name = 'I am list view'
    assert_equal 'list', list_view.style.to_s
    assert_equal({:lane => 'status'}, list_view.to_params[:group_by])
    assert_equal 'priority', list_view.color_by
    assert_equal 'open,close', list_view.group_lanes.to_params[:lanes]
    list_view.save!
    list_view = CardListView.find_by_name('I am list view')
    assert_equal 'list', list_view.style.to_s
    assert_equal nil, list_view.to_params[:group_by]
    assert_equal nil, list_view.color_by
    assert_equal nil, list_view.aggregate_property
    assert_equal nil, list_view.aggregate_type
    assert_equal nil, list_view.group_lanes.to_params[:lanes]
  end

  def test_card_list_view_for_grid_should_not_store_unapplicable_params
    list_view = CardListView.find_or_construct(@project, :style => 'grid', :sort => 'status', :order => 'asc', :columns =>'name,status', :page => 1)
    list_view.name = 'I am grid view'
    assert_equal 'grid', list_view.style.to_s
    assert_equal 'status', list_view.sort
    assert_equal 'asc', list_view.order
    assert_equal ['name','status'], list_view.columns
    list_view.save!
    list_view = @project.card_list_views.find(list_view.id)
    assert_equal 'grid', list_view.style.to_s
    assert_equal nil, list_view.sort
    assert_equal nil, list_view.order
    assert list_view.columns.blank?
  end

  def test_should_not_compare_default_styles_in_equality_checking
    list_view = CardListView.find_or_construct(@project, :style => 'list')
    all_view = CardListView.find_or_construct(@project, {})
    assert (list_view == all_view)
  end

  def test_should_return_tree_style_if_specify_tree_style
    create_planning_tree_project do |project, tree|
      view = CardListView.find_or_construct(project, :style => 'tree', :tree_name => 'Planning')
      assert_card_list_view_params({:style => 'tree', :tree_name=>"Planning"}, view.to_params)
    end
  end

  def test_cards_and_card_numbers_should_be_empty_when_filters_is_invalid
    view = CardListView.find_or_construct(@project, :filters => ["[xx][is][invalid]"])
    assert_equal [], view.cards
    assert_equal [], view.card_numbers
  end


  def test_should_remove_group_by_when_it_is_invalid_in_filters
    with_new_project do |project|
      story_type = project.card_types.create(:name => 'story')
      bug_type = project.card_types.create(:name => 'bug')

      setup_property_definitions 'Story size' => ['4', '5']

      story_size = project.find_property_definition('story size')

      story_size.card_types = [story_type]
      story_size.save!

      project.reload

      view = CardListView.find_or_construct(project, :filters => ["[Type][is][bug]"], :style => 'grid', :group_by => 'story size', :lanes => '4,5')
      assert_equal 'grid', view.style.to_s
      assert_nil view.to_params[:group_by]
      assert_equal [''], view.visible_lanes
      assert_equal({:filters=>["[Type][is][bug]"], :action=>"list", :style => 'grid', :tab => 'All'}, view.to_params)
    end
  end

  def test_sort_grid_by_number_ascending
    bug_type = @project.card_types.create(:name => 'bug')
    bug1 = create_card!(:name => 'bug1', :card_type => bug_type)
    bug2 = create_card!(:name => 'bug2', :card_type => bug_type)
    view = CardListView.find_or_construct(@project, :filters => ["[Type][is][bug]"], :style => 'grid', :grid_sort_by => 'Number')
    assert_equal 'Number', view.to_params[:grid_sort_by]
    assert_equal ['bug1', 'bug2'], view.cards.collect(&:name)
  end

  def test_should_remove_aggregate_values_when_they_are_not_valid
    release = @project.find_property_definition('release')
    status = @project.find_property_definition('status')

    view = CardListView.find_or_construct(@project, :style => 'grid', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'status'})
    assert_nil view.aggregate_type
    assert_nil view.aggregate_property
    assert_equal({:action=>"list", :style=>"grid", :tab=>"All"}, view.to_params)

    view = CardListView.find_or_construct(@project, :style => 'grid', :aggregate_type => {:column => 'asd'}, :aggregate_property => {:column => 'release'})
    assert_nil view.aggregate_type
    assert_nil view.aggregate_property
    assert_equal({:action=>"list", :style=>"grid", :tab=>"All"}, view.to_params)

    view = CardListView.find_or_construct(@project, :style => 'grid', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => nil})
    assert_nil view.aggregate_type
    assert_equal({:action=>"list", :style=>"grid", :tab=>"All"}, view.to_params)
  end

  def test_tree_view_should_be_dirty_if_tree_name_changed
    @project.tree_configurations.create!(:name => 'first tree')
    @project.tree_configurations.create!(:name => 'another tree')
    view = CardListView.find_or_construct(@project, :style => 'tree', :tree_name => 'first tree')
    view.update_attributes(:name => "One")
    another = CardListView.find_or_construct(@project, :style => 'tree', :tree_name => 'another tree')
    view.update_attributes(:name => "Two")
    assert view.dirty_compared_to?(another)
  end

  def test_should_persist_style_correctly
    @project.tree_configurations.create!(:name => 'first tree')
    view = CardListView.find_or_construct(@project, :style => 'tree', :tree_name => 'first tree')
    view.name = 'tree view'
    view.save
    view = @project.card_list_views.find_by_name('tree view')
    assert_equal 'tree', view.style.to_s
  end

  def test_should_return_first_level_of_the_tree_if_tree_selected_and_style_is_hierarchy
    create_planning_tree_project do |project, tree|
      view = CardListView.find_or_construct(project, :style => 'hierarchy', :tree_name => 'Planning')
      assert_equal ['release1', 'iteration2', 'story5'].sort, view.cards.collect(&:name).sort
    end
  end

  def test_cards_method_works_with_hierarchy_when_selected_columns_include_a_capital_f
    create_planning_tree_project do |project, tree|
      type_story = project.card_types.find_by_name('story')
      property = setup_numeric_property_definition('Flabbergast', [1, 2, 3])
      type_story.add_property_definition(property)
      type_story.save!

      view = CardListView.find_or_construct(project, :style => 'hierarchy', :tree_name => 'Planning', :columns => 'Flabbergast')
      assert_sort_equal ['release1', 'iteration2', 'story5'], view.cards.collect(&:name)
    end
  end

  def test_should_all_cards_of_the_tree_if_tree_selected_and_style_is_grid
    create_planning_tree_project do |project, tree, config|
      view = CardListView.find_or_construct(project, :style => 'grid', :tree_name => 'Planning')
      assert_equal ['iteration1', 'iteration2', 'release1', 'story1', 'story2', 'story3', 'story4', 'story5'].sort, view.cards.collect(&:name).sort
    end
  end

  def test_should_first_page_cards_of_the_tree_if_tree_selected_and_style_is_list
    create_planning_tree_project do |project, tree, config|
      with_page_size(3) do
        view = CardListView.find_or_construct(project, :style => 'list', :tree_name => 'Planning')
        assert_equal ["story2", "story1", "story3"], view.cards.collect(&:name)
      end
    end
  end

  def test_viewable_styles
    create_planning_tree_project do |project, tree|
      view = CardListView.find_or_construct(project, :style => 'list', :tree_name => 'Planning')
      assert_equal ['list', 'hierarchy', 'grid', 'tree'], view.viewable_styles.collect(&:to_s)
      view = CardListView.find_or_construct(project, :style => 'list')
      assert_equal ['list', 'grid'], view.viewable_styles.collect(&:to_s)
    end
  end

  def test_should_be_ok_when_init_with_invalid_card_type_filter
    view = CardListView.find_or_construct(@project, :style => 'list', :filters => ["[Type][is][invalid]"])
    assert view.invalid?
    assert_equal [], view.cards
  end

  def test_should_be_invalid_when_init_with_invalid_tree_name
    view = CardListView.find_or_construct(@project, :style => 'list', :tree_name => 'invalid tree')
    assert_equal "There is no tree named #{'invalid tree'.bold}.", view.workspace.validation_errors.join
    assert view.invalid?
    assert_equal [], view.cards
  end

  def test_destroy_also_destroys_my_favorite
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'},
      :style => 'grid', :group_by => 'status', :lanes => '')
    favorite_id = view.favorite.id
    view.destroy
    assert_nil Favorite.find_by_id(favorite_id)
  end

  def test_should_delete_tabs_and_favorites_when_deleting_properties_related_to_mql_filter
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'close', 'fixed']

      view = project.card_list_views.create_or_update(:view => {:name => 'saved view'},
        :style => 'list', :filters => {:mql => 'type = card and (status = fixed or status= new ) and status != close '})
      project.find_property_definition('status').destroy
      assert_record_deleted view.favorite
    end
  end

  def test_should_delete_tabs_and_favorites_when_deleting_properties_value_related_to_mql_filter
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'close', 'fixed']

      view = project.card_list_views.create_or_update(:view => {:name => 'saved view'},
        :style => 'list', :filters => {:mql => 'type = card and status = new '})
      project.find_property_definition('status').find_enumeration_value('close').destroy

      assert_record_not_deleted(view.favorite)

      project.find_property_definition('status').find_enumeration_value('new').destroy
      assert_record_deleted(view.favorite)
    end
  end

  def test_aggregate_parameters_are_saved
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :style => 'grid', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'release'})
    assert_equal({:column => 'sum'}, view.to_params[:aggregate_type])
    assert_equal({:column => 'release'}, view.to_params[:aggregate_property])
  end

  def test_invalid_selection
    selected_card = @project.cards.find_by_name('first card')
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :style => 'list', :selected_cards => selected_card.id.to_s, :columns => 'name,status')
    assert !view.invalid_selection?

    selected_card.destroy
    assert view.invalid_selection?
  end

  # bug 3681
  def test_can_create_tree_view_with_tree_id_parameter_instead_of_tree_name
    some_tree = @project.tree_configurations.create!(:name => 'some tree')
    clv = @project.card_list_views.create_or_update(:view => {:name => 'hello'}, :tree_id => "#{some_tree.id}", :style => 'tree', :filters => ["[Type][is][Card]"])
    assert_equal 'some tree', clv.to_params[:tree_name]
  end

  def test_all_cards_tree_should_be_empty_tree_when_card_list_view_is_invalid
    with_filtering_tree_project do |project|
      current_status = create_plv(project, :name => 'current status', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'open')
      card_list_view = CardListView.construct_from_params(project, {:tf_story => ["[status][is][(current status)]"], :tree_name => tree_name = 'filtering tree'})
      configuration = project.tree_configurations.find_by_name('filtering tree')
      assert card_list_view.all_cards_tree.is_a?(CardTree::EmptyTree)
      assert !card_list_view.filters.validation_errors.empty?
    end
  end

  def test_all_cards_tree_can_be_order_by_columns
    with_three_level_tree_project do |project|
      view = CardListView.construct_from_params(project, :tree_name => 'three level tree')
      assert_equal ['iteration2', 'iteration1'], view.all_cards_tree.root.children.first.children.collect(&:name)

      view = CardListView.construct_from_params(project, :tree_name => 'three level tree', :sort => 'name')
      assert_equal ['iteration1', 'iteration2'], view.all_cards_tree.root.children.first.children.collect(&:name)

      view = CardListView.construct_from_params(project, :tree_name => 'three level tree', :sort => 'name', :order => 'DESC')
      assert_equal ['iteration2', 'iteration1'], view.all_cards_tree.root.children.first.children.collect(&:name)
    end
  end

  def test_should_round_trip_raw_mql_as_filter_conditions
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :filters => {:mql => 'status=open'})
    assert_equal({:tab => 'All', :action => 'list', :style => 'list', :filters => {:mql => 'status=open'}}, view.to_params)
  end

  def test_should_be_able_to_create_card_query_when_filters_are_expressed_as_mql
    first_card = @project.cards.find_by_number(1)
    first_card.update_attributes(:cp_status => 'open')

    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :filters => {:mql => 'status=open'})
    assert_equal 1, view.card_count
    assert_equal first_card.name, view.cards.first.name

    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'}, :filters => {:mql => 'status!=open'})
    assert_equal 1, view.card_count
    assert_equal @project.cards.find_by_number(4).name, view.cards.first.name
  end

  def test_filter_column_query_should_include_order_by_in_hierarchy_view
    create_planning_tree_project do |project, tree|
      view = CardListView.find_or_construct(project, :style => 'hierarchy', :tree_name => 'Planning', :sort => 'name', :order => 'DESC')
      assert_equal ['name', 'number'], view.filter_column_query.order_by.collect(&:column_name)
      assert_equal view.all_cards_tree.nodes_without_root.collect(&:name), view.all_cards.collect(&:name)
    end
  end

  def test_card_query_columns_should_skip_columns_that_do_not_exist
    create_planning_tree_project do |project, tree|
      view = CardListView.construct_from_params(project, { :style => 'hierarchy', :tree_name => 'Planning', :sort => 'name', :order => 'DESC', :columns => ['fake'] }, false)

      assert_nothing_raised CardQuery::Column::PropertyNotExistError do
        view.filter_column_query.order_by.collect(&:column_name)
      end
    end
  end

  def test_filter_with_empty_mql
    view = CardListView.find_or_construct(@project, {:filters => {:mql => ''}})
    assert_equal @project.cards.count, view.card_count
  end

  # bug #4539
  def test_should_update_filter_properties_when_kick_off_member_who_has_owership_of_cards
    @project.card_list_views.create_or_update(:view => {:name => 'removing view'}, :filters => ["[dev][is][bob]"])
    @project.remove_member(@project.users.find_by_login('bob'))

    view = @project.card_list_views.find_by_name('removing view')
    assert_equal ['[dev][is][]'], view.to_params[:filters]
  end

  def test_children_should_be_sorted_by_card_name_as_default_in_tree_view
    create_planning_tree_project do |project, tree|
      type_release = project.card_types.find_by_name('release')
      view = CardListView.find_or_construct(project, :style => :tree, :tree_name => tree.name)
      a1 = tree.configuration.add_child(project.cards.create!(:name => 'a1', :card_type => type_release))
      assert_equal ["a1", "iteration2", "release1", "story5"], view.all_cards_tree.root.children.collect(&:name)
    end
  end

  def test_can_not_select_all_cards_in_list_style_even_with_page_equal_all
    with_page_size(1) do
      view  = CardListView.find_or_construct(@project, {:page => 'All', :style => 'list'})
      assert_equal 1, view.cards.size
    end
  end

  def test_can_describe_current_page_for_list_with_paging
    with_page_size(1) do
      view  = CardListView.find_or_construct(@project, {:style => 'list', :page => 2})
      assert_equal "Listed below: 2 to 2 of 2.", view.describe_current_page
    end
  end

  def test_can_describe_current_page_for_hiearchy
    create_planning_tree_project do |project, tree|
      view = CardListView.find_or_construct(project, :style => 'hierarchy', :tree_name => 'Planning')
      assert_equal "8 cards in view.", view.describe_current_page
      view = CardListView.find_or_construct(project, :style => 'hierarchy', :tree_name => 'Planning', :excluded => ['iteration', 'story'])
      assert_equal "1 card in view.", view.describe_current_page
      view = CardListView.find_or_construct(project, :style => 'hierarchy', :tree_name => 'Planning', :excluded => ['iteration', 'release', 'story'])
      assert_equal "0 cards in view.", view.describe_current_page
    end
  end

  def test_can_describe_current_page_for_grid
    view  = CardListView.find_or_construct(@project, {:style => 'grid'})
    assert_equal "", view.describe_current_page
  end

  def test_can_describe_current_page_for_tree
    create_planning_tree_project do |project, tree|
      view  = CardListView.find_or_construct(@project, {:style => 'tree', :tree_name => 'Planning'})
      assert_equal "", view.describe_current_page
    end
  end

  def test_tree_hierarchy_and_grid_styles_are_not_paginated
    view  = CardListView.find_or_construct(@project, {:style => 'grid'})
    assert !view.paginated?
    create_planning_tree_project do |project, tree|
      view  = CardListView.find_or_construct(@project, {:style => 'tree', :tree_name => 'Planning'})
      assert !view.paginated?
      view  = CardListView.find_or_construct(@project, {:style => 'hierarchy', :tree_name => 'Planning'})
      assert !view.paginated?
    end
  end

  def test_current_page_is_page_number_when_list_is_paginated
    with_page_size(1) do
      view  = CardListView.find_or_construct(@project, {:style => 'list', :page => 2})
      assert_equal 2, view.current_page
    end
  end

  def test_all_cards_should_be_empty_if_invalid
    view  = CardListView.find_or_construct(@project, {:style => 'list', :filters => ["[Type][is][foo]"] })
    assert_equal [], view.all_cards
  end

  def test_should_return_true_if_given_tree_used_as_condition
   with_three_level_tree_project do |project|
     card_list_view = CardListView.construct_from_params(@project, {:style => 'list', :filters => {:mql => %{ FROM TREE 'three level tree'} }} )
     card_list_view.name="from tree view"
     card_list_view.save!
     assert card_list_view.uses_from_tree_as_condition?('three level tree')
     assert card_list_view.uses_from_tree_as_condition?('Three Level Tree')
     assert !card_list_view.uses_from_tree_as_condition?('another tree')
   end
  end

  def test_should_return_false_if_filter_does_not_use_tree_as_condition
   with_three_level_tree_project do |project|
     view = CardListView.construct_from_params(@project, {:style => 'list', :filters => {:mql => %{ type=story } }} )
     assert !view.uses_from_tree_as_condition?('three level tree')

     view  = CardListView.construct_from_params(@project, {:style => 'list', :filters => ["[Type][is][foo]"] })
     assert !view.uses_from_tree_as_condition?('three level tree')
   end
  end

  def test_can_tell_rank_mode
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :rank_is_on => true })
    assert(view.rank_is_on?)
    assert_nil(view.to_params[:rank_is_on])
  end

  def test_can_tell_rank_mode_with_string_boolean_paramter
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :rank_is_on => 'true' })
    assert(view.rank_is_on?)
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :rank_is_on => 'false' })
    assert(!view.rank_is_on?)
  end

  def test_rank_should_be_off_when_there_is_grid_sort_by
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :rank_is_on => 'true', :grid_sort_by => 'type' })
    assert(!view.rank_is_on?)
    assert(!view.to_params[:rank_is_on])
  end

  def test_rank_should_be_off_when_switch_to_other_style
    view  = CardListView.find_or_construct(@project, {:style => 'list', :rank_is_on => 'true'})
    assert(!view.rank_is_on?)
  end

  def test_canonical_string_not_include_rank_mode
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :rank_is_on => 'false'})
    assert_not_include 'rank_is_on=false', view.send(:build_canonical_string)
  end

  def test_rank_mode_should_not_goes_to_tab_params
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :rank_is_on => 'false'})
    assert_nil(view.to_tab_params[:rank_is_on])
  end

  def test_color_by_property_definition_on_grid
    view  = CardListView.find_or_construct(@project, {:style => 'grid', :color_by => 'status'})
    assert_equal @project.find_property_definition('status'), view.color_by_property_definition
  end

  def test_color_by_property_definition_on_tree_should_always_be_card_type
    tree_config = @project.tree_configurations.create(:name => 'lalatree')
    view  = CardListView.find_or_construct(@project, {:style => 'tree', :color_by => 'status', :tree_name => tree_config.name})
    assert_equal CardTypeDefinition::INSTANCE, view.color_by_property_definition
  end

  def test_can_create_a_personal_favorite_with_same_name_as_team_favorite
    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => nil)
    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => @member.id)
    assert_equal 2, @project.card_list_views.count
    assert_equal 1, @member.favorites.count
  end

  def test_can_create_a_view_with_invalid_user_filter
    view = @project.card_list_views.create_or_update(:view => { :name => "non existing user filter view" }, :filters => ['[dev][is][non existing user]'])
    assert_equal 1, @project.card_list_views.count
    assert view.invalid?
  end

  def test_can_create_a_view_with_invalid_user_mql
    view = @project.card_list_views.create_or_update(:view => { :name => "non existing user mql view" }, :filters => {:mql => 'dev is \'non existing user\''})

    assert_equal 1, @project.card_list_views.count
    #the invalidation is not done as there is no condition for existing user value
    # assert view.invalid?
  end

  def test_can_create_a_view_with_invalid_status_mql
    view = @project.card_list_views.create_or_update(:view => { :name => "non existing status view" }, :filters => {:mql => 'status is \'non existing status\''})
    assert_equal 1, @project.card_list_views.count
    assert view.invalid?
  end

  def test_can_create_a_personal_favorite_with_same_name_as_someone_elses_personal_favorite
    me = @project.users.first
    someone_else = create_user!
    @project.add_member(someone_else)

    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => me.id)
    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => someone_else.id)
    assert_equal 2, @project.card_list_views.count
    assert_equal 1, me.favorites.count
    assert_equal 1, someone_else.favorites.count
  end

  def test_cannot_create_a_personal_favorite_with_same_name_as_another_personal_favorite
    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => @member.id)
    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => @member.id)
    assert_equal 1, @project.card_list_views.count
    assert_equal 1, @member.favorites.count
  end

  def test_can_create_a_personal_favorite_with_same_definition_as_another_personal_favorite
    @project.card_list_views.create_or_update(:view => {:name => 'Same'}, :style => 'list', :user_id => @member.id)
    @project.card_list_views.create_or_update(:view => {:name => 'NotTheSame'}, :style => 'list', :user_id => @member.id)
    assert_equal 2, @project.card_list_views.count
    assert_equal 2, @member.favorites.count
  end

  def test_style_description
    assert_equal 'list', @project.card_list_views.create_or_update(:view => {:name => 'foo'}, :style => 'list').style_description
    assert_equal 'maximized list', @project.card_list_views.create_or_update(:view => {:name => 'bar'}, :style => 'list', :maximized => true).style_description
  end

  def test_canonical_string_should_be_same_for_a_simple_list_style_view
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1', :style => 'list'})
    assert_equal view.canonical_string, view.build_canonical_string
  end

  def test_show_lane_will_add_lane_to_lanes_param
    view = CardListView.find_or_construct(@project, { :style => 'grid', :group_by => { :lane => 'Status' }, :lanes => 'new,open' })
    view = view.show_dimension(:lane, 'closed')
    assert view.group_lanes.visibles(:lane).collect(&:title).include?('closed')
  end

  def test_ready_for_cta
    view = CardListView.find_or_construct(@project, {:style => 'grid', :group_by => 'status'})
    assert view.ready_for_cta?
  end

  def test_reload_lane_order_will_reorder_lanes_param
    view = CardListView.find_or_construct(@project, { :style => 'grid', :group_by => { :lane => 'Status' }, :lanes => 'new,open' })
    property_definition = view.group_lanes.lane_property_definition
    property_definition.reorder(['open', 'new']) {|enum| enum.value}

    view.reload_lane_order
    assert_equal ['open', 'new'], view.group_lanes.visibles(:lane).collect(&:title)
  end

  def test_too_many_results_should_raise_error_when_filter_is_invalid
    with_filtering_tree_project do |project|
      view = CardListView.find_or_construct(project,
        {:filters => ["[Type][is][iteration]", "[Planning release][is][(current wd)]"], :style => 'grid', :group_by => { :lane => 'status'} })
      assert_false view.too_many_results?
    end
  end

  def test_should_save_wip_limits
    valid_wip_limits = {'New' => {:type => 'Count', :limit => '30'}, 'Open' => {:type => 'Sum', :property => 'estimate', :limit => '30'}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'new,open', :wip_limits => valid_wip_limits)
    expected_canonical_string = 'group_by={lane=status},lanes=new,open,style=grid,wip_limits={New={limit=30,type=count},Open={limit=30,property=estimate,type=sum}}'
    assert_equal expected_canonical_string, view.canonical_string
  end

  def test_should_save_hide_wip_limits_option
    valid_wip_limits = {'New' => {:type => 'Count', :limit => '30'}, 'Open' => {:type => 'Sum', :property => 'estimate', :limit => '30'}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'new,open', :wip_limits => valid_wip_limits, :hide_wip_limits => 'false')
    expected_canonical_string = 'group_by={lane=status},hide_wip_limits=false,lanes=new,open,style=grid,wip_limits={New={limit=30,type=count},Open={limit=30,property=estimate,type=sum}}'
    assert_equal expected_canonical_string, view.canonical_string
    assert_false view.hide_wip_limits?
  end

  def test_should_save_wip_limits_if_not_number
    valid_wip_limits = {'New' => {:type => 'Count', :limit => '3a0'}, 'Open' => {:type => 'Sum', :property => 'estimate', :limit => '12'}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'new,open', :wip_limits => valid_wip_limits)
    expected_canonical_string = 'group_by={lane=status},lanes=new,open,style=grid,wip_limits={Open={limit=12,property=estimate,type=sum}}'
    assert_equal expected_canonical_string, view.canonical_string
  end

  def test_should_save_wip_limits_if_lane_is_invalid
    valid_wip_limits = {'News' => {:type => 'Count', :limit => '30'}, 'Open' => {:type => 'Sum', :property => 'estimate', :limit => '12'}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'open', :wip_limits => valid_wip_limits)
    expected_canonical_string = 'group_by={lane=status},lanes=open,style=grid,wip_limits={Open={limit=12,property=estimate,type=sum}}'
    assert_equal expected_canonical_string, view.canonical_string
  end

  def test_should_not_save_wip_limit_if_wip_type_is_sum_and_no_property_is_given
    invalid_wip_limits = {'New' => {:type => 'Count', :limit => 30}, 'Closed' => {:type => 'Sum', :limit => 30}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'new,open', :wip_limits => invalid_wip_limits)
    canonical_string = 'group_by={lane=status},lanes=new,open,style=grid,wip_limits={New={limit=30,type=count}}'
    assert_equal canonical_string, view.build_canonical_string
  end

  def test_should_not_save_wip_limit_for_invalid_columns
    wip_limits_with_invalid_column = {'To do' => {:type => 'Count', :limit => 30}, 'invalidColumn' => {:type => 'Sum', :property => 'estimate', :limit => 30}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'new,open', :wip_limits => wip_limits_with_invalid_column)
    canonical_string = 'group_by={lane=status},lanes=new,open,style=grid'
    assert_equal canonical_string, view.build_canonical_string
  end

  def test_should_not_save_wip_limit_for_invalid_column_name_and_when_group_by_missing
    wip_limits_with_invalid_column = {'To do' => {:type => 'Count', :limit => 30}, 'invalidColumn' => {:type => 'Sum', :property => 'estimate', :limit => 30}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:row => 'Status'}, :lanes => 'new,open', :wip_limits => wip_limits_with_invalid_column)
    canonical_string = 'group_by={row=status},style=grid'
    assert_equal canonical_string, view.reload.canonical_string

    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :lanes => 'new,open', :wip_limits => wip_limits_with_invalid_column)
    canonical_string = 'style=grid'
    assert_equal canonical_string, view.reload.canonical_string
  end

  def test_should_update_wip_limits_on_lane_rename
    old_name = 'Open'
    new_name = 'Wopen'
    valid_wip_limits = {'New' => {:type => 'Count', :limit => '30'}, old_name => {:type => 'Sum', :property => 'estimate', :limit => '30'}}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'Status'}, :lanes => 'new,open', :wip_limits => valid_wip_limits)

    wip_limit_value_for_old_name = valid_wip_limits[old_name]

    view.rename_property_value('Status', old_name, new_name)
    view = CardListView.reload(view)

    assert_nil(view.wip_limits[old_name])
    assert_equal(view.wip_limits[new_name], wip_limit_value_for_old_name)
  end

  def test_should_update_wip_limits_on_card_type_rename
    old_name = 'Card'
    new_name = 'CardType'
    limits = {:type => 'Count', :limit => '31'}
    wip_limits = {old_name => limits}
    view = @project.card_list_views.create_or_update(:view => {:name => 'view 1'}, :style => 'grid', :group_by => {:lane => 'type'}, :lanes => 'Card', :wip_limits => wip_limits)

    view.rename_card_type(old_name, new_name)
    view = CardListView.reload(view)

    assert_nil(view.wip_limits[old_name])
    assert_equal(view.wip_limits[new_name], limits)
  end

  def test_should_send_monitoring_event_only_when_wip_changes
    limits = {:type => 'Count', :limit => '31'}
    wip_limits = {'Card' => limits}

    helper = MetricsHelperStub.new
    @project.card_list_views.create_or_update({:view => {:name => 'view 2'}, :style => 'grid', :group_by => {:lane => 'type'}, :lanes => 'Card'}, helper)
    assert_false helper.called

    helper = MetricsHelperStub.new
    @project.card_list_views.create_or_update({:view => {:name => 'view 2'}, :style => 'grid', :group_by => {:lane => 'type'}, :lanes => 'Card', :wip_limits => wip_limits}, helper)
    assert helper.called

    helper = MetricsHelperStub.new
    @project.card_list_views.create_or_update({:view => {:name => 'view 2'}, :style => 'grid', :group_by => {:lane => 'type'}, :lanes => 'Card', :wip_limits => {'Card' => {:type => 'Count', :limit =>'2'}}}, helper)
    assert helper.called

    helper = MetricsHelperStub.new
    @project.card_list_views.create_or_update({:view => {:name => 'view 2'}, :group_by => {:lane => 'type'}, :style => 'grid', :lanes => 'Card'}, helper)
    assert helper.called

    helper = MetricsHelperStub.new
    @project.card_list_views.create_or_update({:view => {:name => 'view 2'}, :style => 'grid', :lanes => 'Card'}, helper)
    assert_false helper.called
  end

  def test_should_fix_encoding_for_params_with_special_chars_serialized_by_jvyaml
    with_new_project do |project|
      project.card_types.create(name: 'stôrÿ')
      clv = project.card_list_views.create_or_update({view: {name: 'view with special params'}, style: 'grid', group_by: {lane: 'type'}, lanes: 'stôrÿ,card'})

      params_dumped_by_jvyaml = JvYAML.dump(clv.params)
      # save stôrÿ as st\xC3\xB4r\xC3\xBF in the DB
      clv.update_attribute(:params, params_dumped_by_jvyaml)
      clv.reload

      expected_params = {style: 'grid',
                         group_by: {lane: 'type'},
                         lanes: 'stôrÿ,card',
                         aggregate_type: {column: nil},
                         aggregate_property: {column: nil}}
      assert_equal(expected_params, clv.params)

    end
  end

  private

  class MetricsHelperStub
    attr_accessor :called

    def initialize
      @called = false
    end

    def add_monitoring_event(event, props)
      @called = true
    end
  end

  def create_card_list_view(name,request_params)
    @project.card_list_views.create_or_update(request_params.merge(:view => {:name => name}))
  end

  def user_names(cards, column_name)
    cards.collect(&column_name).collect {|user_id| User.find(user_id).name }
  end
end
