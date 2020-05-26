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

class CardContextTest < ActiveSupport::TestCase
  def setup
    @project = create_project
    @project.activate
    login_as_member
    @type_story = @project.card_types.create!(:name => 'story')
    @type_bug = @project.card_types.create!(:name => 'bug')
    @type_risk = @project.card_types.create!(:name => 'risk')
    @project.property_definitions.each {|pd| pd.update_attributes(:card_types => @project.reload.card_types)}
  end

  def test_last_tab_should_store_current_page_information_in_addition_to_rest_of_the_view_params
    context = CardContext.new(@project, {})
    (1..28).each { |i| @project.cards.create!(:name => "card #{i}", :card_type_name => 'story')}
    second_page_of_stories = CardListView.find_or_construct(@project, :filters => ['[Type][is][story]'], :page => 2)
    context.store_tab_state(second_page_of_stories, 'cards', nil)
    assert_equal second_page_of_stories.current_page, context.last_tab[:page]
  end

  def test_tab_for_should_switch_tabs_to_specific_tab_if_last_tab_no_longer_contains_this_card
    context = CardContext.new(@project, CardContext::LAST_TAB => {:columns => 'type,status,priority', :filters => ['[type][is][story]']})
    create_tabbed_view('Stories', @project, :filters => ['[type][is][story]'])
    create_tabbed_view('Bugs', @project, :filters => ['[type][is][bug]'])

    assert_equal 'Stories', context.tab_for('stories', nil)[:name]
    assert_equal 'Bugs', context.tab_for('bugs', nil)[:name]
  end

  # bug 7638
  def test_tab_for_should_return_all_tab_when_tab_name_params_does_not_exist
    context = CardContext.new(@project, {})
    @project.with_active_project do
      one = create_card!(:name => 'One')
      two = create_card!(:name => 'Two')
      context.current_list_navigation_card_numbers = [one, two].map(&:number)
      assert_equal DisplayTabs::AllTab::NAME, context.tab_for(nil, one)[:name]
    end
  end

  protected

  def assert_canonical_string_equal(expected, actual)
    expected = expected.split(',').collect(&:downcase).sort
    actual = actual.split(',').collect(&:downcase).sort
    assert_equal expected, actual
  end
end
