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

class HistoryFiltersTest < ActiveSupport::TestCase  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_should_raise_invalid_property_error_when_property_cannot_be_found
    assert_raise HistoryFilters::InvalidError, "Property invalid property does not exist." do
      HistoryFilters.new(@project, :involved_filter_properties => {'invalid property' => 'open'}).to_sql
    end
  end
  
  def test_filter_property_values_can_be_not_set
    filters = HistoryFilters.new(@project, :involved_filter_properties => {'status' => ''})
    assert filters.to_sql =~ /cp_status IS NULL/
    
    filters = HistoryFilters.new(@project, :acquired_filter_properties => {'status' => ''})
    assert filters.to_sql =~ /changes.new_value IS NULL/
    
    filters = HistoryFilters.new(@project, :involved_filter_properties => {'status' => ''}, :acquired_filter_properties => {'status' => ''})
    assert filters.to_sql =~ /cp_status IS NULL/
    assert filters.to_sql =~ /changes.new_value IS NULL/
    assert filters.to_sql =~ /changes.old_value IS NULL/
  end
  
  def test_should_return_results_for_existing_properties_for_involved_properties_filter
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attributes(:cp_priority => 'high')
    card.update_attributes(:cp_status => nil)
    generate_card_changes_for(card)
    assert_equal 2, filtered_events(:involved_filter_properties => {'status' => 'open'}).size
  end  
  
  def test_should_return_results_for_existing_hidden_properties_for_involved_properties_filter
     @project.find_property_definition('status').update_attribute(:hidden, true)
     @project.reload
     
     card =create_card!(:name => 'card1', :status => 'open')
     card.update_attributes(:cp_priority => 'high')
     card.update_attributes(:cp_status => nil)
     generate_card_changes_for(card)
     assert_equal 2, filtered_events(:involved_filter_properties => {'status' => 'open'}).size
   end  
  
  def test_should_return_results_for_acquired_properties_for_acquired_properties_filter
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attributes(:cp_priority => 'high')
    card.update_attributes(:cp_status => nil)
    generate_card_changes_for(card)
    
    assert_equal 1, filtered_events(:acquired_filter_properties => {'status' => 'open'}).size
    assert_equal 1, filtered_events(:acquired_filter_properties => {'priority' => 'high'}).size
  end  
  
  def test_should_return_results_for_acquired_hidden_properties_for_acquired_properties_filter
    @project.find_property_definition('status').update_attribute(:hidden, true)
    @project.find_property_definition('priority').update_attribute(:hidden, true)
    @project.reload    
    
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attributes(:cp_priority => 'high')
    card.update_attributes(:cp_status => nil)
    generate_card_changes_for(card)
    
    assert_equal 1, filtered_events(:acquired_filter_properties => {'status' => 'open'}).size
    assert_equal 1, filtered_events(:acquired_filter_properties => {'priority' => 'high'}).size
  end
  
  def test_should_return_results_for_current_project_only
    with_new_project do |project|
      other_card = create_card!(:name => 'card10')
      other_card.tag_with('apple').save!
    end
    
    @project.activate
    card = create_card!(:name => 'card1', :status => 'open', :priority => 'high')
    card.tag_with('apple').save!
    
    generate_card_changes_for(card)
    
    assert_equal 1, filtered_events(:acquired_filter_tags => ['apple']).size
  end  
  
  def test_should_return_first_version_where_atleast_one_tag_was_acquired_when_specifying_acquired_filter_tags
    card =create_card!(:name => 'smart name') #1
    card.update_attribute(:cp_old_type, 'story') #2
    card.add_tag('luke') #3
    card.save!
    card.add_tag('history') #4
    card.save!

    filters = HistoryFilters.new(@project, :involved_filter_properties => {'old_type' => 'story'}, :acquired_filter_tags => ['luke','history'])
    assert_equal 0, filters.events.size
  end  

  def test_should_be_able_to_see_bugs_that_I_moved_from_fixed_to_closed_in_a_given_time_period
    login_as_admin
    bug =create_card!(:name => 'bug', :old_type => 'bug', :status => 'open') #1
    login_as_member
    bug.update_attributes(:cp_status => 'in progress') #2
    bug.update_attributes(:cp_status => 'fixed') #3
    login_as_admin
    bug.update_attributes(:cp_status => 'closed') #4
    login_as_member

    generate_card_changes_for(bug)
    only_result, *others = filtered_events(:period => :all_history, 
                                    :involved_filter_properties => {:old_type => 'bug', :status => 'fixed'},
                                    :acquired_filter_properties => {:status => 'closed'},
                                    :filter_user => User.find_by_login('admin'))
    assert others.empty?                                
    assert_equal bug.reload.versions[3].id, only_result["version_id"].to_i
  end
  
  def test_involved_properties_filter_honors_earliest_version_params
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attributes(:cp_priority => 'high')
    card.update_attributes(:cp_status => nil)
    card.update_attributes(:cp_status => 'open')
    generate_card_changes_for(card)
    
    filters = HistoryFilters.new(@project, :involved_filter_properties => {'status' => 'open'})
    assert_equal 2, filters.fresh_events(:card_version => card.reload.versions.first.id).size
  end
  
  def test_acquired_properties_filter_honors_earliest_version_params
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attributes(:cp_status => nil)
    card.update_attributes(:cp_status => 'open')
    card.update_attributes(:cp_status => nil)
    
    generate_card_changes_for(card)
    filters = HistoryFilters.new(@project, :acquired_filter_properties => {'status' => 'open'})
    assert_equal 1, filters.fresh_events(:card_version => card.reload.versions.first.id).size  
  end
  
  # bug 1514
  def test_distinct_events_returned_when_mulitple_acquired_filters
    with_first_project do |project|
      card =create_card!(:name => 'test_card')
      card.update_attributes(:cp_status => 'fixed', :cp_iteration => '1')
      generate_card_changes_for(card)
      filters = HistoryFilters.new(project, :acquired_filter_properties => {:status => 'fixed', :iteration => '1'})
      assert_equal 1, filters.events.size
    end
  end
  
  def test_combine_involved_and_acquired_filters_to_see_specific_property_value_changes
    with_first_project do |project|
      card1 =create_card!(:name => 'test_card', :status => 'new')
      card2 =create_card!(:name => 'test_card', :status => 'fixed')
      card1.update_attributes(:cp_status => 'open', :cp_iteration => '1')
      card2.update_attributes(:cp_status => 'open', :cp_iteration => '1')
      generate_card_changes_for(card1, card2)
      reopened_bugs = HistoryFilters.new(project, :involved_filter_properties => {:status => 'fixed'},
        :acquired_filter_properties => {:status => 'open'})
      assert_equal 1, reopened_bugs.events.size
    end
  end
  
  def test_combin_multiple_involved_and_acquired_filters
    project_without_cards.with_active_project do |project|
      card1 =create_card!(:name => 'test_card', :status => 'new', :release => '1')
      card2 =create_card!(:name => 'test_card', :status => 'fixed', :release => '1')
      card1.update_attributes(:cp_status => 'open', :cp_iteration => '1')
      card2.update_attributes(:cp_status => 'open', :cp_iteration => '1', :cp_release => '2')
      generate_card_changes_for(card1, card2)
      reopened_bugs = HistoryFilters.new(project, :involved_filter_properties => {:status => 'fixed', :release => '1'},
        :acquired_filter_properties => {:status => 'open', :release => '2'})
      events = reopened_bugs.events
      assert_equal 1, events.size
      assert_equal card2.reload.versions.last.id, events.first.id
    end
  end
  
  def test_involved_filter_properties_works_with_user_properties
    member = User.find_by_login('member')
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attribute :cp_dev, member
    card.update_attribute :cp_status, 'in progress'
    generate_card_changes_for(card)
    assert_equal 2, filtered_events(:involved_filter_properties => {'dev' => member.id}).size
  end
   
  def test_acquired_filter_properties_works_with_user_properties
    member = User.find_by_login('member')
    card =create_card!(:name => 'card1', :status => 'open')
    card.update_attribute :cp_dev, member
    card.update_attribute :cp_status, 'in progress'
    generate_card_changes_for(card)
    assert_equal 1, filtered_events(:acquired_filter_properties => {'dev' => member.id}).size  
  end
  
  def test_should_allow_filtering_by_not_set_in_addition_to_property_values
    project_without_cards.with_active_project do |project|
      bug1 = project.cards.new(:name => 'bug 1', :project => project, :card_type => project.card_types.first)
      bug1.update_attributes :cp_old_type => 'bug', :cp_release => '1'
      set_modified_time(bug1, 1, 2004, 10, 4, 10, 0, 0)

      bug1.update_attribute :cp_status, 'open'   
      set_modified_time(bug1, 2, 2004, 10, 6, 11, 0, 0)
    
      bug1.update_attribute :cp_status, nil  
      set_modified_time(bug1, 3, 2004, 10, 7, 12, 0, 0)

      bug2 = project.cards.new(:name => 'bug 2', :project => project, :card_type => project.card_types.first)
      bug2.update_attributes :cp_old_type => 'bug', :cp_release => '1'
      set_modified_time(bug2, 1, 2004, 10, 4, 10, 0, 0)
    
      generate_card_changes_for(bug1, bug2)
      filters = HistoryFilters.new(project, :involved_filter_properties => {'status' => ''})
      assert_equal 3, filters.events.size
      
      filters = HistoryFilters.new(project, :acquired_filter_properties => {'status' => ''})
      assert_equal 1, filters.events.size
      
      filters = HistoryFilters.new(project, :involved_filter_properties => {'status' => 'open'}, :acquired_filter_properties => {'status' => ''})
      assert_equal 1, filters.events.size
      
      filters = HistoryFilters.new(project, :involved_filter_properties => {'status' => ''}, :acquired_filter_properties => {'status' => 'open'})
      assert_equal 1, filters.events.size
    end  
  end
  
  def test_should_work_with_card_type
    story_type = @project.card_types.create :name => 'story'
    bug_type = @project.card_types.create :name => 'bug'
    card = create_card!(:name => 'card1', :status => 'open', :card_type => story_type)
    generate_card_changes_for(card)
    assert_equal 1, filtered_events(:acquired_filter_properties => {'type' => story_type.name}).size
    
    card.card_type = bug_type
    card.save!
    generate_card_changes_for(card)
    
    assert_equal 1, filtered_events(:involved_filter_properties => {'type' => story_type.name}).size
    assert_equal 1, filtered_events(:involved_filter_properties => {'type' => bug_type.name}).size
  end
  
  # bug 3716
  def test_calling_event_count_on_history_with_period_should_not_blow_up_when_properties_have_question_marks_in_their_names
    with_new_project do |project|
      setup_numeric_property_definition('question?', [1, 2, 3])
      card = project.cards.create!(:name => 'card1', :card_type_name => 'Card', 'cp_question_' => '2')
      
      filters = HistoryFilters.new(project, :acquired_filter_properties => {'question?' => '2'}, :period => :all_history)
      begin
        filters.event_count
      rescue Exception => e
        fail "An exception should not have been thrown by event_count method."
      end
    end
  end
  
  def test_acquired_filter_properties_works_with_any_change
    card1 =create_card!(:name => 'card1')
    card2 = create_card!(:name => 'card2')
    card1.update_attribute :cp_status, 'in progress'
    generate_card_changes_for(card1, card2)
    result = filtered_events(:acquired_filter_properties => {'status' => '(any change)'})
    assert_equal 1, result.size
  end
  
  def test_acquired_filter_properties_works_with_not_set_in_involved_filters_and_any_change_in_acquired_filters
    card =create_card!(:name => 'card1')
    card.update_attribute :cp_status, 'in progress'
    generate_card_changes_for(card)
    result = filtered_events(:involved_filter_properties => {'status' => ''} ,:acquired_filter_properties => {'status' => '(any change)'})
    assert_equal 1, result.size
  end
  
  def test_filters_should_work_of_changing_value_back_with_any_change
    card = create_card!(:name => 'card1', :status => 'open')
    card.update_attribute :cp_status, 'in progress'
    card.update_attribute :cp_status, 'open'
    generate_card_changes_for(card)
    result = filtered_events(:involved_filter_properties => {'status' => 'open'} ,:acquired_filter_properties => {'status' => '(any change)'})
    assert_equal 1, result.size
  end
  
  def test_any_change_and_normal_filter_should_be_and_relationship
    card = create_card!(:name => 'card')
    card.update_attribute :cp_status, 'open'
    card.update_attribute :cp_release, '2'
    card.update_attribute :cp_status, 'closed'
    card.update_attribute :cp_status, 'open'
    generate_card_changes_for(card)
    result = filtered_events(:involved_filter_properties => {'status' => 'closed'} ,:acquired_filter_properties => {'status' => 'open', 'release' => '(any change)'})
    assert_equal 0, result.size
  end
  
  def test_filters_any_change_should_act_as_and_relation
    card1 = create_card!(:name => 'card1', :status => 'new', :release => '1')
    card2 = create_card!(:name => 'card2', :status => 'new', :release => '1')
    card1.update_attributes :cp_status => 'open', :cp_release => '2'
    card2.update_attributes :cp_status => 'open'
    generate_card_changes_for(card1, card2)
    result = filtered_events(:involved_filter_properties => {'status' => 'new', 'release' => '1'}, :acquired_filter_properties => {'status' => '(any change)', 'release' => '(any change)'})
    assert_equal 1, result.uniq.size
  end

  #bug 8354
  def test_filters_any_change_in_acquired_filter_properties_with_card_type
    with_new_project do |project|
      type_story = project.card_types.create(:name => 'story')

      status = setup_property_definitions(:status => ['new', 'open']).first
      status.card_types = project.card_types
      status.save!

      card1 = create_card!(:name => 'card1', :status => 'new')
      card2 = create_card!(:name => 'card2', :status => 'new')
      card3 = create_card!(:name => 'card3', :status => 'new', :card_type => type_story)

      card1.update_attributes :cp_status => 'open'
      card3.update_attributes :cp_status => 'open'
      generate_card_changes_for(card1, card2, card3)

      result = filtered_events(:involved_filter_properties => {'type' => 'Card', 'status' => 'new'}, :acquired_filter_properties => {'type' => 'Card', 'status' => '(any change)'})
      assert_equal 1, result.uniq.size
    end
  end
  
  def test_should_not_throw_error_when_property_value_has_question_mark
    with_new_project do |project|
      setup_property_definitions(:status => ['changed?']).first
      begin
        filters = HistoryFilters.new(project, :involved_filter_properties => {'status' => 'changed?'})
        filters.fresh_events({})
      rescue
        fail("Parameters with question marks should not cause exceptions")
      end
    end
  end

  def test_events_do_not_include_those_for_deleted_cards
    with_new_project do |project|
      card = create_card!(:name => 'card1')
      card.destroy

      events = HistoryFilters.new(project, {}).events
      assert_equal 0, events.size
    end
  end

  def test_events_do_not_include_those_for_deleted_pages
    login_as_admin
    with_new_project do |project|
      filters = HistoryFilters.new(project, {})
      page = project.pages.create! :name => 'shortlived'
      assert_equal 1, filters.events.size
      page.destroy

      assert_equal 0, filters.events.size
    end
  end

end
