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

class HistoryFiltersMessagingTest < ActiveSupport::TestCase  
  include MessagingTestHelper
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end  
  
  def test_should_return_results_for_existing_tags_for_involved_tags_filter
    card =create_card!(:name => 'card1', :status => 'open')
    page = @project.pages.create!(:name => 'how do you like them pages?')
    page.tag_with("zebra")
    page.save!
    card.tag_with("apple")
    card.save!
    card.add_tag("zebra")
    card.save!
    HistoryGeneration.run_once
    assert_equal 2, filtered_events(:involved_filter_tags => ['apple']).size
    assert_equal 2, filtered_events(:involved_filter_tags => ["zebra"]).size
  end  

  def test_should_return_results_for_acquired_tags_for_acquired_tags_filter
    card =create_card!(:name => 'card1', :status => 'open')
    page = @project.pages.create!(:name => 'how do you like them pages?')
    page.tag_with("zebra")
    page.save!
    
    card.tag_with("apple")
    card.save!
    card.add_tag("zebra")
    card.save!
    HistoryGeneration.run_once
    assert_equal 1, filtered_events(:acquired_filter_tags => ['apple']).size
    assert_equal 2, filtered_events(:acquired_filter_tags => ["zebra"]).size
  end
  
  def test_should_return_events_created_or_modified_by_user_filter
    member = User.find_by_login 'member'
    admin = User.find_by_login 'admin'
    
    card =create_card!(:name => 'card1', :status => 'open', :priority => 'high')
    login_as_admin
    create_card!(:name => 'card2', :status => 'open', :priority => 'high')
    page = @project.pages.create(:name => 'foo', :content => 'rather queer')
    card.tag_with('giraffe').save!
    page.tag_with('giraffe').save!
    
    HistoryGeneration.run_once
    assert_equal 1, filtered_events(:involved_filter_properties => {'status' => 'open'}, :filter_user => member).size
    assert_equal 2, filtered_events(:involved_filter_properties => {'status' => 'open'}, :filter_user => admin).size
    assert_equal 2, filtered_events(:involved_filter_tags => ['giraffe'], :filter_user => admin).size
  end
  
  def test_should_return_results_in_descending_order_of_time
    preexisting_events = filtered_events
    card =create_card!(:name => 'card1', :status => 'open')
    page = @project.pages.create!(:name => 'how do you like them pages?')
    page.tag_with("zebra").save!
    
    card.tag_with("apple").save!
    card.add_tag("zebra")
    card.save!

    HistoryGeneration.run_once
    assert_equal 5, filtered_events.size - preexisting_events.size
    
    event_timings = filtered_events.collect{|row| row["updated_at"]}
    assert_equal event_timings, event_timings.sort.reverse
  end

  def test_should_filter_specific_types
    card =create_card!(:name => 'card1', :status => 'open')
    page = @project.pages.create!(:name => 'how do you like them pages?')
    page.tag_with("zebra").save!
    card.tag_with("apple").save!
    HistoryGeneration.run_once
    
    assert_equal 1, filtered_events(:involved_filter_tags => ['apple', 'zebra'], :filter_types => {'cards' => 'Card::Version'}).size
    assert_equal 1, filtered_events(:involved_filter_tags => ['apple', 'zebra'], :filter_types => {"pages" => 'Page::Version'}).size
    assert_equal 2, filtered_events(:involved_filter_tags => ['apple', 'zebra'], :filter_types => {'cards' => 'Card::Version', 'pages' => 'Page::Version'}).size
    assert_equal 2, filtered_events(:involved_filter_tags => ['apple', 'zebra']).size
  end
  
  def test_exisiting_or_involved_tags_honors_earliest_version_params
    card =create_card!(:name => 'card1', :status => 'open')
    page = @project.pages.create!(:name => 'how do you like them pages?')
    page.tag_with("zebra")
    page.save!
    card.add_tag("zebra")
    card.save!
    
    HistoryGeneration.run_once
    filters = HistoryFilters.new(@project, :involved_filter_tags => ["zebra"])
    events = filters.fresh_events(:card_version => card.reload.versions.first.id, 
      :page_version => page.reload.versions.last.id)   
    assert_equal 1, events.size
    assert_equal :card_version, events[0].event_type 
    
    events = filters.fresh_events(:card_version => card.reload.versions.last.id, 
      :page_version => page.reload.versions.first.id)   
    assert_equal 1, events.size
    assert_equal :page_version, events[0].event_type    
  end  
  
  def test_fresh_events_ordered_oldest_to_newest
    card =create_card!(:name => 'card1', :status => 'open')
    page = @project.pages.create!(:name => 'how do you like them pages?')
    card.update_attribute :name, 'a new name'
    
    set_modified_time(card, 1, 2007, 1, 1, 0, 0, 0)
    set_modified_time(page, 1, 2007, 1, 2, 0, 0, 0)
    set_modified_time(card, 2, 2007, 1, 3, 0, 0, 0)
    
    @project.generate_changes
    
    HistoryGeneration::run_once
    filters = HistoryFilters.new(@project, {})
    events = filters.fresh_events(:card_version => card.reload.versions.first.id - 1, 
      :page_version => page.reload.versions.first.id - 1)   
    assert_equal 3, events.size

    assert_equal [card.versions.first.id, :card_version], [events[0].id, events[0].event_type]
    assert_equal [page.versions.first.id, :page_version], [events[1].id, events[1].event_type]
    assert_equal [card.versions.last.id, :card_version], [events[2].id, events[2].event_type]
  end

  def test_filter_revisions_by_user
    does_not_work_without_subversion_bindings do
      member = User.find_by_login 'member'
      admin = User.find_by_login 'admin'
      member.update_attribute :version_control_user_name, 'bob'
      admin.update_attribute :version_control_user_name, 'joe'
      @project.add_member(admin)

      driver = with_cached_repository_driver(name) do |driver|
        driver.create
        driver.user = 'bob'
        driver.initialize_with_test_data_and_checkout
        sleep 1 # wait for some time before committing again
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "add #13"
        driver.user = 'joe'
        driver.add_file('new_file_2.txt', 'some content')
        driver.commit "add #157"
      end
    
      configure_subversion_for(@project, {:repository_path => driver.repos_dir})
      @project.cache_revisions
   
      HistoryGeneration.run_once
      bobs_work = HistoryFilters.new(@project, :filter_user => member, :filter_types => {'revisions' => 'Revision'})
      bobs_revisions = bobs_work.events
      assert_equal 2, bobs_revisions.size, "bob should have 2 revisions"
      assert_equal 2, bobs_revisions[0].number, "bob's latest event should be r2"
      assert_equal 1, bobs_revisions[1].number, "bob's first event should be r1"
    
      joes_work = HistoryFilters.new(@project, :filter_user => admin, :filter_types => {'revisions' => 'Revision'})
      joes_revisions = joes_work.events
      assert_equal 1, joes_revisions.size, "joe should have only 1 revision"
      assert_equal 3, joes_revisions[0].number, "joe's revision should be r3"
    end
  end
end
