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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

class HistoryMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
  def setup
    @project = project_without_cards
    @project.activate
    SubversionConfiguration.create!(:project => @project, :repository_path => "/") #project must have a repos configured to locate revision events in history
    login_as_member
  end
  
  def teardown
    Clock.reset_fake
    
    SubversionConfiguration.find(:all, :conditions => ['project_id=?', @project.id]).each do |sc|
      sc.destroy
    end
  end
  
  def test_get_revision_events_in_range_boundary_conditions
    create_new_revison('23', 23, 2004, 10, 7, 10, 10, 9)
    create_new_revison('24', 24, 2004, 10, 7, 10, 10, 10)
    create_new_revison('25', 25, 2004, 10, 7, 10, 10, 11)
    create_new_revison('26', 26, 2004, 10, 7, 10, 10, 29)
    create_new_revison('27', 27, 2004, 10, 7, 10, 10, 30)
    create_new_revison('28', 28, 2004, 10, 7, 10, 10, 31)
    HistoryGeneration.run_once
    
    start_time = Time.utc(2004, 10, 7, 10, 10, 10)
    end_time = Time.utc(2004, 10, 7, 10, 10, 30) - 1.second
    history = History.for_period(@project, :period => CustomDateTimeRange.new(start_time, end_time))

    versions = history.events
    assert_equal 3, versions.size
    assert_equal 26, versions[0].number
    assert_equal 25, versions[1].number
    assert_equal 24, versions[2].number   
  end
  
  def test_get_mixed_events_in_range_boundary_conditions 
    create_new_revison('23', 23, 2004, 10, 7, 11, 10, 11)
    create_new_revison('24', 24, 2004, 10, 7, 11, 10, 21)
      
    card1 = create_card!(:name => 'card 1')
    set_modified_time(card1, 1, 2004, 10, 7, 11, 10, 9)
    create_next_version_at(card1, 2004, 10, 7, 11, 10, 10)
    create_next_version_at(card1, 2004, 10, 7, 11, 10, 30)
    HistoryGeneration.run_once
      
    start_time = Time.utc(2004, 10, 7, 11, 10, 10)
    end_time = Time.utc(2004, 10, 7, 11, 10, 20)
    history = History.for_period(@project, :period => CustomDateTimeRange.new(start_time, end_time))
    result = history.events
    assert_equal 2, result.size

    assert_equal :revision, result[0].event_type
    assert_equal 23, result[0].number    
    assert_equal :card_version, result[1].event_type
    assert_equal card1.id, result[1].card_id
    assert_equal 2, result[1].version
  end

  def test_find_history_by_card
    card1 = create_card!(:name => 'card 1')
    set_modified_time(card1, 1, 2004, 10, 7, 11, 10, 9)
    create_next_version_at(card1, 2004, 10, 8, 11, 10, 10)
    card2 =create_card!(:name => 'card 2')
    set_modified_time(card2, 1, 2004, 10, 7, 10, 10, 9)  

    revision1 = create_new_revison('23', 23, 2004, 10, 7, 11, 10, 11)
    CardRevisionLink.create!(:project_id => @project.id, :card_id => card1.id, :revision_id => revision1.id)
    revision2 = create_new_revison('24', 24, 2004, 10, 9, 11, 10, 21)
    CardRevisionLink.create!(:project_id => @project.id, :card_id => card1.id, :revision_id => revision2.id)
    HistoryGeneration.run_once
    
    history = History.for_versioned(@project, card1)
    result = history.events
    assert_equal 4, result.size
    
    revision_09 = result[0]
    assert_equal :revision, revision_09.event_type
    assert_equal 24, revision_09.number
    
    card_version_08 = result[1]
    assert_equal :card_version, card_version_08.event_type
    assert_equal 2, card_version_08.version
    assert_equal card1.id, card_version_08.card_id
            
    revision_07 = result[2]
    assert_equal :revision, revision_07.event_type
    assert_equal 23, revision_07.number
    
    card_version_08 = result[3]
    assert_equal :card_version, card_version_08.event_type
    assert_equal card1.id, card_version_08.card_id
    assert_equal 1, card_version_08.version    
  end

  def test_get_last_events_should_be_really_last
    card1 = create_card!(:name => 'card 1')
    set_modified_time(card1, 1, 2004, 10, 7, 10, 10, 9)
    page1 = @project.pages.create(:identifier => 'page 1')
    set_modified_time(page1, 1, 2004, 10, 7, 10, 10, 19)
    card2 =create_card!(:name => 'card 2')
    set_modified_time(card2, 1, 2004, 10, 7, 10, 10, 29)
    start_time = Time.utc(2004, 10, 7, 10, 10, 0)
    end_time = Time.utc(2004, 10, 7, 10, 10, 30)
    HistoryGeneration.run_once

    history = History.for_period(@project, :period => CustomDateTimeRange.new(start_time, end_time))
    assert_equal [card2.versions.last, page1.versions.last, card1.versions.last], history.last(3)
    assert_equal [card2.versions.last, page1.versions.last], history.last(2)
  end
  
  
  def test_should_show_changes_even_if_current_filter_tags_are_not_among_those_affected_by_current_change
    card1 = create_card!(:name => 'card 1')
    set_modified_time(card1, 1, 2004, 10, 7, 11, 10, 9)
    create_next_version_at(card1, 2004, 10, 8, 11, 10, 10)
    card2 = create_card!(:name => 'card 2')
    set_modified_time(card2, 1, 2004, 10, 7, 10, 10, 9)  
  end  
  
  def test_last_update_time_should_be_the_last_event_happened_time
    create_new_revison('23', 23, 2004, 10, 7, 11, 10, 11)
    create_new_revison('24', 24, 2004, 10, 7, 11, 10, 21)
    create_new_revison('25', 25, 2004, 10, 7, 12, 10, 21)
    start_time = Time.utc(2004, 10, 7, 10, 10, 10)
    end_time = Time.utc(2004, 11, 7, 10, 10, 30)
    HistoryGeneration.run_once
    history = History.for_period(@project, :period => CustomDateTimeRange.new(start_time, end_time))
    assert_equal Time.utc(2004, 10, 7, 12, 10, 21).utc.to_s(:atom_time), history.last_update_time
  end

  
  
  def test_page_history_filtering_by_tags
    page = @project.pages.create(:name => 'dumb name', :content => 'test page') #1
    page.add_tag('luke') #2
    page.save!
    page.add_tag('history') #3
    page.save!

    HistoryGeneration.run_once
    history = History.for_period(@project, 
        :period => :today, 
        :involved_filter_tags => ['luke']
    )
    assert_does_not_show_versions(history, 1)
    assert_shows_version(history, 2, 3)
    
    history = History.for_period(@project, 
        :period => :today, 
        :involved_filter_tags => ['luke'],
        :acquired_filter_tags => ['history']
    )
    assert_does_not_show_versions(history, 1, 2)
    assert_shows_version(history, 3)
  end  
  
  
  
  def test_version_control_username_update_triggers_revision_history_update_across_projects
    does_not_work_without_subversion_bindings do
      bob = create_user!
      bob.update_attribute :version_control_user_name, 'bob'
      project_1 = create_project
      project_2 = create_project
      project_1.add_member(bob)
      project_2.add_member(bob)
      @driver = with_cached_repository_driver(name + 'test_version_control_username_update') do |driver|
        driver.user = 'bob'
        driver.initialize_with_test_data_and_checkout
      end   
    
      first_proj_rev_event =  nil
      project_1.with_active_project do |proj|
        configure_subversion_for(proj, {:repository_path => @driver.repos_dir})
        User.with_first_admin { proj.cache_revisions }
        first_proj_rev_event = RevisionEvent.find(:first)
      end
      project_2.with_active_project do |proj|
        configure_subversion_for(proj, {:repository_path => @driver.repos_dir})
        User.with_first_admin { proj.cache_revisions }
      end

      HistoryGeneration.run_once

      assert_equal 1, History.for_period(project_1, :period => :all_history, :filter_user => bob.id.to_s, 
        :filter_types => {'revisions' => 'Revision'}).events.size
      assert_equal 1, History.for_period(project_2, :period => :all_history, :filter_user => bob.id.to_s, 
        :filter_types => {'revisions' => 'Revision'}).events.size
      
      bob.reload.update_attribute :version_control_user_name, 'dave'    
      HistoryGeneration.run_once
      
      assert_equal 0, History.for_period(project_1, :period => :all_history, 
        :filter_user => bob.id.to_s, :filter_types => {'revisions' => 'Revision'}).events.size
      assert_equal 0, History.for_period(project_2, :period => :all_history, 
        :filter_user => bob.id.to_s, :filter_types => {'revisions' => 'Revision'}).events.size 
    
      bob.reload.update_attribute :version_control_user_name, 'bob'    
      HistoryGeneration.run_once
      
      assert_equal 1, History.for_period(project_1, :period => :all_history, 
        :filter_user => bob.id.to_s, :filter_types => {'revisions' => 'Revision'}).events.size
      assert_equal 1, History.for_period(project_2, :period => :all_history, 
        :filter_user => bob.id.to_s, :filter_types => {'revisions' => 'Revision'}).events.size      
    end
  end

  # make test run at end because the DDL from creating a new project will cause the subversion configuration created in the setup to linger
  def test_z_for_versioned_returns_eager_loaded_changes_correctly_for_projects_with_numbered_name
    # Eager loading can be done in Rails one of two ways: in a big LEFT OUTER JOIN sql, or in multiple separate small sqls.
    # When tablename contains numbers, the #table_in_strings method in associations.rb helps determine which method to eager load.
    # In Rails 2.3 upgrade, the regex changed, and resulted in acts_as_versioned_ext.rb #versions_with_eager_loads_for_history_performance
    # not eager loading changes properly.  This is a bug in Rails 2.3.
    
    with_new_project :name => 'with_123_number' do |project|
      setup_property_definitions :status => ['open', 'closed'], :iteration => ['1', '2']
      card = project.cards.create!(:name => 'some card with several changes', :card_type_name => 'Card', :cp_status => 'open', :cp_iteration => '1')
      HistoryGeneration.run_once
      assert_equal 4, History.for_versioned(project, card).events.map(&:changes).flatten.size
    end
  end
  
  # make test run at end because the DDL from creating a new project will cause the subversion configuration created in the setup to linger
  def test_z_should_not_modify_history_events_or_saved_views_or_transitions_or_history_subscriptions_for_invalid_enum_value_renames_which_would_get_rolled_back
    with_new_project do |project|
      project.add_member(User.current)
      estimate = setup_numeric_property_definition('estimate', ['1'])
      card = project.cards.create!(:name => 'Card 1', :card_type_name => project.card_types.first.name, :cp_estimate => '1')
      view = project.card_list_views.find_or_construct(project, :filters => ['[estimate][is][1]'], :name => 'estimate is one')
      view.save!
      set_it_to_one = create_transition(project, 'set it to one', :required_properties => {:estimate => '1'}, :set_properties => {:estimate => '1'}, :card_type => project.card_types.first)
      estimate_set_to_one_history_subscription = project.create_history_subscription(project.users.first, 'acquired_filter_properties[estimate]=1')
      old_change_descriptions = card.versions.last.describe_changes

      estimate_of_one = estimate.enumeration_values.first
      estimate_of_one.project.reload
      estimate_of_one.value = 'foo'
      estimate_of_one.save

      assert_equal 'Value f53077d10b01a01b118cb519d7a796f67de67d43foo4321b981f34c6cb8e6a74784c908646c083327e9 is an invalid numeric value', estimate_of_one.errors.full_messages.join

      card = project.cards.find_by_number(card.number)
      assert_equal 1, card.versions.reload.size
      new_change_descriptions = card.versions.last.describe_changes
      assert_equal old_change_descriptions, new_change_descriptions

      view = project.card_list_views.find_by_name('estimate is one')
      assert_equal ['[estimate][is][1]'], view.filters.to_params

      assert_equal '1', set_it_to_one.prerequisites.reload.first.value
      assert_equal '1', set_it_to_one.actions.reload.first.value

      assert_equal({"acquired_filter_properties"=>{"estimate"=>"1"}}, estimate_set_to_one_history_subscription.reload.to_history_filter_params.to_hash)
    end
  end
  
  
  private
    
  def create_new_revison(identifier, rev_number, year, month, day, hour, minute, second)
    Revision.create(:number => rev_number, 
                   :identifier => identifier,
                   :commit_message => '',
                   :commit_user => '',
                   :commit_time => Time.utc(year, month, day, hour, minute, second).utc,
                   :project_id => @project.id)
  end

  def create_next_page_version_at(versioned, year, month, day, hour, minute, second)
    versioned.update_attribute(:content, versioned.name.next)
    versioned.reload
    set_modified_time(versioned, versioned.versions.size, year, month, day, hour, minute, second)
  end
  
end
