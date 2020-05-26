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

class ActsAsAttributeChangingObservableTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
    @card = @project.cards.find_by_number(1)
    login_as_member
    Card.acts_as_attribute_changing_observable
  end
  
  def test_observer_should_be_notified_when_attribute_changed
    ob1 = nil
    ob2 = nil
    
    @card.after_attribute_change(:name) do |old_value, new_value|
      ob1 = [old_value, new_value]
    end
    
    @card.after_attribute_change(:name) do |old_value, new_value|
      ob2 = [old_value, new_value]
    end
    
    @card.update_attribute(:name,  'new name')
    assert_equal ['first card', 'new name'], ob1
    assert_equal ['first card', 'new name'], ob2
  end
    
  def test_for_observe_new_record
    ob = nil
    card = Card.new({:name => 'new name', :project => @project, :card_type => @project.card_types.first})

    card.after_attribute_change(:name) do |old_value, new_value|
      ob = [old_value, new_value]
    end
    
    card.save!

    assert_equal [nil, 'new name'], ob
  end
  
  def test_observer_should_only_get_notification_about_the_attribute_it_cares
    ob = nil
    
    @card.after_attribute_change(:desc) do |old_value, new_value|
      ob = [old_value, new_value]
    end
    
    @card.update_attribute(:name,  'new name')
    assert_nil ob
  end
  
  def test_observer_should_not_be_disturb_if_no_change_happens
    ob = nil
    
    @card.after_attribute_change(:desc) do |old_value, new_value|
      ob = [old_value, new_value]
    end
    
    @card.update_attribute(:name,  @card.name)
    assert_nil ob
  end
    
end
