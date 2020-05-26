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

# Tags: filters
class Scenario08FilterCardListTest < ActiveSupport::TestCase 
  
  fixtures :users, :login_access
  
  ANY = '(any)'
  NOT_SET = '(not set)'
  
  VARIETY = 'Variety'
  FEATURE = 'Feature'
  PRIORITY = 'Priority'
  RELEASE = 'Release'
  SIZE = 'Size'
  TYPE = 'Type'
  
  ITERATION_TYPE = 'Iteration'
  RELEASE_TYPE = 'Release'
  CARD = 'Card'
  BUG = 'Bug'
  STORY = 'Story'  
  STORY_STATUS = 'Story Status'
  BUG_STATUS = 'Bug Status'
  BUG_PRIORITY ='Bug Priority'
  STORY_PRIORITY = 'Story Priority'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    login_as_project_member
    @project = create_project(:prefix => 'scenario_08', :users => [users(:project_member)])
    setup_property_definitions :Release => [1,2,4], :Feature => ['user','email'], :Priority => ['high', 'low', 'medium'], :Variety => ['story'], :Size => [8]
        
    @card_55 = create_card!(:name => 'card without tagging')
    @card_56 = create_card!(:name => 'crud user', :release => '1', :feature => 'user', :priority => 'high', :variety => 'story')
    @card_57 = create_card!(:name => 'tag as spam', :release => '2', :feature => 'email', :size => '8', :priority => 'medium', :variety => 'story').tag_with('bling')
    @card_58 = create_card!(:name => 'compose new email', :release => '2', :feature => 'email', :priority => 'high', :variety => 'story')
    @card_59 = create_card!(:name => 'add avatar to address', :release => '4', :feature => 'email', :priority => 'low', :variety => 'story').tag_with('bling')
    
    navigate_to_card_list_for(@project)
  end
  
  #bug 5219
  def test_using_invalid_card_number_in_the_url_for_filters_should_not_causes_the_applicatin_crash
    login_as_admin_user
    card_property = create_property_definition_for(@project, 'other_card', :type => CARD, :types => [CARD])
    #navigate_to_card_list_for(@project)
    #click_card_on_list(1)
    open_card(@project, @card_55)
    set_relationship_properties_on_card_show('other_card'=> @card_59)
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0,'Card')
    add_new_filter
    set_the_filter_property_option(1, 'other_card')
    set_the_filter_value_using_select_lightbox(1, @card_59)
    click_link_to_this_page

    assert_location_url("/projects/#{@project.identifier}/cards/list?filters%5B%5D=%5BType%5D%5Bis%5D%5BCard%5D&filters%5B%5D=%5Bother_card%5D%5Bis%5D%5B5%5D&page=1&style=list&tab=All")
    @browser.open("/projects/#{@project.identifier}/cards/list?filters%5B%5D=%5BType%5D%5Bis%5D%5BCardXXX%5D&filters%5B%5D=%5Bother_card%5D%5Bis%5D%5B5%5D&page=1&tab=All")
    @browser.assert_text_present("Filter is invalid. Card Type Type contains invalid value CardXXX")
  end
  
  
  def test_filtering_with_any_and_not_set
    card_release_one = create_card!(:name => 'release one card', :release => 1)
    card_release_four = create_card!(:name => 'release two card', :release => 4)
    card_without_release = create_card!(:name => 'card without release', :feature => 'user')

    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :release => NOT_SET)
    assert_cards_present(card_without_release)
    assert_cards_not_present(card_release_one, card_release_four)
      
    filter_card_list_by(@project, :release => ANY)
    assert_cards_present(card_without_release, card_release_one, card_release_four)
    
    filter_card_list_by(@project, :release => NOT_SET, :feature => NOT_SET)
    assert_cards_not_present(card_without_release, card_release_one, card_release_four)
    assert_card_not_present(card_release_four)
    
    filter_card_list_by(@project, :release => ANY, :feature => 'user')
    assert_card_present(card_without_release)
    assert_cards_not_present(card_release_one, card_release_four)
    
    filter_card_list_by(@project, :release => '4', :feature => NOT_SET)
    assert_card_present(card_release_four)
    assert_cards_not_present(card_release_one, card_without_release)
    
    reset_view
    assert_cards_present(card_release_one, card_release_four, card_without_release)
  end
  
  def test_basic_card_list_filter
    assert_filtering_remembers_sort_order
    
    reset_view
    assert_all_cards_present
        
    filter_card_list_by(@project, :release => '2')
    assert_properties_present_on_card_list_filter 'release' => '2'
    assert_cards_not_present(@card_55, @card_56, @card_59) 
    assert_cards_present(@card_57, @card_58)
    
    reset_view
    assert_all_cards_present
        
    filter_card_list_by(@project, :release => '2')
    filter_card_list_by(@project, :release => '1')
    assert_properties_present_on_card_list_filter 'release' => '1'
    assert_card_present @card_56
    assert_cards_not_present(@card_57, @card_58)
    
    reset_view    
    filter_card_list_by(@project, :priority => 'high')
    assert_properties_present_on_card_list_filter 'priority' => 'high'
    assert_cards_present(@card_56, @card_58)
    assert_cards_not_present(@card_55, @card_57, @card_59)
    reset_view
  end
  
  def test_filtering_remembers_columns
    add_column_for(@project, ['feature'])
    @browser.assert_column_present('cards', 'Feature')
    filter_card_list_by(@project, :feature => 'user')
    @browser.assert_column_present('cards', 'Feature')
  end
  
  def test_deleted_property_no_longer_appears_in_filter
    property_to_be_deleted = 'old_type'
    setup_property_definitions(property_to_be_deleted => [], :status => ['foo'])
    login_as_admin_user
    navigate_to_property_management_page_for(@project)
    delete_property_for(@project, property_to_be_deleted)
    navigate_to_card_list_for(@project)
    assert_property_not_present_on_card_list_filter(property_to_be_deleted)
  end
    
  # bug 799
  def test_ampersand_display_correctly_in_filter_widget
    setup_property_definitions :page => ['ruby & agile'], :status => ['open']
    login_as_admin_user
    navigate_to_card_list_by_clicking(@project)
    filter_card_list_by(@project, :page => ANY)
    @browser.click("cards_filter_1_values_drop_link")
    @browser.assert_element_matches(cards_filter_option(1, 'ruby & agile'), /ruby & agile/)
  end
  
  # bug 1889 & 1891
  def test_clicking_link_to_this_page_or_add_remove_columns_does_not_remove_filtering
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :priority => 'medium')
    click_link_to_this_page
    assert_properties_present_on_card_list_filter(:priority => 'medium')
    assert_card_present @card_57
    assert_cards_not_present(@card_55, @card_56, @card_58, @card_59)
    
    add_column_for(@project, ['variety'])
    assert_properties_present_on_card_list_filter(:priority => 'medium')
    assert_card_present @card_57
    assert_cards_not_present(@card_55, @card_56, @card_58, @card_59)
  end
  
  # bug 1893
  def test_can_switch_between_filtered_card_list_and_grid_views
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :release => '2')
    switch_to_grid_view
    assert_properties_present_on_card_list_filter(:release => '2')
    group_columns_by('Feature')
    assert_cards_present(@card_57, @card_58)
    assert_cards_not_present(@card_55, @card_56, @card_59)
  end
  

  # Bug 3159.
  def test_columns_should_be_union_of_card_type_properties
    feature, priority, size = [FEATURE, PRIORITY, SIZE].collect { |property_name| @project.find_property_definition(property_name) }
    type_release = setup_card_type(@project, RELEASE_TYPE, :properties => [FEATURE, PRIORITY])
    type_iteration = setup_card_type(@project, ITERATION_TYPE, :properties => [PRIORITY, SIZE])
    
    create_card!(:name => 'makes add / remove properties available', :card_type => type_release)
    navigate_to_card_list_for(@project)
    filter_card_list_by(@project, :type => RELEASE_TYPE)
    property_columns = [feature, priority]
    assert_properties_present_on_add_remove_column_dropdown(@project, property_columns)
    
    set_the_filter_property_and_value(1, :property => 'Type', :value => ITERATION_TYPE)
    property_columns << size
    assert_properties_present_on_add_remove_column_dropdown(@project, property_columns)
  end

  # bug 2564
  def test_when_only_type_remains_in_filter_property_selection_option_on_removal_other_filter_should_have_other_options
    login_as_admin_user
    setup_property_definitions(:"#{BUG_STATUS}" => %w(new open closed), :"#{BUG_PRIORITY}" => %w(ungent medium low), :"#{STORY_STATUS}" => %w(new assigned close), :"#{STORY_PRIORITY}" => ['must have', 'should have', 'could have'])
    setup_card_type(@project, STORY, :properties => [STORY_STATUS,STORY_PRIORITY])
    setup_card_type(@project, BUG, :properties => [BUG_STATUS,BUG_PRIORITY])
    
    navigate_to_card_list_for(@project)
    set_the_filter_value_option(0, STORY)
    
    add_new_filter
    assert_filter_property_present_on(1, :properties => [TYPE, STORY_STATUS, STORY_PRIORITY])  
    set_the_filter_property_and_value(1, :property => TYPE, :value => BUG)
    add_new_filter
    assert_filter_property_present_on(2, :properties => [TYPE])
    assert_filter_property_not_present_on(2, :properties => [STORY_STATUS, STORY_PRIORITY, BUG_STATUS, BUG_PRIORITY])
    remove_a_filter_set(1)
    assert_filter_property_present_on(2, :properties => [TYPE, STORY_STATUS, STORY_PRIORITY])
  end
  
  def assert_filtering_remembers_sort_order
    property_columns = ['Variety', 'Feature', 'Priority', 'Release']
    add_column_for(@project, property_columns)
    cards = HtmlTable.new(@browser, 'cards', ['number', 'name'] + @project.property_definitions_for_columns.collect{|prop| prop.name}, 1, 1)
    
    @browser.open "/projects/#{@project.identifier}/cards/list?order=ASC&sort=release&columns=release,priority,feature,variety"
    cards.assert_ascending('Release')

    filter_card_list_by(@project, :variety=> 'story', :keep_filters => true)
    cards.assert_ascending('Release')
    assert_column_present_for(*property_columns) #bug 1181
    
    filter_card_list_by(@project, :feature => 'email', :keep_filters => true)
    cards.assert_ascending('Release')
    assert_cards_not_present(@card_55, @card_56)
    assert_column_present_for(*property_columns)
    
    click_card_list_column_and_wait 'Priority'
    cards.assert_ascending('Priority')
    assert_cards_not_present(@card_55, @card_56)
    assert_column_present_for(*property_columns)
    
    filter_card_list_by(@project, :priority => 'high', :keep_filters => true)
    cards.assert_ascending('Priority')
    assert_cards_not_present(@card_55, @card_56, @card_57, @card_59)
    assert_column_present_for(*property_columns)
  end
  
  def assert_all_cards_present
    assert_cards_present(@card_55, @card_56, @card_57, @card_58, @card_59)
  end
  
  def assert_no_cards_present
    assert_cards_not_present(@card_55, @card_56, @card_57, @card_58, @card_59)
  end

end
       
