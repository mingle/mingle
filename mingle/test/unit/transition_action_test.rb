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

class TransitionActionTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def teardown
    Clock.reset_fake
  end

  def test_should_set_user_property_to_currently_logged_in_user
    transition = create_transition(@project, 'Story is done',
            :card_type => @story,
            :required_properties => {:status => 'open'},
            :set_properties => {:status => 'in progress', :dev => PropertyType::UserType:: CURRENT_USER})
    status = @project.find_property_definition('status')
    dev = @project.find_property_definition('dev')
    card = @project.cards.first
    last_user = @project.users.last
    status.update_card(card, 'open')
    card.save!

    logout_as_nil
    login(last_user.email)

    assert transition.available_to?(card.reload)
    transition.execute(card)
    card.save!
    card.reload
    
    assert_equal last_user, dev.value(card)
  end  

  def test_required_properties_with_today
    transition = create_transition(@project, 'some transition',
            :card_type => @story,
            :required_properties => {'start date' => PropertyType::DateType::TODAY}, 
            :set_properties => {:status => 'open'} )
    status = @project.find_property_definition('status')
    start_date = @project.find_property_definition('start date')
    card = @project.cards.first
    Clock.fake_now(:year => 2007, :month => 7, :day => 6)
    assert !transition.reload.available_to?(card)
    start_date.update_card(card, '06 Jul 2007')
    card.save!
    
    assert transition.reload.available_to?(card)
    transition.execute card
    card.save!
    card.reload
    
    assert_equal '06 Jul 2007', card.display_value(start_date)
    assert_equal 'open', card.display_value(status)
  end
  
  def test_should_set_date_property_to_today
    transition = create_transition(@project, 'some transition',
            :card_type => @story,
            :required_properties => {:status => 'open'}, 
            :set_properties => {'start date' => PropertyType::DateType::TODAY } )
    status = @project.find_property_definition('status')
    start_date = @project.find_property_definition('start date')
    card = @project.cards.first
    status.update_card(card, 'open')
    card.save!
    
    Clock.fake_now(:year => 2007, :month => 7, :day => 6)
    transition.execute card
    card.save!
    card.reload
    
    assert_equal '06 Jul 2007', card.display_value(start_date)
  end
  
  def test_should_update_card_from_transition_when_the_property_definition_is_transition_only
    with_new_project do |project|
      login_as_member
      setup_property_definitions(:status => ['open', 'close'])
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      transition = create_transition(project, 'some transition', :set_properties => {'status' => 'open'})
      card = create_card!(:name => 'I am card')
      assert_equal nil, status.value(card)
      transition.execute card
      assert_equal 'open', status.value(card)
    end
  end
  
  def test_target_property_should_return_project_variable_display_name
    with_new_project do |project|
      setup_property_definitions(:status => ['open', 'close'])
      status = project.find_property_definition('status')
      
      special_status = create_plv!(project, :name => 'special status', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'neither', :property_definitions => [status])
      project.reload

      transition = create_transition(project, 'some transition', :set_properties => {'status' => special_status.display_name})
      assert_equal '(special status)', transition.actions.first.target_property.display_value
    end
  end
  
end
