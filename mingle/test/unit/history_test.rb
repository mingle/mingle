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
require 'ostruct'

class HistoryTest < ActiveSupport::TestCase

  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end

  def teardown
    Clock.reset_fake
  end

  def test_today_should_be_last_24_hours
    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
    today = Today.new
    assert_equal [Time.utc(2005, 10, 8, 8, 7, 6), Time.utc(2005, 10, 9, 8, 7, 6)], today.boundaries
  end

  def test_yesterday_should_be_last_24_to_48_hours
    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
    yesterday = Yesterday.new
    assert_equal [Time.utc(2005, 10, 7, 8, 7, 6), Time.utc(2005, 10, 8, 8, 7, 6)], yesterday.boundaries
  end

  def test_last_7_days_should_be_last_168_hours
    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
    assert_equal [Time.utc(2005, 10, 2, 8, 7, 6), Time.utc(2005, 10, 9, 8, 7, 6)], Last7Days.new.boundaries
    Clock.fake_now(:year => 2005, :month => 10, :day => 5, :hour => 8, :min => 7, :sec => 6)
    assert_equal [Time.utc(2005, 9, 28, 8, 7, 6), Time.utc(2005, 10, 5, 8, 7, 6)], Last7Days.new.boundaries
  end

  def test_last_30_days_should_be_last_720_hours
    Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
    assert_equal [Time.utc(2005, 9, 9, 8, 7, 6), Time.utc(2005, 10, 9, 8, 7, 6)], Last30Days.new.boundaries
    Clock.fake_now(:year => 2005, :month => 9, :day => 9, :hour => 8, :min => 7, :sec => 6)
    assert_equal [Time.utc(2005, 8, 10, 8, 7, 6), Time.utc(2005, 9, 9, 8, 7, 6)], Last30Days.new.boundaries
  end

  def test_changes_are_not_identified_on_the_basis_of_text_comparison
    card1 =create_card!(:name => 'card 1')
    card1.cp_iteration = '1'
    card1.save!
    card2 =create_card!(:name => 'card 2')
    card2.cp_iteration = '12'
    card2.save!
    generate_card_changes_for(card1, card2)

    history = History.for_period(@project, :period => :today, :involved_filter_properties => {'iteration' => '1', 'priority' => nil})
    assert_equal 1, history.events.size
    history = History.for_period(@project, :period => :today, :involved_filter_properties => {'iteration' => '12', 'priority' => ''})
    assert_equal 1, history.events.size
  end

  def test_filter_events_by_values
    card1 = @project.cards.new(:name => 'card 1', :project => @project)
    card1.cp_feature = 'email'
    card1.cp_status = 'open'
    card1.card_type = @project.card_types.first
    card1.save!
    set_modified_time(card1, 1, 2004, 10, 4, 10, 0, 0)
    create_next_version_at(card1, 2004, 10, 6, 5, 0, 0)
    create_next_version_at(card1, 2004, 10, 6, 8, 0, 0)
    create_next_version_at(card1, 2004, 10, 7, 5, 0, 0)

    card2 = @project.cards.new(:name => 'card 2', :project => @project)
    card2.cp_feature = 'email'
    card2.cp_status = 'closed'
    card2.card_type = @project.card_types.first
    card2.save!
    set_modified_time(card2, 1, 2004, 10, 7, 9, 0, 0)
    generate_card_changes_for(card1, card2)

    history = History.for_period(@project,
      :period => CustomDateTimeRange.new(Time.utc(2004, 10, 2, 0, 0, 0), Time.utc(2004, 10, 10, 0, 0, 0)),
      :involved_filter_properties => {'status' => 'closed'})

    assert_equal 1, history.events.size
    assert_equal card2.id, history.events[0].card_id
  end

  def test_filter_events_by_tags_should_include_tags_that_do_not_change_between_versions
    card1 = @project.cards.new(:name => 'card 1', :project => @project)
    card1.cp_feature = 'email'
    card1.cp_status = 'open'
    card1.cp_old_type = 'story'
    card1.card_type = @project.card_types.first
    card1.save!
    set_modified_time(card1, 1, 2004, 10, 4, 10, 0, 0)
    card1.cp_status = 'closed'
    card1.save!
    set_modified_time(card1, 2, 2004, 10, 4, 11, 0, 0)
    generate_card_changes_for(card1)
    history = History.for_period(@project,
      :period => CustomDateTimeRange.new(Time.utc(2004, 10, 4, 0, 0, 0), Time.utc(2004, 10, 8, 0, 0, 0)),
      :involved_filter_properties => {'old_type' => 'story'})
    assert_equal 2, history.events.size
  end

  def test_filter_events_by_acquired_properties
    bug1 = @project.cards.new(:name => 'bug 1', :project => @project, :card_type => @project.card_types.first)
    bug1.update_attributes :cp_old_type => 'bug', :cp_release => '1'
    set_modified_time(bug1, 1, 2004, 10, 4, 10, 0, 0)

    bug1.update_attribute :cp_status, 'open'
    set_modified_time(bug1, 2, 2004, 10, 6, 11, 0, 0)

    bug1.update_attribute :cp_priority, 'high'
    set_modified_time(bug1, 3, 2004, 10, 7, 12, 0, 0)

    bug2 = @project.cards.new(:name => 'bug 2', :project => @project, :card_type => @project.card_types.first)
    bug2.update_attributes :cp_old_type => 'bug', :cp_release => '1'
    set_modified_time(bug2, 1, 2004, 10, 4, 10, 0, 0)
    generate_card_changes_for(bug1, bug2)

    history_of_release_1_bugs = History.for_period(@project,
      :period => CustomDateTimeRange.new(Time.utc(2004, 10, 3, 0, 0, 0), Time.utc(2004, 10, 8, 0, 0, 0)),
      :involved_filter_properties => {'release' => '1', 'old_type' => 'bug'})
    assert_equal 4, history_of_release_1_bugs.events.size

    history_of_newly_opened_bugs_in_release_1 = History.for_period(@project,
      :period => CustomDateTimeRange.new(Time.utc(2004, 10, 3, 0, 0, 0), Time.utc(2004, 10, 8, 0, 0, 0)),
      :involved_filter_properties => {'release' => '1', 'old_type' => 'bug'},
      :acquired_filter_properties => {'status' => 'open', 'release' => PropertyValue::IGNORED_IDENTIFIER, 'old_type' => PropertyValue::IGNORED_IDENTIFIER})
    assert_equal 1, history_of_newly_opened_bugs_in_release_1.events.size

    history_of_newly_opened_high_bugs_in_release_1 = History.for_period(@project,
      :period => CustomDateTimeRange.new(Time.utc(2004, 10, 3, 0, 0, 0), Time.utc(2004, 10, 8, 0, 0, 0)),
      :involved_filter_properties => {'release' => '1','old_type' => 'bug'},
      :acquired_filter_properties => {'status' => 'open', 'priority' => 'high'})
    assert_equal 1, history_of_newly_opened_high_bugs_in_release_1.events.size
  end

  def test_get_card_version_events_in_range_boundary_conditions
    card1 =create_card!(:name => 'card 1')
    set_modified_time(card1, 1, 2004, 10, 7, 10, 10, 9)
    create_next_version_at(card1, 2004, 10, 7, 10, 10, 10)
    create_next_version_at(card1, 2004, 10, 7, 10, 10, 11)
    create_next_version_at(card1, 2004, 10, 7, 10, 30, 29)
    create_next_version_at(card1, 2004, 10, 7, 10, 30, 30)
    create_next_version_at(card1, 2004, 10, 7, 10, 30, 31)
    generate_card_changes_for(card1)

    start_time = Time.utc(2004, 10, 7, 10, 10, 10)
    end_time = Time.utc(2004, 10, 7, 10, 30, 30) - 1.second
    history = History.for_period(@project, :period => CustomDateTimeRange.new(start_time, end_time))

    versions = history.events
    assert_equal 3, versions.size
    assert_equal 4, versions[0].version
    assert_equal 3, versions[1].version
    assert_equal 2, versions[2].version
  end

  def test_add_new_comment_should_generate_new_event
     card1 =create_card!(:name => 'card 1', :number => 42)
     card1.add_comment :content =>  'blah blah'
     set_modified_time(card1, 1, 2004, 10, 7, 10, 10, 9)
     set_modified_time(card1, 2, 2004, 10, 7, 10, 10, 9)
     generate_card_changes_for(card1)

     history = History.for_versioned(@project, card1)
     assert_equal 2, history.events.size
     assert history.events.collect(&:comment).include?('blah blah')
  end

  def test_add_new_comment_should_generate_new_event
     card1 =create_card!(:name => 'card 1', :number => 42)
     card1.add_comment :content => 'blah blah'
     set_modified_time(card1, 1, 2004, 10, 7, 10, 10, 9)
     set_modified_time(card1, 2, 2004, 10, 7, 10, 10, 9)
     generate_card_changes_for(card1)

     history = History.for_versioned(@project, card1)
     assert_equal 2, history.events.size
     assert history.events.collect(&:comment).include?('blah blah')
  end

  def test_create_new_dependency_should_generate_new_event
    raising_card = create_card!(:name => 'raising', :number => 42)
    raising_card.raise_dependency(
      :desired_end_date => "8-11-2014",
      :resolving_project_id => @project.id,
      :name => "new dependency"
    ).save!
    filter = HistoryFilterParams.new({}, :today).generate_history_filter(@project)
    history = History.new(@project, filter, {})
    assert_equal 2, history.events.size
    dep_version = history.events.select {|event| event.instance_of? Dependency::Version}
    assert_equal 1, dep_version.size
    assert_equal 1, dep_version.first.events.size
  end

  def test_all_history_period_should_pull_out_all_events
    card1 =create_card!(:name => 'card 1')
    set_modified_time(card1, 1, 2004, 10, 7, 10, 10, 9)
    page1 = @project.pages.create(:identifier => 'page 1')
    set_modified_time(page1, 1, 2004, 10, 7, 10, 10, 19)
    card2 =create_card!(:name => 'card 2')
    set_modified_time(card2, 1, 2005, 10, 7, 10, 10, 29)
    generate_card_changes_for(card1, card2)
    history = History.for_period(@project, :period => :all_history)
    assert_equal [card2.versions.last, page1.versions.last, card1.versions.last], history.last(3)
  end

  def test_bug_1048
    card =create_card!(:name => 'smart name')
    card.update_attributes(:cp_release => '2')
    card.update_attributes(:cp_priority => 'high')
    card.update_attributes(:cp_priority => 'low')
    generate_card_changes_for(card)

    history = History.for_period(@project,
        :period => :today,
        :acquired_filter_properties => {'release' => '2'}
    )
    assert_shows_version(history, 2)
    assert_does_not_show_versions(history, 1, 3, 4)
    history = History.for_period(@project,
        :period => :today,
        :involved_filter_properties => {'priority' => 'low'},
        :acquired_filter_properties => {'release' => '2'}
    )
    assert_does_not_show_versions(history, 1, 2, 3, 4)
  end

  def test_filtering_acquisition_by_tag
    card =create_card!(:name => 'smart name') #1
    card.update_attribute(:cp_old_type, 'story') #2
    card.add_tag('luke') #3
    card.save!
    card.add_tag('history') #4
    card.save!
    generate_card_changes_for(card)
    history = History.for_period(@project,
        :period => :today,
        :involved_filter_properties => {'old_type' => 'story'}
    )
    assert_shows_version(history, 2, 3, 4)

    history = History.for_period(@project,
        :period => :today,
        :involved_filter_properties => {'old_type' => 'story'},
        :acquired_filter_tags => ['luke']
    )
    assert_does_not_show_versions(history, 1, 2, 4)
    assert_shows_version(history, 3)

    history = History.for_period(@project,
        :period => :today,
        :involved_filter_properties => {'old_type' => 'story'},
        :acquired_filter_tags => ['luke','history']
    )
    assert_does_not_show_versions(history, 1, 2, 3, 4)
  end

  def test_filtering_by_junk_tag_should_remove_all_events
    card =create_card!(:name => 'smart name') #1
    card.update_attribute(:cp_old_type, 'story') #2
    card.add_tag('luke') #3
    card.save!
    card.add_tag('history') #4
    card.save!

    history = History.for_period(@project,
        :period => :today,
        :involved_filter_tags => ['non existing tag']
    )
    assert_does_not_show_versions(history, 1, 2, 3, 4)

    history = History.for_period(@project,
        :period => :today,
        :involved_filter_properties => {'old_type' => 'story'},
        :acquired_filter_tags => ['junk']
    )
    assert_does_not_show_versions(history, 1, 2, 3, 4)
  end

  def test_filtering_by_user_selects_both_creation_and_modification_events
    Clock.now_is(:year => 2011, :month => 1, :day => 10, :hour => 9) do
      set_current_user(User.find_by_login("admin")) do
        @card1 =create_card!(:name => 'card 1') #1
        @card1.reload.update_attribute(:name, 'sother nmae for #2') #2
      end
      set_current_user(User.find_by_login("bob")) do
        @card1.reload.update_attribute(:name, 'other name for #3') #3
      end
      generate_card_changes_for(@card1)
      assert_equal 2, History.for_period(@project, :period => CustomDateTimeRange.new(Clock.now - 2.days, Clock.now + 1.day), :filter_user => User.find_by_login("admin").id).size
      assert_equal 1, History.for_period(@project, :period => CustomDateTimeRange.new(Clock.now - 2.days, Clock.now + 1.day), :filter_user => User.find_by_login("bob").id).size
    end
  end

  def test_can_page_through_history
    card =create_card!(:name => 'smart name') #1
    card.update_attributes(:cp_priority => 'high') #2
    card.update_attributes(:cp_status => 'open') #3

    set_modified_time(card, 1, 2004, 10, 7, 10, 10, 8)
    set_modified_time(card, 2, 2004, 10, 7, 10, 10, 9)
    set_modified_time(card, 3, 2004, 10, 7, 10, 10, 10)
    generate_card_changes_for(card)

    history = History.for_period(@project, {:period => :all_history}, {:page => 1, :page_size => 1})
    assert_equal 1, history.events.size
    history = History.for_period(@project, {:period => :all_history}, {:page => 2, :page_size => 1})
    assert_equal 1, history.events.size
    history = History.for_period(@project, {:period => :all_history}, {:page => 3, :page_size => 1})
    assert_equal 1, history.events.size
  end

  def test_filter_history_by_acquired_card_property_definition
    with_card_prop_def_test_project_and_card_type_and_pd do |project, story_type, iteration_type, iteration_propdef|
      iteration1 = project.cards.create!(:name => 'iteration1', :card_type => iteration_type)

      story1 = project.cards.create!(:name => 'story1', :card_type => story_type, :cp_iteration => iteration1) #1
      story1.update_attributes(:cp_priority => 'high') #2
      story1.update_attributes(:cp_iteration => nil) #3
      generate_card_changes_for(iteration1, story1)

      assert_equal 1, filtered_events(project, :acquired_filter_properties => {'iteration' => iteration1.id.to_s}).size
      assert_equal 1, filtered_events(project, :acquired_filter_properties => {'iteration' => nil}).size
    end
  end

  def test_filter_history_by_involved_card_property_definition
    with_card_prop_def_test_project_and_card_type_and_pd do |project, story_type, iteration_type, iteration_propdef|
      iteration1 = project.cards.create!(:name => 'iteration1', :card_type => iteration_type)
      story1 = project.cards.create!(:name => 'story1', :card_type => story_type, :cp_iteration => iteration1) #1
      story1.update_attributes(:name => 'story 1') #2
      story1.update_attributes(:cp_iteration => nil) #not included
      generate_card_changes_for(iteration1, story1)
      assert_equal 2, filtered_events(project, :involved_filter_properties => {'iteration' => iteration1.id.to_s}).size
    end
  end

  def test_should_be_able_to_filter_history_for_stories_moved_between_iterations_using_card_property_definition
    with_card_prop_def_test_project_and_card_type_and_pd do |project, story_type, iteration_type, iteration_propdef|
      iteration1 = project.cards.create!(:name => 'iteration1', :card_type => iteration_type)
      iteration2 = project.cards.create!(:name => 'iteration2', :card_type => iteration_type)
      story1 = project.cards.create!(:name => 'story1', :card_type => story_type, :cp_iteration => iteration1)
      story1.update_attributes(:cp_iteration => iteration2)

      generate_card_changes_for(iteration1, iteration2, story1)
      only_result, *others = filtered_events(project,
        :period => :all_history,
        :involved_filter_properties => {:iteration => iteration1.id.to_s},
        :acquired_filter_properties => {:iteration => iteration2.id.to_s}
      )
      assert others.empty?

      assert_equal story1.reload.versions[1].id, only_result["version_id"].to_i
    end
  end

  private
  def filtered_events(project, filters={})
    sql = HistoryFilters.new(project, filters).to_sql
    ActiveRecord::Base.connection.select_all(sql)
  end

end
