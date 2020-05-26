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

class EventTest < ActiveSupport::TestCase
  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end

  def test_duplicate_version_event_is_not_allowed
    card = create_card!(:name => 'story')
    assert_raise(ActiveRecord::RecordInvalid) { card.versions.first.create_event }
  end

  def test_should_store_project_and_created_at
    card = create_card!(:name => 'story')
    version = card.versions.first
    version.reload
    assert_equal @project, version.event.project
    assert_equal version.updated_at, version.event.created_at
  end

  def test_details_are_still_loading_when_no_changes_and_event_updated_within_5_minutes
    ENV['EVENT_LOADING_TIME_THRESHOLD_MINUTES'] = '5'
    e = Event.new
    e.changes = []
    e.created_at = Clock.now - 4.minutes
    assert e.details_still_loading?
    e.created_at = Clock.now - 6.minutes
    assert !e.details_still_loading?
    e.created_at = Clock.now - 4.minutes
    e.changes = [Change.new]
    assert !e.details_still_loading?
  ensure
    ENV['EVENT_LOADING_TIME_THRESHOLD_MINUTES'] = nil
  end

  def test_changes_should_show_properties_in_correct_order
    with_new_project do |project|
      card_type = project.card_types.find_by_name('Card')
      UnitTestDataLoader.setup_property_definitions(
        :a => ['awesome', 'avuncular', 'animal-magnetism'],
        :j => ['jocular', 'joyful', 'just fine'],
        :y => ['youthful', 'yummy', 'yeah, baby']
      )
      a_property = project.find_property_definition('a')
      j_property = project.find_property_definition('j')
      y_property = project.find_property_definition('y')

      j_property.property_type_mappings.each { |j| j.position = 1; j.save! }
      a_property.property_type_mappings.each { |a| a.position = 2; a.save! }
      y_property.property_type_mappings.each { |y| y.position = 3; y.save! }

      card_type.reload

      event = Event.new
      event.changes << PropertyChange.new(:field => 'a', :old_value => 'awesome', :new_value => 'animal-magnetism')
      event.changes << PropertyChange.new(:field => 'j', :old_value => 'jocular', :new_value => 'just fine')
      event.changes << PropertyChange.new(:field => 'y', :old_value => 'youthful', :new_value => 'yummy')

      changes = event.changes_for_card_type(card_type)
      assert_equal 3, changes.size
      assert_equal ['j', 'a', 'y'], changes.collect(&:field)
    end
  end

  def test_bulk_generate_card_version_events_should_fix_losing_event
    card = create_card!(:name => 'story')
    card.update_attributes(:name => 'story1')
    Event.find_all_by_deliverable_id(@project.id).each(&:destroy)
    assert_nil card.reload.versions.last.event

    Event.bulk_generate(Card::Version, CardVersionEvent, @project)
    assert_not_nil card.versions.last.event
  end

  def test_bulk_generate_should_be_scoped_in_single_project
    another_project = with_new_project do |project|
      create_card!(:name => "eno")
      project.events.each(&:destroy)
      Event.bulk_generate(Card::Version, CardVersionEvent, project)
    end
    assert_equal 0,  @project.events.to_a.size
    assert_equal 1, another_project.events.to_a.size
  end


  def test_is_history_generated_flag_is_set_to_true_when_changes_are_generated
    card = create_card!(:name => 'my first card')
    first_version = card.versions.first.reload
    event = first_version.event
    assert_equal false, event.history_generated?
    event.send(:generate_changes)
    assert_equal true, event.history_generated?
  end

  def test_should_only_create_card_version_event_on_formula_change
    create_card!(:name => 'card 1', :startdate => 'Jan 1, 2010'.to_time)
    assert_equal 1, @project.reload.events.to_a.size

    day_after_start_date = @project.find_property_definition("day after start date")
    day_after_start_date.change_formula_to("startdate + 2")
    events = @project.reload.events

    assert_equal 2, events.to_a.size

    event = events[1]
    event.send(:generate_changes)

    assert_equal 'Card::Version', event.origin_type
    assert_equal 'CardVersionEvent', event.type
    assert_equal ['System generated comment', 'day after start date'], event.changes.collect(&:field).sort
  end

  def test_card_copy_should_generate_events
    destination = create_project(:name => "p2")
    with_new_project do |source|
      card_to_copy = create_card! :name => 'copy', :description => 'this is the description'
      assert_difference 'source.reload.events.to_a.size', 1 do
        assert_difference 'destination.reload.events.to_a.size', 2 do
          new_card = card_to_copy.copier(destination).copy_to_target_project
          assert_equal destination.id, new_card.project_id
          assert_equal 'copy', new_card.name
          assert_equal 'this is the description', new_card.description

          expected_details = {
            :source => { :number => card_to_copy.number, :project_id => source.identifier },
            :destination => { :number => new_card.number, :project_id => destination.identifier }
          }

          copied_to_event = source.events.find_by_type('CardCopyEvent::To')
          assert_equal card_to_copy, copied_to_event.origin
          assert_equal expected_details[:source], copied_to_event.source
          assert_equal expected_details[:destination], copied_to_event.destination

          destination.reload.with_active_project do
            copied_from_event = destination.events.find_by_type('CardCopyEvent::From')
            assert_equal new_card, copied_from_event.origin
            assert_equal expected_details[:source], copied_from_event.source
            assert_equal expected_details[:destination], copied_from_event.destination
          end
        end
      end
    end
  end

  def test_card_copy_twice_should_generate_two_events
    destination = create_project(:name => "p2")

    with_new_project do |source|
      card_to_copy = create_card! :name => 'copy', :description => 'this is the description'
      card_to_copy.copier(destination).copy_to_target_project
      card_to_copy.copier(destination).copy_to_target_project

      assert_equal 2, source.events.find_all_by_type('CardCopyEvent::To').size
    end
  end

  def test_card_version_event_should_contain_an_additional_field_if_origin_type_is_set
    Thread.current['origin_type'] = 'slack'
    card = create_card!(:name => 'my first card')
    card_version = card.versions.first.reload
    event = card_version.event
    
    assert_false event.details.nil?
    assert 'slack', event.details[:event_source]
  end

  def first_card
    @project.cards.first
  end

  def version(range_or_number)
    return first_card.find_version(range_or_number) if !(range_or_number.respond_to? :first)
    range_or_number.each do |version_number|
      yield first_card.find_version(version_number)
    end
  end
end
