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

class DependencyVersionEventTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @project = first_project
    @project2 = project_without_cards
    @project.activate
    @card = @project.cards.create(:name => 'foo', :card_type_name => 'card')
  end

  def test_should_get_events_for_raising_and_resolving_project
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project2.id, :name => "some dependency")
    dependency.save!
    dependency.update_attribute :name, 'new name'
    dep_version = dependency.versions.last

    @project.with_active_project do |project|
      assert dep_version.event
    end

    @project2.with_active_project do |project|
      assert dep_version.event
    end
  end

  def test_should_get_changes_for_name_description_and_desired_end_date_change_in_dependency
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project2.id, :name => "some dependency")
    dependency.save!
    dependency.update_attribute :name, 'new name'

    dep_version = dependency.versions.last
    dep_version.event.do_generate_changes
    assert_equal 1, dep_version.reload.changes.size
    assert dep_version.changes.first instance_of? NameChange

    dependency.update_attribute :description, 'new description'
    dep_version = dependency.versions.last
    dep_version.event.do_generate_changes
    assert_equal 1, dep_version.reload.changes.size
    assert dep_version.changes.first instance_of? DescriptionChange

    dependency.update_attribute :desired_end_date, '1-1-2016'
    dep_version = dependency.versions.last
    dep_version.event.do_generate_changes
    assert_equal 1, dep_version.reload.changes.size
    assert dep_version.changes.first instance_of? DependencyPropertyChange
  end

  def test_should_get_changes_for_status_change
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project2.id, :name => "some dependency")
    dependency.save!

    dependency.update_attribute :status, 'PLANNED'
    dep_version = dependency.versions.last
    dep_version.event.do_generate_changes
    assert_equal 1, dep_version.reload.changes.size
    assert dep_version.changes.first instance_of? DependencyPropertyChange
  end

  def test_should_create_dependency_events_when_a_resolving_card_is_linked
    project2 = project_without_cards
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => project2.id, :name => "some dependency")
    dependency.save!
    project2.with_active_project do |project|
      resolving_card1 = project.cards.create(:name => 'raising', :card_type_name => 'card')
      resolving_card2 = project.cards.create(:name => 'raising2', :card_type_name => 'card')
      dependency.link_resolving_cards([resolving_card1, resolving_card2])
    end

    assert_equal 2, dependency.versions.size
    dep_version = dependency.versions.last
    assert_equal 2, dep_version.events.size

    dep_version.event.do_generate_changes
    assert_equal 2, dep_version.event.reload.changes.size
    assert dep_version.event.changes.first.is_a?(DependencyCardLinkChange), "should record card link change"
    assert dep_version.event.changes.last.is_a?(DependencyPropertyChange), "should record dependency status change"
  end

  def test_should_create_dependency_events_when_a_resolving_card_is_unlinked
    resolving_project = project_without_cards
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => resolving_project.id, :name => "some dependency")
    dependency.save!
    resolving_project.activate
    resolving_card1 = resolving_project.cards.create(:name => 'raising', :card_type_name => 'card')
    resolving_card2 = resolving_project.cards.create(:name => 'raising2', :card_type_name => 'card')
    dependency.link_resolving_cards([resolving_card1])
    dependency.link_resolving_cards([resolving_card2])
    dependency.unlink_resolving_card_by_number(resolving_card2.number)

    assert_equal 4, dependency.versions.size
    dep_version = dependency.versions.last
    assert_equal 2, dep_version.events.size
    dep_version.event.do_generate_changes
    assert_equal 1, dep_version.event.reload.changes.size
    assert dep_version.event.changes.first.is_a? DependencyCardLinkChange

    dependency.unlink_resolving_card_by_number(resolving_card1.number)
    assert_equal 5, dependency.versions.size
    dep_version = dependency.versions.last
    assert_equal 2, dep_version.events.size
    dep_version.event.do_generate_changes
    assert_equal 2, dep_version.event.reload.changes.size
    assert dep_version.event.changes.first.is_a? DependencyCardLinkChange
    assert dep_version.event.changes.last.is_a? DependencyPropertyChange
  end

  def test_deleting_resolving_card_should_create_an_unlink_event_on_the_dependency
    project2 = project_without_cards
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => project2.id, :name => "some dependency")
    dependency.save!
    project2.with_active_project do |project|
      resolving_card1 = project.cards.create(:name => 'raising', :card_type_name => 'card')
      resolving_card2 = project.cards.create(:name => 'raising2', :card_type_name => 'card')
      dependency.link_resolving_cards([resolving_card1, resolving_card2])
      resolving_card2.destroy
    end

    dep_version = dependency.reload.versions.last
    dep_version.event.do_generate_changes
    assert_equal 1, dependency.reload.resolving_cards.length
    assert_equal 1, dep_version.event.reload.changes.size
    assert dep_version.event.changes.first.is_a? DependencyCardLinkChange
    assert_equal 'Unlinked cards', dep_version.event.reload.changes[0].field
  end

  def test_should_see_resolving_project_change_and_raising_card_change_on_creation
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project2.id, :name => "some dependency")
    dependency.save!
    dep_version = dependency.reload.versions.last
    dep_version.event.do_generate_changes
    changes = dep_version.event.reload.changes.select(&:descriptive?)
    assert_equal 2, changes.size
    assert changes.first.is_a? DependencyResolvingProjectChange
    assert changes.last.is_a? DependencyRaisingCardChange
    assert_equal "Resolving project set to #{@project2.name}", changes[0].describe
  end

  def test_changing_resolving_project
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project2.id, :name => "some dependency")
    dependency.save!
    dependency.resolving_project_id = @project.id
    dependency.save

    dep_version = dependency.reload.versions.last
    dep_version.event.do_generate_changes
    assert_equal 1, dep_version.event.reload.changes.size
    assert dep_version.event.changes.first.is_a? DependencyResolvingProjectChange
    assert_equal "Resolving project changed from #{@project2.name} to #{@project.name}", dep_version.event.reload.changes[0].describe
  end

  def test_should_get_linked_and_unlinked_cards
    card1 = @project.cards.create(:name => 'one', :card_type_name => 'card')
    card2 = @project.cards.create(:name => 'two', :card_type_name => 'card')
    card3 = @project.cards.create(:name => 'two', :card_type_name => 'card')
    card4 = @project.cards.create(:name => 'two', :card_type_name => 'card')
    card5 = @project.cards.create(:name => 'two', :card_type_name => 'card')
    version_event = DependencyVersionEvent.new
    linked_cards = version_event.cards_linked([card1, card2], [card1, card2, card3, card4])
    assert_equal 2, linked_cards.size
    assert linked_cards.include? card3
    assert linked_cards.include? card4

    unlinked_cards = version_event.cards_unlinked([card3, card4, card5], [card1, card2])
    assert_equal 3, unlinked_cards.size
    assert unlinked_cards.include? card3
    assert unlinked_cards.include? card4
    assert unlinked_cards.include? card5
  end

end
