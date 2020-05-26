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

class GroupLanesTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_member
    @admin = User.find_by_login('admin')
    @project = create_project :prefix => 'gl_test', :users => [User.find_by_login('member'), @admin]
    setup_property_definitions :status => ['new', 'open', 'closed', 'single \'quote\'', 'double "quote"'], :old_type => ['bug,story', 'card']
    setup_user_definition 'developer'
    @size = setup_numeric_property_definition('size', [1, 2, 3])
    @status = @project.find_property_definition(:status)
    @developer = @project.find_property_definition_or_nil('developer')
    @view = CardListView.find_or_construct(@project, :style => 'grid')
  end

  def test_should_be_able_to_parse_lane_name_with_quotes
    lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'open,new,single \'quote\',double "quote"'})
    assert_equal 'status IN (open, new, \'single \'quote\'\', \'double "quote"\')', lanes.lane_restriction_query.to_s
  end

  def test_with_no_cards_when_no_lanes_explicitly_specified_not_set_is_visible
    lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => ''})
    assert_equal [PropertyValue::NOT_SET_LANE_IDENTIFIER], lanes.visibles(:lane).map(&:identifier)
  end

  def test_with_no_cards_when_no_lanes_implicitly_specified_not_set_is_visible
    lanes = CardView::GroupLanes.new(@view, {:group_by => 'status'})
    assert_equal [PropertyValue::NOT_SET_LANE_IDENTIFIER], lanes.visibles(:lane).map(&:identifier)
  end

  def test_with_filtered_out_cards_when_no_lanes_explicitly_specified_not_set_is_visible
    create_card! :name => 'filtered away', :status => 'new'
    view = CardListView.find_or_construct(@project, :style => 'grid', :filters => ["[status][is][(not set)]"])
    lanes = CardView::GroupLanes.new(view, {:group_by => 'status'})
    assert_equal [PropertyValue::NOT_SET_LANE_IDENTIFIER], lanes.visibles(:lane).map(&:identifier)
  end

  def test_can_hide_on_sole_visible_lane_should_be_false
    lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => "new"})
    assert_false lanes.lane('new').can_hide?
  end

  def test_after_rename_property_group_by_should_change
    lanes = CardView::GroupLanes.new(@view, {:group_by => 'status'})
    lanes.rename_property('STatus', 'new_name_for_status')
    assert_equal({:lane => 'new_name_for_status'}, lanes.to_params[:group_by])
  end

  def test_after_rename_property_aggregate_value_should_change
    lanes = CardView::GroupLanes.new(@view, {:aggregate_type => {:column => 'avg'}, :aggregate_property => {:column => 'size'}})
    lanes.rename_property('SIze', 'new_name_for_size')
    assert_equal({:column => 'new_name_for_size'}, lanes.to_params[:aggregate_property])
  end

  def test_rename_property_should_also_rename_row_aggregate_property
    lanes = CardView::GroupLanes.new(@view, {:aggregate_type => {:column => 'avg'}, :aggregate_property => {:row => 'size'}})
    lanes.rename_property('SIze', 'new_name_for_size')
    assert_equal({:row => 'new_name_for_size'}, lanes.to_params[:aggregate_property])
  end

  def test_all_lanes_should_include_all_the_properties
    lanes = CardView::GroupLanes.new(@view, {:group_by => 'status'})
    assert_equal [PropertyValue::NOT_SET,'new',  'open', 'closed', 'single \'quote\'', 'double "quote"'], lanes.lanes.collect(&:title)
  end

  def test_show_lane_return_new_view_with_lane_visible
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status'})
    assert_equal ' ,new', group_lanes.show_dimension_params(:lane, 'new')[:lanes]


    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'new,open'})
    assert_equal 'new,open,closed', group_lanes.show_dimension_params(:lane, 'closed')[:lanes]
    assert_equal 'new,open', group_lanes.show_dimension_params(:lane, 'new')[:lanes]
  end

  def test_show_lane_when_there_is_visible_lanes_but_no_lane_params_specified
    create_card!(:name => "open card", :status => 'open')
    create_card!(:name => "not set card")
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status'})
    assert_equal "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,closed", group_lanes.show_dimension_params(:lane, 'closed')[:lanes]
  end

  def test_should_only_show_lanes_specified_if_there_is_lane_param
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :color_by => 'developer', :lanes => "new,open,#{PropertyValue::NOT_SET_LANE_IDENTIFIER}"})
    assert_equal [PropertyValue::NOT_SET, 'new','open'], group_lanes.visibles(:lane).collect(&:title)
  end

  def test_should_only_show_lanes_with_cards_in_view_if_no_lanes_specified
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :color_by => 'developer')
    @view.name = 'test'
    @view.save!
    assert_equal ['(not set)'], @view.group_lanes.visibles(:lane).collect(&:title)

    create_card!(:name => "open card", :status => 'open')
    create_card!(:name => "close card", :status => 'closed')
    create_card!(:name => 'not set card')
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :color_by => 'developer')
    assert_equal [PropertyValue::NOT_SET, 'open', 'closed'], @view.group_lanes.visibles(:lane).collect(&:title)
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :filters => ["[status][is][open]"])
    assert_equal ['open'], @view.group_lanes.visibles(:lane).collect(&:title)
  end

  def test_only_show_lane_with_cards_behavior_should_works_when_group_by_user_property
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'developer')
    card = create_card!(:name => "admin's card", :developer => @admin.id)
    create_card!(:name => 'not set card')
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'developer')
    assert_equal [PropertyValue::NOT_SET, @admin.name], @view.group_lanes.visibles(:lane).collect(&:title)
  end

  def test_hide_lane_params_removes_the_lane_from_params
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'new,open'})
    assert_equal 'new', group_lanes.hide_dimension_params(:lane, 'open')[:lanes]
  end

  def test_hide_lane_params_ignores_non_existent_lanes
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'new,open'})
    assert_equal 'new,open', group_lanes.hide_dimension_params(:lane, 'whatchamacallit')[:lanes]
  end

  def test_validates_color_by
    assert_not_nil CardView::GroupLanes.new(@view, {:group_by => 'status', :color_by => 'developer'}).color_by_property_definition
    assert_nil CardView::GroupLanes.new(@view, {:group_by => 'status', :color_by => 'hackhack'}).color_by_property_definition
  end

  def test_validates_group_by
    assert_not_nil CardView::GroupLanes.new(@view, {:group_by => 'status'}).lane_property_definition
    assert_nil CardView::GroupLanes.new(@view, {:group_by => 'hackhack'}).lane_property_definition
  end

  def test_property_definition_uses
    assert CardView::GroupLanes.new(@view, {:group_by => 'status'}).uses?(@status)
    assert !CardView::GroupLanes.new(@view, {:group_by => 'status'}).uses?(@developer)
    assert CardView::GroupLanes.new(@view, {:group_by => 'status', :color_by => 'developer'}).uses?(@developer)
    assert CardView::GroupLanes.new(@view, {:group_by => 'status', :color_by => 'developer'}).uses?(@status)
    assert CardView::GroupLanes.new(@view, {:group_by => 'status', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'size'}}).uses?(@size)
    assert CardView::GroupLanes.new(@view, {:group_by => 'status', :aggregate_type => {:row => 'sum'}, :aggregate_property => {:row => 'size'}}).uses?(@size)
  end

  def test_property_definition_uses_in_group_sort_by
    assert CardView::GroupLanes.new(@view, {grid_sort_by: 'status'}).uses?(@status)
  end

  def test_to_params
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :color_by => 'developer', :lanes => 'new,open,close', :aggregate_type => {:column => 'sum'}, :aggregate_property => {:column => 'size'}})
    assert_equal({:lane => 'status'}, group_lanes.to_params[:group_by])
    assert_equal('developer', group_lanes.to_params[:color_by])
    assert_equal({:column => 'sum'}, group_lanes.to_params[:aggregate_type])
    assert_equal({:column => 'size'}, group_lanes.to_params[:aggregate_property])
    assert_equal('new,open,close', group_lanes.to_params[:lanes])
  end

  def test_rename_lane_should_change_lane_title_and_url
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'open'})
    assert group_lanes.rename_property_value('status', 'open', 'another open status')
    assert_equal('another open status', group_lanes.to_params[:lanes])
  end

  def test_rename_lane_should_case_insensitive
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'open'})
    assert group_lanes.rename_property_value('StAtus', 'oPen', 'another')
    assert_equal('another', group_lanes.to_params[:lanes])
  end

  def test_should_do_nothing_when_rename_excluded_lane
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => 'open'})
    assert !group_lanes.rename_property_value('status', 'new', 'another new status')
    assert_equal('open', group_lanes.to_params[:lanes])
  end

  def test_every_lane_should_only_contain_cards_that_belongs_to
    not_set_card = create_card!(:name => 'status not set card')
    open_card = create_card!(:name => 'open card', :status => 'open')
    closed_card = create_card!(:name => 'close card', :status => 'close')
    group_lanes = CardView::GroupLanes.new(@view, {:color_by => 'status'})
    assert_equal [not_set_card, open_card, closed_card].collect(&:name), group_lanes.cards.collect(&:name)
    assert_equal [0, 1, 2], group_lanes.cards.collect(&:index_in_card_list_view)
  end

  def test_card_should_have_card_list_view_index_if_there_is_color_by_property
    not_set_card = create_card!(:name => 'status not set card')
    open_card = create_card!(:name => 'open card', :status => 'open')
    closed_card = create_card!(:name => 'close card', :status => 'close')
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,close,new"})
    assert_equal [not_set_card], group_lanes.not_set_lane.cards
    assert_equal [open_card], group_lanes.lane('open').cards
    assert_equal [closed_card], group_lanes.lane('close').cards
    assert_equal [], group_lanes.lane('new').cards
  end

  def test_should_escape_property_value_with_comma_in_params
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'old_type', :lanes => ''})
    assert_equal ' ,bug\\,story', group_lanes.show_dimension_params(:lane, 'bug,story')[:lanes]
  end

  def test_lanes_with_user_property_definition
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'developer', :lanes => PropertyValue::NOT_SET_LANE_IDENTIFIER})
    assert_equal({:lane => 'developer'}, group_lanes.to_params[:group_by])
    admin_lane = @admin.login
    new_view = view_with_lane_visible(group_lanes, admin_lane)

    assert_equal "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},#{@admin.login}", new_view.to_params[:lanes]
    assert_equal [PropertyValue::NOT_SET, @admin.name], new_view.group_lanes.visibles(:lane).collect(&:title)
  end

  def test_lanes_shoud_smart_sort_by_lane_title
    @project.add_member(User.find_by_login('first'))
    @project.add_member(User.find_by_login('bob'))
    setup_user_definition 'sortTestDeveloper'
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'sortTestDeveloper', :lanes => 'JEN,foo,B A R'})
    assert_equal @project.users.collect(&:name).smart_sort.unshift(PropertyValue::NOT_SET),  group_lanes.lanes.collect(&:title)
  end

  def test_group_lane_should_be_empty_if_the_enumeration_of_lane_property_definition_is_empty
    setup_property_definitions :browse => {}
    assert CardView::GroupLanes.new(@view, {:group_by => 'browse'}).empty?
    assert CardView::GroupLanes.new(@view, {:group_by => 'noexist-browse'}).empty?
  end

  def test_lanes_should_include_not_set_lane
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'old_type', :lanes => ''})
    assert_equal PropertyValue::NOT_SET_LANE_IDENTIFIER, group_lanes.lanes.first.identifier
    assert_equal nil, group_lanes.lanes.first.value
  end

  def test_should_get_not_set_lanes_if_no_lanes_specified_and_have_not_set_card
    create_card!(:name => "This is first card")
    view = CardListView.find_or_construct(@project, :group_by => 'old_type')
    assert view.group_lanes.lanes.first.visible
  end

  def test_can_group_by_relationship_properties
    init_planning_tree_types
    tree_config = create_planning_tree_with_multi_types_in_levels.configuration
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    iteration2 = @project.cards.find_by_name('iteration2')

    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Planning release'})
    assert_equal ['iteration2', 'story4', 'story5', 'release1'].sort, group_lanes.not_set_lane.cards.collect(&:name).sort
    assert_equal ['iteration1', 'story1', 'story2', 'story3'].sort, group_lanes.lane(release1.number).cards.collect(&:name).sort

    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Planning iteration'})
    assert_equal ['iteration1', 'iteration2', 'story3', 'story5', 'release1'].sort, group_lanes.not_set_lane.cards.collect(&:name).sort
    assert_equal ['story1', 'story2'].sort, group_lanes.lane(iteration1.number).cards.collect(&:name).sort
    assert_equal ['story4'].sort, group_lanes.lane(iteration2.number).cards.collect(&:name).sort
  end

  def test_group_by_relationship_property_with_duplicate_card_name_as_values
    init_planning_tree_types
    tree_config = create_planning_tree_with_duplicate_iteration_names.configuration
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Planning iteration'})
    assert_equal ["(not set)", "release1 > iteration1", "release1 > iteration2", "release2 > iteration1", "release2 > iteration2"].sort, group_lanes.lanes.collect(&:title).sort
  end

  def test_group_by_week_order_property_should_auto_smart_sort_lanes
    init_planning_tree_types
    tree_config = create_planning_tree_with_duplicate_iteration_names.configuration

    release1 = @project.cards.find_by_name('release1')
    type_iteration = @project.card_types.find_by_name('iteration')

    tree_config.add_child(create_card!(:name => 'iteration15', :card_type => type_iteration), :to => release1)

    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Planning iteration'})
    expected = ["(not set)",
     "release1 > iteration1",
     "release1 > iteration2",
     "release1 > iteration15",
     "release2 > iteration1",
     "release2 > iteration2"
    ]
    assert_equal expected, group_lanes.lanes.collect(&:title)
  end

  def test_lane_header_card
    init_planning_tree_types
    tree_config = create_planning_tree_with_multi_types_in_levels.configuration
    release1 = @project.cards.find_by_name('release1')
    context = FakeCardContext.new

    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Planning release'})
    result = []

    group_lanes.lanes.each do |lane|
      result << lane.header_card(context)
    end

    assert_equal ["(not set)", "release1"], group_lanes.lanes.collect(&:title)
    assert_equal [nil, release1], result
    assert_equal [release1.number], context.numbers
  end

  def test_row_header_card
    init_planning_tree_types
    create_planning_tree_with_multi_types_in_levels
    release1 = @project.cards.find_by_name('release1')
    context = FakeCardContext.new

    view = CardListView.find_or_construct(@project, :filters => ["[Type][is][Story]"], :style => 'grid', :group_by => {:row => 'Planning release'})
    view.name = 'group lane by row property'
    view.save!
    view.reload

    result = []
    group_rows = view.groups.visibles(:row)

    group_rows.each do |row|
      result << row.header_card(context)
    end

    assert_equal ["(not set)", "release1"], group_rows.collect(&:title)
    assert_equal [nil, release1], result
    assert_equal [release1.number], context.numbers
  end

  def test_row_aggregate_value
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => {:row => 'status'}, :aggregate_type => {:row => "COUNT"})
    row = CardView::Row.new(@project, @view.group_lanes)
    row << CardView::LaneSupport::Cell.new(nil, OpenStruct.new(:db_identifier => 'db_identifier'), [@project.cards.first, @project.cards.second])
    assert_equal '2', row.aggregate_value
  end

  def test_row_knows_its_cards
    card1 = @project.cards.first
    card2 = @project.cards.second
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => {:row => 'status'}, :aggregate_type => {:row => "COUNT"})

    row = CardView::Row.new(@project, @view.group_lanes)
    row << CardView::LaneSupport::Cell.new(nil, OpenStruct.new(:db_identifier => 'db_identifier'), [card1])
    row << CardView::LaneSupport::Cell.new(nil, OpenStruct.new(:db_identifier => 'db_identifier'), [card2])
    assert_equal [card1, card2], row.cards
  end

  def test_ancestor_names
    init_planning_tree_types
    tree_config = create_three_level_tree.configuration
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Planning release'})
    release1 = @project.cards.find_by_name('release1')
    iteration1 = @project.cards.find_by_name('iteration1')
    lane = group_lanes.lane(release1.number)
    assert_equal [iteration1.number], ancestor_numbers(lane, 'story1')
    assert_equal [iteration1.number], ancestor_numbers(lane, 'story2')
    assert_equal [], ancestor_numbers(lane, 'iteration1')
  end

  def test_lane_aggregate_value_defaults_to_count_of_all_cards
    not_set_card = create_card!(:name => 'status not set card')
    open_card = create_card!(:name => 'open card', :status => 'open')
    closed_card = create_card!(:name => 'close card', :status => 'close')
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status', :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,close,new"})

    card_counts = { PropertyValue::NOT_SET => '1', 'open' => '1', 'close' => '1', 'new' => '0'}

    group_lanes.visibles(:lane).each do |lane|
      assert_equal card_counts[lane.title], lane.aggregate_value
    end
  end

  def test_can_aggregate_by_sum_of_numeric_property
    size = setup_numeric_property_definition('size', [1, 2, 3])

    not_set_card = create_card!(:name => 'status not set card')

    open_card_1 = create_card!(:name => 'open card 1', :status => 'open', :size => 1)
    open_card_2 = create_card!(:name => 'open card 2', :status => 'open', :size => 2)

    closed_card_1 = create_card!(:name => 'close card', :status => 'close', :size => 3)
    closed_card_2 = create_card!(:name => 'close card', :status => 'close', :size => 4)

    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status',
                                                   :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,close,new",
                                                   :aggregate_type => {:column => AggregateType::SUM.identifier},
                                                   :aggregate_property => {:column => size.name} })

    size_sums = { PropertyValue::NOT_SET => '0', 'open' => '3', 'close' => '7', 'new' => '0'}

    group_lanes.visibles(:lane).each do |lane|
      assert_equal size_sums[lane.title], lane.aggregate_value
    end
  end

  def test_average_aggregate_ignores_cards_without_chosen_property
    type_has_size = @project.card_types.create!(:name => 'has size')
    type_has_size.property_definitions = [@size, @status]
    type_no_size = @project.card_types.create!(:name => 'no size')
    type_no_size.property_definitions = [@status]

    open_card_1 = @project.cards.create!(:name => 'open card 1', :cp_status => 'open', :cp_size => 1, :card_type => type_has_size)
    open_card_2 = @project.cards.create!(:name => 'open card 2', :cp_status => 'open', :card_type => type_no_size)

    closed_card_1 = @project.cards.create!(:name => 'close card 1', :cp_status => 'close', :cp_size => 3, :card_type => type_has_size)
    closed_card_2 = @project.cards.create!(:name => 'close card 2', :cp_status => 'close', :card_type => type_no_size)
    closed_card_3 = @project.cards.create!(:name => 'close card 1', :cp_status => 'close', :cp_size => 4, :card_type => type_has_size)


    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status',
                                                   :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,close,new",
                                                   :aggregate_type => {:column => AggregateType::AVG.identifier},
                                                   :aggregate_property => {:column => @size.name} })

    size_sums = { PropertyValue::NOT_SET => '0', 'open' => '1', 'close' => '3.5', 'new' => '0'}

    group_lanes.visibles(:lane).each do |lane|
      assert_equal size_sums[lane.title], lane.aggregate_value
    end
  end

  def test_cannot_reorder_not_set_lane
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status',
                                                   :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,close,new",
                                                   :aggregate_type => {:column => AggregateType::AVG.identifier},
                                             :aggregate_property => {:column => @size.name} })
    not_set_lane = group_lanes.visibles(:lane).find { |lane| lane.identifier == PropertyValue::NOT_SET_LANE_IDENTIFIER }
    open_lane = group_lanes.visibles(:lane).find { |lane| lane.identifier == 'open' }
    assert !not_set_lane.can_reorder?
    assert open_lane.can_reorder?
  end

  def test_can_hide_not_set_lane
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'status',
                                                   :lanes => "#{PropertyValue::NOT_SET_LANE_IDENTIFIER},open,close,new",
                                                   :aggregate_type => {:column => AggregateType::AVG.identifier},
                                             :aggregate_property => {:column => @size.name} })
    not_set_lane = group_lanes.visibles(:lane).find { |lane| lane.identifier == PropertyValue::NOT_SET_LANE_IDENTIFIER }
    assert not_set_lane.can_hide?
  end

  def test_can_reorder_and_hide_text_enum_property_values
    status_group_lanes = CardView::GroupLanes.new(@view, { :group_by => 'status', :lanes => "open,close,new" })
    assert status_group_lanes.visibles(:lane).all? { |lane| lane.can_reorder? }
    assert status_group_lanes.visibles(:lane).all? { |lane| lane.can_hide? }
  end

  def test_can_reorder_and_hide_card_type_properties
    @project.card_types.create :name => 'bug'
    type_group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Type', :lanes => "Card,bug"})
    assert type_group_lanes.visibles(:lane).all? { |lane| lane.can_reorder? }
    assert type_group_lanes.visibles(:lane).all? { |lane| lane.can_hide? }
  end

  def test_hide_but_not_reorder_numeric_enum_property_values
    size_group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'size', :lanes => '1,2,3'})

    assert size_group_lanes.visibles(:lane).none? { |lane| lane.can_reorder? }
    assert size_group_lanes.visibles(:lane).all? { |lane| lane.can_hide? }
  end

  def test_direct_manipulation_is_supported_for_enumerated_text_properties
    group_lanes = CardView::GroupLanes.new(@view, { :group_by => 'status', :lanes => "open,close,new" })
    assert group_lanes.supports_direct_manipulation?(:lane)
  end

  def test_direct_manipulation_is_supported_for_enumerated_numeric_properties
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid')
      group_lanes = CardView::GroupLanes.new(view, {:group_by => 'Release', :lanes => "open,close,new"})
      assert group_lanes.supports_direct_manipulation?(:lane)
    end
  end

  def test_direct_manipulation_is_supported_for_user_properties
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid')
      group_lanes = CardView::GroupLanes.new(view, {:group_by => 'dev', :lanes => "open,close,new"})
      assert group_lanes.supports_direct_manipulation?(:lane)
    end
  end

  def test_direct_manipulation_is_supported_for_tree_relationship_properties
    with_three_level_tree_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid')
      group_lanes = CardView::GroupLanes.new(view, {:group_by => 'Planning iteration', :lanes => "open,close,new"})
      assert group_lanes.supports_direct_manipulation?(:lane)
    end
  end

  def test_direct_manipulation_is_supported_for_card_types
    group_lanes = CardView::GroupLanes.new(@view, {:group_by => 'Type', :lanes => "open,close,new"})
    assert group_lanes.supports_direct_manipulation?(:lane)
  end

  private

  class FakeCardContext
    attr_reader :numbers

    def initialize
      @numbers = []
    end

    def add_to_current_list_navigation_card_numbers(num)
      @numbers.concat(num)
      @numbers.uniq!
    end
  end

  def ancestor_numbers(lane, card_name)
    lane.cards.detect{ |card| card.name == card_name}.ancestors
  end

  def view_with_lane_visible(grouplanes, lane_identifier)
    CardListView.construct_from_params(@project, grouplanes.show_dimension_params(:lane, lane_identifier))
  end

end
