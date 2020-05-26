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

class CardListViewGroupByRowTest < ActiveSupport::TestCase
  def setup
    login_as_member
  end

  #         \ status |(not set) (2)  | new (1)       |
  # priority \       |               |               |
  # --------------------------------------------------
  # (not set)        | first card    |               |
  #                  | another card  |               |
  # --------------------------------------------------
  #   high           |               | high priority |
  def test_group_by_lane_and_row
    with_new_project do |project|
      setup_property_definitions("status" => ["new", "open"], "priority" => ["low", "high"])
      create_card!(:name => "first card", :card_type_name => "card")
      create_card!(:name => "another card", :card_type_name => "card")
      create_card!(:name => "high priority", :priority => "high", :status => "new")

      view = CardListView.find_or_construct(project, :style => "grid", :group_by => {:lane => "status", :row => "priority"})
      view.name = "group lane by row property"
      view.save!
      view.reload

      rows = view.groups.visibles(:row)

      assert_equal 2, rows.length
      assert_equal 2, rows[0].cells.length
      assert_equal 2, rows[1].cells.length

      assert_equal "(not set)", rows[0].title
      assert_equal ["another card", "first card"], rows[0].cells[0].cards.collect(&:name).sort
      assert_equal [], rows[0].cells[1].cards

      assert_equal "high", rows[1].title
      assert_equal [], rows[1].cells[0].cards
      assert_equal ["high priority"], rows[1].cells[1].cards.collect(&:name)
    end
  end

  def test_group_rows_by_user_prop_with_not_set
    with_first_project do |project|
      create_card!(:name => 'high priority', :priority => 'high', :status => 'new', :dev => nil)
      card = create_card!(:name => 'high priority', :priority => 'high', :status => 'new', :dev => User.find_by_login('member').id)
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status', :row => 'dev'})
      view.name = 'group lane by row property'
      view.save!
      view.reload

      rows = view.groups.visibles(:row)
      assert_equal 2, rows.length
      assert_equal '(not set)', rows[0].title
    end
  end

  def test_group_rows_should_sort_card_type_by_position
    with_new_project do |project|
      project.card_types.each(&:destroy)
      card_type = project.card_types.create! :name => 'card'
      bug_type = project.card_types.create! :name => 'bug'
      ass_type = project.card_types.create! :name => 'assassin'

      ass_type.reload.update_attributes(:position => 100, :nature_reorder_disabled => true)

      assert_equal(100, ass_type.reload.position)

      create_card!(:name => 'card type card', :card_type => card_type)
      create_card!(:name => 'bug type card', :card_type => bug_type)
      create_card!(:name => 'assassin type card', :card_type => ass_type)

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'type', :row => 'type'})
      view.name = 'group lane by row property'
      view.save!
      view.reload

      rows = view.groups.visibles(:row)
      assert_equal ["bug", "card", "assassin"], rows.collect(&:title)
    end
  end

  def test_group_by_lane_and_row_cell_html_id
    with_first_project do |project|
      create_card!(:name => 'high priority', :priority => 'high', :status => 'new')
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status', :row => 'priority'})
      rows = view.groups.visibles(:row)

      assert_equal "#{lane_html_id('')}_#{row_html_id('')}", rows[0].cells[0].html_id
      assert_equal "#{lane_html_id('new')}_#{row_html_id('')}", rows[0].cells[1].html_id

      assert_equal "#{lane_html_id('')}_#{row_html_id('high')}", rows[1].cells[0].html_id
      assert_equal "#{lane_html_id('new')}_#{row_html_id('high')}", rows[1].cells[1].html_id
    end
  end

  def test_group_by_lane_only_cell_html_id
    with_first_project do |project|
      create_card!(:name => 'high priority', :priority => 'high', :status => 'new')
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status'})
      rows = view.groups.visibles(:row)

      assert_equal lane_html_id(''), rows[0].cells[0].html_id
      assert_equal lane_html_id('new'), rows[0].cells[1].html_id
    end
  end

  def test_group_by_row_only_cell_html_id
    with_first_project do |project|
      create_card!(:name => 'high priority', :priority => 'high', :status => 'new')
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'status'})
      rows = view.groups.visibles(:row)

      assert_equal "ungrouped_#{row_html_id('')}", rows[0].cells[0].html_id
      assert_equal "ungrouped_#{row_html_id('new')}", rows[1].cells[0].html_id
    end
  end

  def test_no_group_by_cell_html_id
    with_first_project do |project|
      create_card!(:name => 'high priority', :priority => 'high', :status => 'new')
      view = CardListView.find_or_construct(project, :style => 'grid')
      rows = view.groups.visibles(:row)

      assert_equal 'ungrouped', rows[0].cells[0].html_id
    end
  end

  def test_group_rows_when_view_is_only_grouped_by_lane
    with_new_project do |project|
      setup_property_definitions("status" => ["new", "open"], "priority" => ["low", "high"])
      create_card!(:name => "first card", :card_type_name => "card")
      create_card!(:name => "another card", :card_type_name => "card")
      create_card!(:name => "high priority", :priority => "high", :status => "new")

      view = CardListView.find_or_construct(project, :style => "grid", :group_by => {:lane => "status"})
      view.name = "group lane by row property"
      view.save!
      view.reload

      rows = view.groups.visibles(:row)

      assert_equal 1, rows.length
      assert_equal 2, rows[0].cells.length

      assert_equal nil, rows[0].title
      assert_equal ["another card", "first card"], rows[0].cells[0].cards.collect(&:name).sort
      assert_equal ["high priority"], rows[0].cells[1].cards.collect(&:name)
    end
  end

  def test_group_by_row_params
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status', :row => 'priority'})
      assert_equal({:row => "priority", :lane => "status"}, view.to_params[:group_by])

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'priority'})
      assert_equal({:row => 'priority'}, view.to_params[:group_by])

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status'})
      assert_equal({:lane => 'status'}, view.to_params[:group_by])

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => nil)
      assert_equal nil, view.to_params[:group_by]
    end
  end


  ##################################################################
  #                       Planning tree
  #                            |
  #                    ----- release1----
  #                   |                 |
  #            ---iteration1----    iteration2
  #           |                |
  #       story1            story2
  #
  ##################################################################
  #         \ release | (not set)     |release1 (2)  |
  # iteration \       |               |              |
  # --------------------------------------------------
  # (not set)        | story0         |
  # --------------------------------------------------
  # iteration1       |                |story1        |
  #                  |                |story2        |
  # --------------------------------------------------
  def test_group_by_lane_and_row_that_is_a_tree_relationship_property
    with_three_level_tree_project do |project|
      create_card!(:name => 'story0', :card_type_name => 'story')
      view = CardListView.find_or_construct(project, :filters => ['[type][is][story]'], :style => 'grid', :group_by => {:lane => 'Planning release', :row => 'Planning iteration'})
      view.name = 'group lane by row property'
      view.save!
      view.reload

      rows = view.groups.visibles(:row)

      assert_equal 2, rows.length
      assert_equal 2, rows[0].cells.length
      assert_equal 2, rows[1].cells.length

      assert_equal '(not set)', rows[0].title
      assert_equal 'iteration1', rows[1].title

      assert_equal ['story0'], rows[0].cells[0].cards.collect(&:name).sort
      assert_equal [], rows[0].cells[1].cards
      assert_equal [], rows[1].cells[0].cards
      assert_equal ['story1', 'story2'], rows[1].cells[1].cards.collect(&:name).sort
    end
  end

  def test_valid_group_by_property_when_group_by_row
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid')
      assert view.valid_group_by_properties?({:lane => 'status', :row => 'priority'})
      assert view.valid_group_by_properties?({:row => 'priority'})
      assert view.valid_group_by_properties?({:lane => 'status'})
      assert view.valid_group_by_properties?(nil)
      assert view.valid_group_by_properties?({})
      assert !view.valid_group_by_properties?({:lane => 'status', :row => 'something'})
    end
  end

  def test_group_by_param_property_names
    assert_equal ['status', 'priority'], CardView::GroupByParam.new({:lane => 'status', :row => 'priority'}).property_names
    assert_equal [nil, 'priority'], CardView::GroupByParam.new({:row => 'priority'}).property_names
    assert_equal [], CardView::GroupByParam.new({:lane => '', :row => ''}).property_names
    assert_equal [nil, 'status'], CardView::GroupByParam.new({:lane => '', :row => 'status'}).property_names
    assert_equal ['status', nil], CardView::GroupByParam.new({:lane => 'status', :row => ''}).property_names
    assert_equal ['status', nil], CardView::GroupByParam.new({:lane => 'status'}).property_names
    assert_equal [], CardView::GroupByParam.new(nil).property_names
    assert_equal [], CardView::GroupByParam.new({}).property_names
    assert_equal ['status', 'something_else'], CardView::GroupByParam.new({:lane => 'status', :row => 'something_else'}).property_names
  end

  def test_group_by_param_should_handle_a_string_initialize_param_as_lane_property
    group_by = CardView::GroupByParam.new('status')
    assert_equal({:lane => 'status'}, group_by.param_value)
    assert_equal(['status', nil], group_by.property_names)
  end

  def test_save_group_by_row_param
    with_new_project do |project|
      status = setup_managed_text_definition 'status', ['new', 'open']
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'status'})
      view.name = 'group by row status'
      view.save!

      view = project.card_list_views.find_by_name('group by row status')
      assert_equal({:row => 'status'}, view.to_params[:group_by])
    end
  end

  def test_rename_property_name_should_update_card_list_view_group_by_row_property_name
    with_new_project do |project|
      status = setup_managed_text_definition 'status', ['new', 'open']
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'status'})
      view.name = 'group by row status'
      view.save!

      status.update_attribute(:name, 'new_status')
      project.reload

      view = project.card_list_views.find_by_name('group by row status')
      assert_equal({:row => 'new_status'}, view.to_params[:group_by])
    end
  end

  def test_rename_group_by_lane_property_name_when_the_view_is_group_by_lane_and_row
    with_new_project do |project|
      status = setup_managed_text_definition 'status', ['new', 'open']
      priority = setup_managed_text_definition 'priority', ['high', 'low']
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'priority', :row => 'status'})
      view.name = 'group by priority;status'
      view.save!

      priority.update_attribute(:name, 'new_priority')
      project.reload

      view = project.card_list_views.find_by_name('group by priority;status')
      assert_equal({:lane => 'new_priority', :row => 'status'}, view.to_params[:group_by])
    end
  end

  def test_uses_property
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status', :row => 'priority'})
      assert view.uses?(project.find_property_definition('status'))
      assert view.uses?(project.find_property_definition('priority'))
      assert !view.uses?(project.find_property_definition('iteration'))
    end
  end

  def test_uses_property_in_grid_sort_by
    with_first_project do |project|
      view = CardListView.find_or_construct(project, style: 'grid', group_by:  {row: 'priority'}, grid_sort_by: 'status')
      assert view.uses?(project.find_property_definition('priority'))
      assert !view.uses?(project.find_property_definition('iteration'))
      assert view.uses?(project.find_property_definition('status'))
    end
  end

  def test_uses_card_type
    with_first_project do |project|
      card_type = project.card_types.find_by_name('Card')
      story_type = project.card_types.create!(:name => 'story')
      status = project.find_property_definition('status')
      status.card_types = [card_type, story_type]
      status.save!

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status', :row => 'type'})
      assert_equal({:lane => 'status', :row => 'type'}, view.to_params[:group_by])
      assert !view.uses_card_type?(story_type)
      assert view.uses_card_type?(card_type)
    end
  end

  def test_uses_card_type_when_no_group_by_lane
    with_first_project do |project|
      card_type = project.card_types.find_by_name('Card')
      story_type = project.card_types.create!(:name => 'story')

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'type'})
      assert_equal({:row => 'type'}, view.to_params[:group_by])
      assert !view.uses_card_type?(story_type)
      assert view.uses_card_type?(card_type)
    end
  end

  def test_uses_property_value
    with_first_project do |project|
      status = project.find_property_definition('status')
      create_card!(:name => 'high priority', :status => 'new')

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'priority', :row => 'status'})
      assert !view.uses_property_value?('status', 'open')
      assert view.uses_property_value?('status', 'new')
    end
  end

  def test_uses_property_value_when_no_group_by_lane
    with_first_project do |project|
      status = project.find_property_definition('status')
      create_card!(:name => 'high priority', :status => 'new')

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'status'})
      assert !view.uses_property_value?('status', 'open')
      assert view.uses_property_value?('status', 'new')
    end
  end

  def test_row_property_values_order
    with_first_project do |project|
      create_card!(:name => 'high priority', :priority => 'high')
      create_card!(:name => 'low priority', :priority => 'low')
      create_card!(:name => 'medium priority', :priority => 'medium')
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'priority'})

      rows = view.groups.visibles(:row)
      assert_equal ['(not set)', 'low', 'medium', 'high'], rows.collect(&:title)
    end
  end

  ##################################################################
  #                       Planning tree
  #                            |
  #                    ----- release1---- ----------------------release2--------------
  #                   |                 |                 |                           |
  #            ---iteration1----    iteration2          iteration3                  iteration10
  #           |                |                           |                          |
  #       story1            story2                       story4                     story3
  #
  ##################################################################
  #         \ release | release1 (2)  | release2 (2)
  # iteration \       |               |
  # -------------------------------------------------
  # iteration1       | story1        |
  #                  | story2        |
  # ----------------------------------------------------
  # iteration3       |               | story4        |
  # -----------------------------------------------------
  # iteration10      |               | story3        |
  # ---------------------------------------------------
  def test_group_row_by_a_tree_property_order
    with_three_level_tree_project do |project|
      configuration = project.tree_configurations.find_by_name('three level tree')

      release2 = create_card!(:name => 'release2', :card_type_name => 'Release')
      iteration10 = create_card!(:name => 'iteration10', :card_type_name => 'Iteration')
      iteration3 = create_card!(:name => 'iteration3', :card_type_name => 'Iteration')
      story4 = create_card!(:name => 'story4', :card_type_name => 'Story')
      story3 = create_card!(:name => 'story3', :card_type_name => 'Story')

      configuration.add_child(release2)
      configuration.add_child(iteration10, :to => release2)
      configuration.add_child(iteration3, :to => release2)
      configuration.add_child(story4, :to => iteration3)
      configuration.add_child(story3, :to => iteration10)

      view = CardListView.find_or_construct(project, :filters => ['[type][is][story]'], :style => 'grid', :group_by => {:lane => 'Planning release', :row => 'Planning iteration'})

      rows = view.groups.visibles(:row)
      assert_equal 3, rows.length
      assert_equal 'iteration1', rows[0].title
      assert_equal 'iteration3', rows[1].title
      assert_equal 'iteration10', rows[2].title
    end
  end

  class CustomizedHashClass < Hash
  end

  def test_should_dump_params_as_ruby_default_hash_obj
    with_first_project do |project|
      group_by = CustomizedHashClass.new
      group_by[:lane] = 'status'
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => group_by)
      view.name = 'group lane by row property'
      assert_equal Hash, view.to_params[:group_by].class
    end
  end

  def test_build_canonical_string_for_group_by_row_view
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status', :row => 'dev'})
      assert_equal 'group_by={lane=status,row=dev},style=grid', view.build_canonical_string

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:row => 'dev'})
      assert_equal 'group_by={row=dev},style=grid', view.build_canonical_string

      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => {:lane => 'status'})
      assert_equal 'group_by={lane=status},style=grid', view.build_canonical_string
    end
  end

  private
  def lane_html_id(lane_value)
    "lane_#{Digest::MD5::new.update(lane_value)}"
  end

  def row_html_id(row_value)
    "row_#{Digest::MD5::new.update(row_value)}"
  end

end
