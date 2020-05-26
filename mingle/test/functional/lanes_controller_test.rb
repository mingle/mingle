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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class LanesControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller LanesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_admin
    @project = first_project
    @project.activate
  end

  def test_create_lane_will_add_enumeration_value
    status_prop = @project.find_property_definition 'Status'
    post(:create, :project_id => @project.identifier,
         :lane => {:value => 'foo', :property_definition_id => status_prop.id },
         :group_by => { :lane => 'Status' },
         :format => 'js')
    assert_response :ok
    assert status_prop.values.collect(&:name).include? 'foo'
  end

  def test_create_lane_with_empty_string_will_show_not_set
    status_prop = @project.find_property_definition 'Status'
    post(:create, :project_id => @project.identifier,
         :lane => {:value => '', :property_definition_id => status_prop.id },
         :group_by => { :lane => 'status' },
         :lanes => 'new,open',
         :format => 'js')
    assert_response :ok
    assert_equal ['(not set)', 'new', 'open'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
  end

  def test_created_lane_status_will_be_in_last_position
    with_new_project do |project|
      status_prop = setup_managed_text_definition 'nature', ['B', 'C', 'D']

      post(:create, :project_id => project.identifier,
           :lane => {:value => 'A', :property_definition_id => status_prop.id },
           :style => 'grid',
           :lanes => 'B,C,D',
           :group_by => { :lane => 'nature' },
           :format => 'js')
      assert_response :ok
      assert_equal ['B','C','D', 'A'], status_prop.reload.values.map(&:name)
    end
  end

  def test_created_lane_will_be_visible
    status_prop = @project.find_property_definition 'Status'
    post(:create, :project_id => @project.identifier,
         :lane => {:value => 'reopen', :property_definition_id => status_prop.id },
         :style => 'grid',
         :lanes => 'new,open,closed',
         :group_by => { :lane => 'status' },
         :format => 'js')
    assert_response :ok
    assert_equal ["new", 'open', 'closed', 'reopen'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
  end

  def test_created_lane_will_be_visible_with_grouping_actions
    status_prop = @project.find_property_definition 'Status'
    first_status_prop = status_prop.values.first

    post(:create, :project_id => @project.identifier,
         :lane => {:value => 'reopen', :property_definition_id => status_prop.id },
         :style => 'grid',
         :lanes => 'new,open,closed',
         :group_by => { :lane => 'status' },
         :color_by => "status",
         :filters => ["[Status][is][closed]"],
         :format => 'js')
    assert_response :ok

    assert_select 'form#new_filter[action=?]', "/projects/#{@project.identifier}/cards/list"
    assert_select "form#color_legend_form_#{first_status_prop.id}[action=?]", "/projects/#{@project.identifier}/cards/update_property_color/#{first_status_prop.id}?color_provider_type=EnumerationValue"
 end

  def test_create_with_invalid_value_will_respond_with_error
    status_prop = @project.find_property_definition 'Status'
    post(:create, :project_id => @project.identifier,
         :lane => {:value => 'a' * 256, :property_definition_id => status_prop.id },
         :style => 'grid',
         :lanes => 'new,open',
         :group_by => { :lane => 'status' },
         :format => 'js')
    assert_response 422
    assert flash.now[:error] =~ /Value is too long/
  end

  def test_create_lane_with_user_property
    user_property = @project.find_property_definition 'dev'

    bob = User.find_by_login "bob"
    member = User.find_by_login "member"
    post(:create, :project_id => @project.identifier,
         :lane => {:value => bob.login.to_s, :property_definition_id => user_property.id },
         :style => 'grid',
         :lanes => member.login,
         :group_by => { :lane => 'dev' },
         :format => 'js')
    assert_response :ok
    assert_equal [bob.name, member.name], assigns['view'].group_lanes.visibles(:lane).map(&:title)
  end

  def test_create_lane_with_tree_relationship_property
    with_three_level_tree_project do |project|
      iteration_property = project.find_property_definition('Planning iteration')

      iteration1_card = project.cards.find_by_name('iteration1')
      iteration2_card = project.cards.find_by_name('iteration2')
      post(:create, :project_id => project.identifier,
           :lane => {:value => iteration1_card.number, :property_definition_id => iteration_property.id },
           :style => 'grid',
           :lanes => iteration2_card.number,
           :filters => "[Type][is][Story]",
           :group_by => { :lane => 'Planning iteration' },
           :format => 'js')
      assert_response :ok
      assert_equal ["release1 > iteration1", "release1 > iteration2"], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    end
  end

  def test_create_lane_with_card_type_property
    with_data_series_chart_project do |project|
      card_type_property = project.find_property_definition('Type')
      card = CardType.find_by_name "Card"
      story = CardType.find_by_name "story"
      iteration = CardType.find_by_name "iteration"
      post(:create, :project_id => project.identifier,
           :lane => {:value => card.name, :property_definition_id => card_type_property.id },
           :style => 'grid',
           :lanes => 'iteration,story',
           :group_by => { :lane => 'Type' },
           :format => 'js')
      assert_response :ok
      assert_equal [card.name, iteration.name, story.name], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    end
  end

  def test_create_lane_with_tree_property_treats_blank_as_not_set
    with_three_level_tree_project do |project|
      iteration_property = project.find_property_definition('Planning iteration')

      post(:create, :project_id => project.identifier,
           :lane => {:value => "", :property_definition_id => iteration_property.id },
           :style => 'grid',
           :lanes => '',
           :filters => "[Type][is][Story]",
           :group_by => { :lane => 'Planning iteration' },
           :format => 'js')
      assert_response :ok
      assert_equal ["(not set)"], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    end
  end

  def test_create_lane_with_user_property_treats_blank_as_not_set
    user_property = @project.find_property_definition 'dev'

    post(:create, :project_id => @project.identifier,
         :lane => {:value => "", :property_definition_id => user_property.id },
         :style => 'grid',
         :lanes => '',
         :group_by => { :lane => 'dev' },
         :format => 'js')
    assert_response :ok
    assert_equal ['(not set)'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
  end

  def test_rename_lane_should_rename_enumeration_value
    post(:update, :project_id => @project.identifier,
         :style => 'grid',
         :group_by => { :lane => 'status' },
         :format => 'js',
         :lane_to_rename => 'new',
         :new_lane_name => 'backlog')

    assert_response :ok
    values = @project.find_property_definition("status").values.map(&:name)
    assert values.include?("backlog")
    assert !values.include?('new')
  end

  def test_rename_lane_should_rename_card_type
    with_new_project do |project|
      post(:update, :project_id => project.identifier,
           :style => 'grid',
           :group_by => { :lane => 'Type' },
           :format => 'js',
           :lane_to_rename => 'Card',
           :new_lane_name => 'Greeting')

      assert_response :ok
      values = project.reload.card_types.map(&:name)
      assert values.include?("Greeting")
      assert !values.include?('Card')
    end
  end

  def test_rename_nonexistent_card_type_lane_should_show_error
    with_new_project do |project|
      post(:update, :project_id => project.identifier,
           :style => 'grid',
           :group_by => { :lane => 'Type' },
           :format => 'js',
           :lane_to_rename => 'XYZ',
           :new_lane_name => 'Greeting')

      assert_response 422
      assert flash.now[:error] =~ /rename/
    end
  end

  def test_rename_lane_should_return_422_if_failed
    post(:update, :project_id => @project.identifier,
         :style => 'grid',
         :group_by => { :lane => 'status' },
         :format => 'js',
         :lane_to_rename => 'new',
         :new_lane_name => '')

    assert_response 422
    values = @project.find_property_definition("status").values.map(&:name)
    assert !values.include?("backlog")
    assert values.include?('new')
  end

  def test_rename_lane_with_same_name_doing_nothing
    post(:update, :project_id => @project.identifier,
         :style => 'grid',
         :group_by => { :lane => 'status' },
         :format => 'js',
         :lane_to_rename => 'new',
         :new_lane_name => 'new')

    assert_response :ok
  end

  def test_rename_lane_should_rename_lanes_in_current_view
    post(:update, :project_id => @project.identifier,
         :style => 'grid',
         :group_by => { :lane => 'status' },
         :format => 'js',
         :lanes => 'new,open',
         :lane_to_rename => 'new',
         :new_lane_name => 'fresh')

    assert_response :ok
    assert_equal ['fresh', 'open'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
  end

  def test_rename_lane_should_not_make_tab_dirty
    view = create_tabbed_view('story wall', @project,
                              :style => 'grid',
                              :group_by => { :lane => 'status' },
                              :format => 'js',
                              :lanes => 'new,open',
                              :tab => 'story wall'
                              )
    post(:update, view.to_params.merge(:project_id => @project.identifier,
                                            :lane_to_rename => 'new',
                                            :new_lane_name => 'fresh'))

    assert_response :ok
    assert_equal ['fresh', 'open'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    assert_false @controller.display_tabs.find_by_identifier(view.favorite.id).dirty?
  end


  def test_reorder_lanes_should_reorder_property_values
    with_new_project do |project|
      status = setup_property_definitions(:status => ['New', 'In progress', 'Testing', 'Done']).first
      view = create_tabbed_view('story wall', project,
                                :style => 'grid',
                                :group_by => { :lane => 'status' },
                                :format => 'js',
                                :lanes => 'New,In progress,Done',
                                :tab => 'story wall'
                                )
      assert_equal ['New', 'In progress', 'Testing', 'Done'], status.reload.enumeration_values.map(&:value)
      post(:reorder, view.to_params.merge(:project_id => project.identifier,
                                                :property_definition_id => status.id,
                                                :new_order => {
                                                  'New' => 0,
                                                  'Done' => 1,
                                                  'In progress' => 2}))

      assert_response :ok

      project.reload
      assert_equal [1, 2, 3, 4], status.reload.enumeration_values.map(&:position)
      assert_equal ['New', 'Testing', 'Done', 'In progress'], status.reload.enumeration_values.map(&:value)
      assert_equal ['New', 'Done', 'In progress'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    end
  end

  def test_reorder_lanes_with_card_type_property
    with_three_level_tree_project do |project|
      view = create_tabbed_view('story wall', project,
                                :style => 'grid',
                                :group_by => { :lane => 'Type' },
                                :format => 'js',
                                :lanes => 'Card,iteration,release,story',
                                :tab => 'story wall'
                                )
      assert_equal ['Card', 'iteration', 'release', 'story'], project.card_types.map(&:name)
      assert_equal ['Card', 'iteration', 'release', 'story'], view.group_lanes.visibles(:lane).map(&:identifier)
      post(:reorder, view.to_params.merge(:project_id => project.identifier,
                                                 :property_definition_id => "",
                                                 :new_order => {
                                                   'Card' => 0,
                                                   'release' => 1,
                                                   'iteration' => 2,
                                                   'story' => 3}))

      assert_response :ok
      project.reload
      assert_equal ['Card', 'release', 'iteration', 'story'], project.card_types.map(&:name)
    end
  end

  def test_reorder_lanes_with_card_type_property_with_invalid_value
    with_three_level_tree_project do |project|
      view = create_tabbed_view('story wall', project,
                                :style => 'grid',
                                :group_by => { :lane => 'Type' },
                                :format => 'js',
                                :lanes => 'Card,iteration,release,story',
                                :tab => 'story wall'
                                )
        post(:reorder, view.to_params.merge(:project_id => project.identifier,
                                                 :property_definition_id => "",
                                                 :new_order => {
                                                   'Card' => 0,
                                                   'release' => 1,
                                                   'invalid' => 2,
                                                   'story' => 3}))

      assert_response :ok
      assert_select "div#flash", :text => /.*column to reorder 'invalid' is invalid*/
    end
  end

  def test_reorder_lanes_should_validate_values
    with_new_project do |project|
      status = setup_property_definitions(:status => ['New', 'In progress', 'Testing', 'Done']).first
      assert_equal ['New', 'In progress', 'Testing', 'Done'], status.reload.enumeration_values.map(&:value)

      view = create_tabbed_view('story wall', project,
                                :style => 'grid',
                                :group_by => { :lane => 'status' },
                                :format => 'js',
                                :lanes => 'New,Done',
                                :tab => 'story wall'
                                )
      post(:reorder, view.to_params.merge(:project_id => project.identifier,
                                                :property_definition_id => status.id,
                                                :new_order => {
                                                  'New' => 0,
                                                  'Done' => 1,
                                                  'In progress' => 2,
                                                  'invalid' => 3
                                                }))
      assert_response :ok
      assert_select "div#flash", :text => /.*column to reorder 'invalid' is invalid*/

      project.reload
      assert_equal [1, 2, 3, 4], status.reload.enumeration_values.map(&:position)
      assert_equal ['New', 'In progress', 'Testing', 'Done'], status.reload.enumeration_values.map(&:value)
    end
  end

  def test_destroy_lane_will_make_the_selected_lane_not_visible
    status_prop = @project.find_property_definition 'Status'
    view = create_tabbed_view('story wall', @project,
                              :style => 'grid',
                              :group_by => { :lane => 'status' },
                              :format => 'js',
                              :lanes => 'new,open,closed',
                              :tab => 'story wall'
                              )
    post(:destroy, view.to_params.merge( :project_id => @project.identifier,
                                           :lane => {
                                             :value => 'open',
                                             :property_definition_id => status_prop.id
                                           }
                                         ))
    assert_response :ok
    assert_equal ["new", 'closed'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    assert @controller.display_tabs.find_by_identifier(view.favorite.id).dirty?
  end

  def test_destroy_lane_should_render_errors_for_hiding_non_existent_lanes
    status_prop = @project.find_property_definition 'Status'
    post(:destroy, :project_id => @project.identifier,
         :lane => {:value => 'non_existent', :property_definition_id => status_prop.id },
         :style => 'grid',
         :lanes => 'new,open,closed',
         :group_by => { :lane => 'status' },
         :format => 'js')
    assert_response :unprocessable_entity
  end

  def test_destroy_should_destroy_specified_user_property
    user_property = @project.find_property_definition 'dev'
    bob = User.find_by_login "bob"
    member = User.find_by_login "member"

    view = create_tabbed_view('story wall', @project,
                              :style => 'grid',
                              :group_by => { :lane => 'dev' },
                              :format => 'js',
                              :lanes => "#{member.login},#{bob.login}",
                              :tab => 'story wall'
                              )

    post(:destroy, view.to_params.merge(:project_id => @project.identifier,
                                        :lane => {:value => bob.login.to_s, :property_definition_id => user_property.id }))

    assert_response :ok
    assert_equal ['member@email.com'], assigns['view'].group_lanes.visibles(:lane).map(&:title)
  end

  def test_destroy_should_destroy_specified_tree_property
    with_three_level_tree_project do |project|
      iteration_property = project.find_property_definition('Planning iteration')
      iteration1_card = project.cards.find_by_name('iteration1')
      iteration2_card = project.cards.find_by_name('iteration2')
      post(:destroy, :project_id => project.identifier,
           :lane => {:value => iteration1_card.number, :property_definition_id => iteration_property.id },
           :style => 'gid',
           :lanes => "#{iteration1_card.number},#{iteration2_card.number}",
           :filters => "[Type][is][Story]",
           :group_by => { :lane => 'Planning iteration' },
           :format => 'js')
      assert_response :ok
      assert_equal ["release1 > iteration2"], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    end
  end

  def test_destroy_should_destroy_specified_card_type_lane
    with_data_series_chart_project do |project|
      card_type_property = project.find_property_definition('Type')
      card = CardType.find_by_name "Card"
      story = CardType.find_by_name "story"
      iteration = CardType.find_by_name "iteration"
      post(:destroy, :project_id => project.identifier,
           :lane => {:value => card.name, :property_definition_id => card_type_property.id },
           :style => 'grid',
           :lanes => 'card,iteration,story',
           :group_by => { :lane => 'Type' },
           :format => 'js')
      assert_response :ok
      assert_equal [iteration.name, story.name], assigns['view'].group_lanes.visibles(:lane).map(&:title)
    end
  end

end
