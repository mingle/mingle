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

class CardTypeBehaviourOnCardListViewTest < ActiveSupport::TestCase
  
  def setup
    login_as_member
    @project = create_project
    @project.activate
    @card_type = @project.card_types.find_by_name('Card')
    @story_type = @project.card_types.create :name => 'story'
    @bug_type = @project.card_types.create :name => 'bug'
    
    @story_card1 = create_card!(:name => 'story 1', :card_type => @story_type)
    @story_card2 = create_card!(:name => 'story 2', :card_type => @story_type)
    @bug_card1 = create_card!(:name => 'bug 1', :card_type => @bug_type)
    @project.reload
  end

  def test_filter_by_card_type
    view = create_view_with_card_type(@story_type.name)
    assert_equal [@story_card1, @story_card2].sort_by(&:number).collect(&:name), view.cards.sort_by(&:number).collect(&:name)

    view = create_view_with_card_type(@bug_type.name)
    assert_equal [@bug_card1].sort_by(&:number).collect(&:name), view.cards.sort_by(&:number).collect(&:name)
  end

  def test_can_convert_to_card_query
    view = create_view_with_card_type(@story_type.name)
    assert_equal_ignoring_spaces "SELECT Number, Name WHERE Type is #{@story_type.name} Order by Number DESC", view.as_card_query.to_s
    
    expected = [{"Name"=>"story 2", "Number"=>"2"}, {"Name"=>"story 1", "Number"=>"1"}].sort_by{|card| card['Number']}
    
    assert_equal expected , view.as_card_query.values.sort_by{|card| card['Number']}
  end
  
  def test_convert_to_card_query_with_mutli_filter_properties_and_specific_columns_sort_and_so_on
    setup_property_definitions :status => ['new', 'open', 'close'], :iteration => ['1', '2']
    
    @bug_type.add_property_definition @project.find_property_definition('status')
    @bug_type.add_property_definition @project.find_property_definition('iteration')
    
    @bug_card2 = create_card!(:name => 'bug 2', :card_type => @bug_type, :iteration => '1', :status => 'new')
    @bug_card3 = create_card!(:name => 'bug 3', :card_type => @bug_type, :iteration => '1', :status => 'new')
    @bug_card4 = create_card!(:name => 'bug 4', :card_type => @bug_type, :iteration => '2', :status => 'new')

    request_params = {
      :sort => 'iteration', 
      :filters => ["[status][is][new]", "[iteration][is][1]", "[type][is][#{@bug_type.name}]"],
      :order => 'asc', 
      :page => '1', 
      :columns => 'status,type'}
    view = CardListView.find_or_construct(@project, request_params)
    view.name = 'test view name'
    view.save!
    view = @project.card_list_views.find_by_name('test view name')
    assert_equal_ignoring_order(
      "SELECT Number, Name, Status, Type WHERE (Iteration is 1 AND Status is New And Type is #{@bug_type.name}) ORDER BY Iteration asc, Number DESC",
      view.as_card_query.to_s)
  end
  
  def test_should_sort_by_card_type_order
    card1 = create_card!(:name => 'card 1', :card_type => @card_type)
    view = CardListView.find_or_construct @project, {:sort => 'type'}
    
    assert_equal @project.card_types.collect(&:name), view.cards.collect(&:card_type).collect(&:name).uniq

    @story_type.update_attributes(:position => 3)
    @card_type.update_attributes(:position => 2)
    @bug_type.update_attributes(:position => 1)
    
    view = CardListView.find_or_construct @project, {:sort => 'type'}
    assert_equal @project.reload.card_types.collect(&:name), view.cards.collect(&:card_type).collect(&:name).uniq
    assert_equal 'bug', view.cards.first.card_type.name
    assert_equal 'story', view.cards.last.card_type.name
  end
  
  def test_should_convert_to_card_query_when_sort_by_card_type
    view = CardListView.find_or_construct @project, {:sort => 'type'}
    assert_equal_ignoring_spaces "SELECT Number, Name ORDER BY Type asc, Number desc", view.as_card_query.to_s
  end
  
  def test_uses_card_type
    view = create_view_with_card_type(@story_type.name)
    assert view.uses_card_type?(@story_type)
    assert !view.uses_card_type?(@card_type)
    group_lane_view = CardListView.find_or_construct @project, {:group_by => 'type', :lanes => @story_type.name}
    assert group_lane_view.uses_card_type?(@story_type)
    assert !group_lane_view.uses_card_type?(@card_type)
  end

  def test_should_destroy_card_list_view_and_subscription_and_transitions_related_when_destroy_card_type
    user = User.find_by_login('member')
    @project.add_member(user)
    setup_property_definitions :status => ['new', 'open', 'close']
    
    status_prop = @project.find_property_definition :status
    
    status_prop.card_types = [@story_type]
    status_prop.save!
    
    view = create_view_with_card_type(@story_type.name)
    transition = create_transition(@project, 'destroy card type', :card_type => @story_type, :set_properties => {:status => 'open'})
    
    subscription = @project.create_history_subscription(user, "involved_filter_properties[type]=story")
    
    @project.reload
    @story_type.reload

    @story_type.destroy
    @project.reload
    status_prop.reload
    
    assert status_prop.card_types.empty?
    assert_nil @project.card_list_views.find_by_name(view.name)
    assert_nil @project.transitions.find_by_name(transition.name)
    assert @project.history_subscriptions.empty?
  end
  
  def create_view_with_card_type(name)
    CardListView.find_or_construct @project, {:filters => ["[type][is][#{name}]"]}
  end
end
