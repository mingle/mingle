# -*- coding: utf-8 -*-

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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: card-list
class ListViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  TYPE = 'Type'
  CREATED_BY = 'Created by'
  MODIFIED_BY = 'Modified by'
  PRIORITY = 'priority'
  STATUS = 'status'
  ITERATION = 'iteration'
  ESTIMATE = 'estimate'

  MB_PRIORITY = '팊료리'
  MB_HIGH = '티힉'
  MB_LOW = 'ㅎ로'
  MB_STATUS = 'ㅌㅅ타'
  MB_OPEN = '투소'
  MB_CLOSED = '펀ㅊ로'

  MB_RELEASE = '서러러ㅏ'
  MB_ITERATION = '세터라'
  MB_STORY = '툔ㅅ토'

  MB_TREE_NAME = 'ㅓㅍ란닝 ㅌ러'

  MB_RELATION_PLANNING_RELEASE = '툔ㅍ란닝 ㅌ러ㅓ - 러러ㅏ'
  MB_RELATION_PLANNING_ITERATION = '닢란닝 ㅌ러ㅓ - ㅣ터라'

  MB_RELEASE_CARD_NAME = '러러ㅏ서 찰ㄷ 나'
  MB_ITERATION_CARD_NAME = '메터라툔 찰ㄷ 나'
  MB_STORY_CARD_NAME = '멋토리 찰ㄷ 나'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @team_member = users(:project_member)
    @mingle_admin = users(:admin)
    @project_admin = users(:proj_admin)
    @read_only_user = users(:read_only_user)
    @browser = selenium_session
    @project = create_project(:prefix => 'list_view_test', :users => [@team_member], :admins => [@mingle_admin, @project_admin], :read_only_users => [@read_only_user])
    setup_property_definitions(:priority => ['low'], :status => ['fixed'], :iteration => [1, 3, 26])
    login_as_admin_user
  end

  def test_selection_should_be_remembered_in_dropdown_list_of_add_remove_columns_link
    create_card!(:name => 'the first card.')
    navigate_to_card_list_for(@project)

    add_column_for(@project,[TYPE])
    click_add_or_remove_columns_link
    assert_columns_selected(@project, [TYPE])
    assert_select_all_columns_not_checked

    add_all_columns
    click_add_or_remove_columns_link
    assert_columns_selected(@project,[TYPE,CREATED_BY,MODIFIED_BY,PRIORITY,STATUS,ITERATION])
    assert_select_all_columns_checked

    click_checkbox_of_column(@project, [ITERATION])
    assert_select_all_columns_not_checked
  end

  def test_order_of_columns
    setup_property_definitions(:estimate => [1,2])
    create_card!(:name => 'the first card.')

    navigate_to_card_list_for(@project)
    add_all_columns
    assert_column_present_for(TYPE,CREATED_BY,MODIFIED_BY,PRIORITY,STATUS,ITERATION,ESTIMATE)
    assert_columns_ordered(TYPE,ESTIMATE,ITERATION,PRIORITY,STATUS,CREATED_BY,MODIFIED_BY)

    remove_column_for(@project,[TYPE,ESTIMATE,PRIORITY,CREATED_BY])
    assert_column_not_present_for(TYPE,ESTIMATE,PRIORITY,CREATED_BY)
    assert_column_present_for(MODIFIED_BY,STATUS,ITERATION)
    assert_columns_ordered(ITERATION,STATUS,MODIFIED_BY)

    add_column_for(@project,[TYPE,ESTIMATE,PRIORITY,CREATED_BY])
    assert_column_present_for(TYPE,CREATED_BY,MODIFIED_BY,PRIORITY,STATUS,ITERATION,ESTIMATE)
    assert_columns_ordered(ITERATION,STATUS,MODIFIED_BY,TYPE,ESTIMATE,PRIORITY,CREATED_BY)

    remove_all_columns
    assert_column_not_present_for(TYPE,CREATED_BY,MODIFIED_BY,PRIORITY,STATUS,ITERATION,ESTIMATE)

    add_all_columns
    assert_columns_ordered(TYPE,ESTIMATE,ITERATION,PRIORITY,STATUS,CREATED_BY,MODIFIED_BY)
  end

  # bug 4529, #5049
  def test_to_view_cards_after_delete_its_history_version
    card1 = create_card!(:name => 'card 1', :status => 'fixed', :iteration => '1')
    card1.update_attributes(:cp_iteration => '3')
    navigate_to_card_list_for(@project)
    click_card_on_list(1)
    @browser.run_once_history_generation
    load_card_history
    assert_history_for(:card, card1.number).version(1).present
    assert_history_for(:card, card1.number).version(2).present
    Project.connection.execute("Delete from #{Project.connection.quote_table_name(Card::Version.table_name)} where id=#{card1.versions.last.id}")

    navigate_to_card_list_for(@project)
    click_card_on_list(1)
    assert_history_for(:card, card1.number).version(1).present
    assert_history_for(:card, card1.number).version(2).not_present

    login_as_project_member
    open_card(@project, card1)
    @browser.run_once_history_generation
    load_card_history
    assert_history_for(:card, card1.number).version(1).present
    assert_history_for(:card, card1.number).version(2).not_present

    login_as_read_only_user
    open_card(@project, card1)
    load_card_history
    assert_history_for(:card, card1.number).version(1).present
    assert_history_for(:card, card1.number).version(2).not_present
  end

  def test_card_list_and_sort
    as_user('member') do
      @browser.open("/projects/#{@project.identifier}")
      @card_1 = create_card!(:name => 'a basic navigation (card number 1)', :description => 'scenarios first story card', :status => 'fixed', :iteration => '1')
      @card_2 = create_card!(:name => 'spike (card number 2)', :description => 'scenarios second story card', :iteration => '3')
      @card_3 = create_card!(:name => 'more navigation (card number 3)', :description => 'scenarios third story card', :priority => 'low')
      @card_4 = create_card!(:name => 'Implement search (card number 4)', :description => 'scenarios fourth story card', :iteration => '26')
      @card_5 = create_card!(:name => '100 more things (card number 5)', :description => 'scenarios fifth story card', :iteration => '1')

      navigate_to_card_list_showing_iteration_and_status_for(@project)
      cards = HtmlTable.new(@browser, 'cards', ['number', 'name', 'iteration', 'status'], 1, 1)

      # sort by Number
      click_card_list_column_and_wait '#'
      cards.assert_ascending('Number')
      click_card_list_column_and_wait '#'
      cards.assert_descending('Number')

      # sort by Name
      click_card_list_column_and_wait 'Name'
      cards.assert_ascending('Name')
      click_card_list_column_and_wait 'Name'
      cards.assert_descending('Name')

      # sort by custom property columns
      @browser.assert_column_not_present('cards', 'priority')

      click_card_list_column_and_wait 'iteration'
      cards.assert_ascending('iteration')
      click_card_list_column_and_wait 'iteration'
      cards.assert_descending('iteration')

      click_card_list_column_and_wait 'status'
      cards.assert_ascending('status')
      click_card_list_column_and_wait 'status'
      cards.assert_descending('status')

      # remove tag group (column)
      @browser.assert_column_present('cards', 'status')
      @browser.click 'link=Add / remove columns'
      remove_column_for(@project, ['status'])
      @browser.assert_column_not_present('cards', 'status')
      cards.column_names = ['number', 'name', 'iteration']

      # removing the tag group that is the current sort
      # results in the card list sorting by the default (descending number)
      cards.assert_descending('Number')

      # sort again by remaining tag group
      click_card_list_column_and_wait 'iteration'
      cards.assert_ascending('iteration')
      click_card_list_column_and_wait 'iteration'
      cards.assert_descending('iteration')
    end
  end

  #bug 9602
  def test_card_list_view_sort_order_when_properties_are_NOT_SET
    setup_property_definitions "priority" => ['high', 'medium', 'low']
    setup_user_definition("owner")
    card_foo = create_card!(:name => 'foo', "priority" => 'high', "owner" => @mingle_admin.id)
    card_bar = create_card!(:name => 'bar')
    navigate_to_card_list_for(@project)
    add_column_for(@project,["priority", "owner"])
    click_card_list_column_and_wait 'priority'
    @browser.assert_ordered(card_foo.html_id, card_bar.html_id)
    click_card_list_column_and_wait 'priority'
    @browser.assert_ordered(card_bar.html_id, card_foo.html_id)
    click_card_list_column_and_wait 'owner'
    @browser.assert_ordered(card_foo.html_id, card_bar.html_id)
    click_card_list_column_and_wait 'owner'
    @browser.assert_ordered(card_bar.html_id, card_foo.html_id)
  end

  # bug 585
  def test_view_column_remembered_should_be_project_specific
    as_user('member') do
      @browser.open("/projects/#{@project.identifier}")
      create_card!(:name => 'first card', :status => 'new')

      another_project = create_project(:prefix => 'bug585_another', :users => [users(:project_member)])
      setup_property_definitions :status => ['new', 'open']
      create_card!(:name => 'another first card', :status => 'open')

      navigate_to_card_list_for(@project, ['status'])
      navigate_to_card_list_by_clicking(another_project)
      @browser.assert_column_not_present('cards', 'status')
      navigate_to_card_list_by_clicking(@project)
      @browser.assert_column_present('cards', 'status')
    end
  end

  # bug 981
  def test_card_list_view_should_not_have_next_link_when_current_page_is_the_last_one
    as_user('member') do
      @browser.open("/projects/#{@project.identifier}")
      create_cards(@project, 2)
      navigate_to_card_list_by_clicking(@project)
      assert_link_not_present("/projects/#{@project.identifier}/cards/list?page=2")
      @browser.assert_element_not_present 'link=Next'
    end
  end

  # bug 3986.
  def test_should_be_able_to_display_multi_byte_properties_when_filtering_with_multi_byte_tree_relationships_without_causing_error
    as_user('member') do
      @browser.open("/projects/#{@project.identifier}")
      setup_property_definitions MB_PRIORITY => [MB_HIGH, MB_LOW], MB_STATUS => [MB_OPEN, MB_CLOSED]

      release_type = setup_card_type(@project, MB_RELEASE, :properties => [MB_PRIORITY, MB_STATUS])
      iteration_type = setup_card_type(@project, MB_ITERATION, :properties => [MB_PRIORITY, MB_STATUS])
      story_type = setup_card_type(@project, MB_STORY, :properties => [MB_PRIORITY, MB_STATUS])

      tree = setup_tree(@project, MB_TREE_NAME, :types => [release_type, iteration_type, story_type],
        :relationship_names => [MB_RELATION_PLANNING_RELEASE, MB_RELATION_PLANNING_ITERATION])

      release_card = create_card!(:card_type => release_type, :name => MB_RELEASE_CARD_NAME, MB_PRIORITY => MB_HIGH, MB_STATUS => MB_OPEN)
      iteration_card = create_card!(:card_type => iteration_type, :name => MB_ITERATION_CARD_NAME, MB_PRIORITY => MB_LOW, MB_STATUS => MB_CLOSED)
      story_card = create_card!(:card_type => story_type, :name => MB_STORY_CARD_NAME, MB_PRIORITY => MB_LOW, MB_STATUS => MB_CLOSED)

      add_card_to_tree(tree, release_card)
      add_card_to_tree(tree, iteration_card, release_card)
      add_card_to_tree(tree, story_card, iteration_card)

      navigate_to_card_list_for(@project)
      select_tree(tree.name)

      set_tree_filter_for(release_type, 0, :property => MB_RELATION_PLANNING_RELEASE, :value => release_card.number)
      set_tree_filter_for(iteration_type, 0, :property => MB_RELATION_PLANNING_ITERATION, :value => iteration_card.number)

      add_column_for(@project, [MB_PRIORITY, MB_STATUS])
      assert_column_present_for(MB_PRIORITY, MB_STATUS)
    end
  end

  # bug 948
  def test_sorting_card_list_with_properties_using_special_sql_or_ruby_words
    special_words = ['class', 'send', 'select', 'table', 'new']

    project2 = create_project(:prefix => 'bug948', :users => [users(:admin), users(:project_member)])
    properties_and_values = special_words.map {|word| {word.humanize => %w(a b)} }.inject(&:merge)
    setup_property_definitions properties_and_values
    project2.reload

    as_user('member') do
      special_words.each {|property| assert_sorting_for(project2, property)}
    end
  end

  #bug 7351
  def test_add_new_column_to_card_list_view_should_not_change_the_current_cards_order
    new_card_1 = create_card!(:name => 'a_new_card', :description => 'scenarios first story card', :status => 'fixed', :iteration => '1')
    new_card_2 = create_card!(:name => 'b_new_card', :description => 'scenarios second story card', :iteration => '3')
    navigate_to_card_list_for(@project)
    @browser.assert_ordered(new_card_2.html_id, new_card_1.html_id)
    @browser.with_ajax_wait do
      @browser.click("link=Name")
    end
    @browser.assert_ordered(new_card_1.html_id, new_card_2.html_id)
    add_column_for(@project, [ITERATION])
    @browser.assert_ordered(new_card_1.html_id, new_card_2.html_id)
  end

  def assert_sorting_for(project, property)
    project.cards.map(&:destroy)
    create_cards_with_property property

    @browser.open "/projects/#{project.identifier}"
    navigate_to_card_list_for project
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name', property], 1, 1)
    add_column_for(project, [property])
    property = property.capitalize!
    assert_ascending_for cards, property
    assert_descending_for cards, property
  end

  #bug #11089
  def test_should_not_see_500_error_when_showing_all_columns
     create_card!(:name => 'the first card.')
     create_card_type_property("test")
     @project.find_property_definition("test").update_attributes(:name => "related card")
     setup_user_definition("test")
     @project.find_property_definition("test").update_attributes(:name => "related user")
     create_card_type_property("test")
     navigate_to_card_list_for(@project)
     add_all_columns
     assert_column_present_for(TYPE,ITERATION,PRIORITY,"related card","related user",STATUS,"test",CREATED_BY,MODIFIED_BY)
  end

  #bug 12840
  def test_should_show_up_cards_when_quick_add_cards_on_list
    navigate_to_card_list_for(@project)
    assert_quick_add_link_present_on_funky_tray
    add_card_via_quick_add("new card")
    card = @project.cards.find_by_name("new card")
    assert_notice_message("Card ##{card.number} was successfully created.", :escape => true)
    assert_cards_present_in_list(card)
    add_card_via_quick_add("second card")
    card2 = find_card_by_name("second card")
    assert_notice_message("Card ##{card2.number} was successfully created.", :escape => true)
    assert_cards_present_in_list(card,card2)
   end

   def test_new_card_only_shows_in_card_list_for_its_project
     @another_project = create_project(:prefix => 'list_view_test2', :users => [users(:project_member)])
     create_cards(@project,1,:card_name => "belongs to first project")
     @browser.open("/projects/#{@project.identifier}/cards/list")
     @browser.assert_text_present "belongs to first project"
     @browser.open "/projects/#{@another_project.identifier}/cards/list"
     @browser.assert_text_not_present "belongs to first project"
   end

   def test_name_are_not_truncated
     card =create_card!(:name => "This is a very, very, very, very, very, very, very, very, very long name")
     @browser.open "/projects/#{@project.identifier}/cards/list"
     @browser.assert_text_present card.name
   end

  private
  def create_cards_with_property(property)
    card_1 = create_card! :name => 'card one', property.to_sym => 'b'
    card_2 = create_card! :name => 'card two', property.to_sym => 'b'
    card_3 = create_card! :name => 'card three', property.to_sym => 'a'
    card_4 = create_card! :name => 'card four', property.to_sym => 'b'
  end

  def assert_ascending_for(table, property)
    click_card_list_column_and_wait "#{property}"
    table.assert_ascending(property)
  end

  def assert_descending_for(table, property)
    click_card_list_column_and_wait "#{property}"
    table.assert_descending(property)
  end
end
