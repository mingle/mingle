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

class TransitionPrerequisiteTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def teardown
    Clock.reset_fake
  end
    
  def test_sti_works
    transition = create_transition(@project, 'fix', :set_properties => {:old_type => nil}, :user_prerequisites => [User.find_by_login('first').id])
    transition.add_value_prerequisite('old_type', 'bug')
    transition.save!

    assert_equal ['HasSpecificValue', 'IsUser'], @project.transitions.find_by_name("fix").prerequisites.collect(&:class).collect(&:name).sort
  end
  
  def test_has_specific_value
    @project.cards.find_by_number(1).update_attributes(:cp_old_type => 'bug')
    transition = create_transition(@project, 'fix',:set_properties => {:old_type => nil})
    
    prereq = HasSpecificValue.create!(:transition_id => transition.id, :required_property => property_value_from_db(@project, 'old_type', 'bug'))

    assert prereq.satisfied_by(@project.cards.find_by_number(1).reload)
    assert !prereq.satisfied_by(@project.cards.find_by_number(4).reload)
  end
  
  def test_has_set_value
    set_card = @project.cards.find_by_number(1)
    not_set_card = @project.cards.find_by_number(4)
    set_card.update_attributes(:cp_old_type => 'bug')
    not_set_card.update_attributes(:cp_old_type => nil)
    transition = create_transition(@project, 'fix', :set_properties => {:old_type => nil})
    
    prereq = HasSetValue.create!(:transition_id => transition.id, :property_definition => @project.find_property_definition('old_type'))

    assert prereq.satisfied_by(set_card.reload)
    assert !prereq.satisfied_by(not_set_card.reload)
  end
  
  def test_is_user
    transition = create_transition(@project, 'fix', :set_properties => {:old_type => nil})
    prereq = IsUser.create!(:transition_id => transition.id, :user_id => User.find_by_login("first").id)
    Thread.current['user'] = User.find_by_login("first")
    assert prereq.satisfied_by(@project.cards.find_by_number(1))
    Thread.current['user'] = User.find_by_login("member")
    assert !prereq.satisfied_by(@project.cards.find_by_number(1))  
  end

  def test_group_membership_prerequisite_is_not_satisfied_for_a_card_when_the_applicable_group_has_no_members
    group = create_group('group1')
    assert_equal false, InGroup.new(:group_id => group.id).satisfied_by(@project.cards.first)
  end
  
  def test_group_membership_prerequisite_is_not_satisfied_for_a_card_when_the_applicable_group_has_only_members_who_are_not_the_current_user
    member_who_is_not_current_user = @project.users.detect{|member| member.login != User.current.login }
    group = create_group('group1', [member_who_is_not_current_user])
    assert_equal false, InGroup.new(:group_id => group.id).satisfied_by(@project.cards.first)
  end
  
  def test_group_membership_prerequisite_is_satisfied_for_a_card_when_the_applicable_group_contains_the_current_user
    assert @project.member?(User.current)
    group = create_group('jimmy', [User.current])
    assert_equal true, InGroup.new(:group_id => group.id).satisfied_by(@project.cards.first)
  end
  
  def test_to_s_for_user_properties
    transition = create_transition(@project, 'make bob the owner', :set_properties => {:old_type => nil})
    action = HasSpecificValue.create!(:required_property => property_value_from_db(@project, 'dev', User.find_by_login('bob').id), :transition_id => transition.id)
    assert_equal "Has value of #{'bob@email.com'.bold} for #{'dev'.bold}", action.to_s    
  end  
  
  def test_top_level_prerequists_collection_should_be_a_and_collection
    transition = create_transition(@project, 'fix bug', :set_properties => {:status => 'fixed'})
    transition.add_value_prerequisite('old_type', 'bug')
    transition.add_value_prerequisite('status', 'open')
    transition.reload
    assert_equal(AndPrerequisitesCollection, transition.prerequisites_collection.class)
    assert_equal(2, transition.prerequisites_collection.prerequisites.size)
  end
  
  def test_should_put_all_is_user_prerequists_into_a_or_collection
    transition = create_transition(@project, 'fix bug', :set_properties => {:status => 'fixed'}, :user_prerequisites => [User.find_by_login('admin').id, User.find_by_login('first').id])
    transition.add_value_prerequisite('old_type', 'bug')
    transition.reload
    assert_equal(2, transition.prerequisites_collection.prerequisites.size)
    assert_equal([HasSpecificValue, OrPrerequisitesCollection], transition.prerequisites_collection.prerequisites.collect(&:class))
  end
  
  def test_should_be_availabe_for_all_cards_if_prerequisites_is_empty
    transition = create_transition(@project, 'fix bug', :set_properties => {:status => 'fixed'})
    story_card = create_card!(:name => 'card for test', :old_type => 'story')
    assert transition.available_to?(story_card)
  end
  
  def test_value_required_for_not_set_should_be_empty_string
    status = @project.find_property_definition('status')
    transition = create_transition(@project, 'open story', :required_properties => {:status => ''}, :set_properties => {:status => 'open'})
    assert_equal nil,  transition.value_required_for(status)
  end
  
  def test_value_required_for_project_variable                                                                                                                
    release = @project.find_property_definition('release')
    current_release = create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '2', :property_definition_ids => [release.id])
    transition = create_transition(@project, 'open in current release', :required_properties => {:release => current_release.display_name}, :set_properties => {:status => 'open'})
    assert_equal current_release.display_name, transition.value_required_for(release) 
  end
  
  def test_value_set_for_not_set_should_be_empty_string
    release = @project.find_property_definition('release')
    transition = create_transition(@project, 'reset release', :set_properties => {:release => ''})
    assert_equal nil,  transition.value_set_for(release)
  end
  
  # for bug 1239
  def test_transition_name_should_be_stripped
    assert_equal 'foo', Transition.new(:name => ' foo ').name
  end
  
  def test_card_type_is_available
    create_project(:admins => [User.find_by_login('proj_admin')]) do |project|
      login_as_admin
      setup_property_definitions :status => ['in progress', 'done']
      @status = project.find_property_definition('status')
      @story = project.card_types.create(:name => 'Story')
      @card = project.card_types.find_by_name('Card')
      @story.add_property_definition @status
      @card.add_property_definition @status
      @story.save
      @card.save
    
      transition = create_transition(project, 'Story is done', :card_type => @story, :required_properties => {:status => 'in progress'}, :set_properties => {:status => 'done'})
      card_with_story_type = create_card!(:name => 'I am a story', :card_type => @story, :status => 'in progress')
      assert transition.available_to?(card_with_story_type)
      card_with_card_type = create_card!(:name => 'I am a card', :card_type => @card, :status => 'in progress')
      assert !transition.available_to?(card_with_card_type)
    end  
  end
  
  def test_should_not_be_available_with_current_user_prerequisite_if_user_property_has_a_value_other_than_currently_logged_in_user
    transition = create_transition(@project, 'Story is done', :required_properties => {:dev => PropertyType::UserType:: CURRENT_USER}, :set_properties => {:status => 'done'})
    dev = @project.find_property_definition('dev')
    card = @project.cards.first
    last_user = @project.users.last
    
    assert_nil dev.value(card)
    assert !transition.available_to?(card)
    
    dev.update_card(card, last_user.id)
    card.save!
    logout_as_nil
    login(last_user.email)
    
    assert_equal last_user, dev.value(card)
    assert transition.available_to?(card)
  end  

  def test_transition_with_a_today_prerequisite_should_not_be_available_on_a_card_where_that_date_property_is_not_set_to_today
    card_type = @project.card_types.first
    
    transition = create_transition(@project, 'today transition', 
        :card_type => card_type, 
        :required_properties => {'start date' => PropertyType::DateType::TODAY}, 
        :set_properties => {:status => 'done'})
    start_date = @project.find_property_definition('start date')
    card = @project.cards.first
    
    assert_nil start_date.value(card)
    assert !transition.available_to?(card)
    
    Clock.fake_now(:year => 2007, :month => 10, :day => 3)
    start_date.update_card(card, Date.new(2007, 6, 7).to_s)
    card.save!
    assert !transition.available_to?(card)
    
    start_date.update_card(card, Date.new(2007, 10, 3).to_s)
    assert transition.available_to?(card)
  end  
  
  def test_required_property_should_return_project_variable_display_name
    release = @project.find_property_definition('release')
    current_release = create_plv!(@project, :name => 'current release', :value => '5', :data_type => ProjectVariable::NUMERIC_DATA_TYPE)
    current_release.property_definitions = [release]
    current_release.save!
    transition = create_transition(@project, 'close in current release',
                  :card_type => @project.card_types.first,
                  :required_properties => {:release => current_release.display_name},
                  :set_properties => {:status => 'open'})
    assert_equal current_release.display_name, transition.prerequisites.first.required_property.display_value
  end
end
