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
require File.expand_path(File.dirname(__FILE__) + '/./user_access_test_helper')

class DependencyTest < ActiveSupport::TestCase
  include UserAccessTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
    @card = @project.cards.first
  end

  def test_comparator
    dep1, dep2, dep3, dep4 = nil, nil, nil, nil
    project_2 = nil

    with_new_project do |project|
      project.update_attribute(:name, "b")
      project_2 = project
    end

    with_new_project do |project|
      project.update_attribute(:name, "a")
      card = project.cards.create!(:name => "first a", :card_type_name => "card")
      dep1 = card.raise_dependency(:number => 1, :desired_end_date => Date.parse("2014-09-11"), :resolving_project_id => project.id, :name => "dep1")
      dep1.save!
      dep2 = card.raise_dependency(:number => 2, :desired_end_date => Date.parse("2014-08-11"), :resolving_project_id => project_2.id, :name => "dep2")
      dep2.save!
      dep3 = card.raise_dependency(:number => 3, :desired_end_date => Date.parse("2014-10-11"), :resolving_project_id => project.id, :name => "dep3")
      dep3.save!
      dep4 = card.raise_dependency(:number => 4, :desired_end_date => Date.parse("2014-11-11"), :resolving_project_id => project_2.id, :name => "dep4")
      dep4.save!
    end

    initial = [dep1, dep2, dep3, dep4]
    assert_equal [1, 3, 2, 4], initial.sort(&Dependency.comparator(:resolving_project, "asc")).map(&:number)
    assert_equal [2, 4, 1, 3], initial.sort(&Dependency.comparator(:resolving_project, "desc")).map(&:number)
  end

  def test_comparator_can_accept_users
    dep1, dep2, dep3 = nil, nil, nil
    project_2 = nil

    with_new_project do |project|
      project.update_attribute(:name, "b")
      project_2 = project
    end

    with_new_project do |project|
      project.update_attribute(:name, "a")
      card = project.cards.create!(:name => "first a", :card_type_name => "card")
      dep1 = card.raise_dependency(:number => 1, :desired_end_date => Date.parse("2014-09-11"), :resolving_project_id => project.id, :name => "dep1")
      dep1.save!
      dep2 = card.raise_dependency(:number => 2, :desired_end_date => Date.parse("2014-08-11"), :resolving_project_id => project_2.id, :name => "dep2")
      dep2.save!

      login_as_admin

      dep3 = card.raise_dependency(:number => 3, :desired_end_date => Date.parse("2014-10-11"), :resolving_project_id => project.id, :name => "dep3")
      dep3.save!
    end

    initial = [dep1, dep2, dep3]
    assert_equal [3, 1, 2], initial.sort(&Dependency.comparator(:raising_user, "asc")).map(&:number)
    assert_equal [1, 2, 3], initial.sort(&Dependency.comparator(:raising_user, "desc")).map(&:number)
  end

  def test_card_finds_its_raised_dependencies_within_its_project
    login_as_admin
    Dependency.find_each(&:destroy)

    card_1_p1 = nil, card_1_p2 = nil
    project_1 = with_new_project do |project|
      card_1_p1 = project.cards.create!(:name => "first card project 1", :card_type_name => "card")
      assert_equal 1, project.cards.count
      assert_equal 1, card_1_p1.number

      card_1_p1.raise_dependency(:name => "dependency for project_1/#1", :resolving_project_id => project.id, :desired_end_date => "2016-02-24").save!
    end

    project_2 = with_new_project do |project|
      card_1_p2 = project.cards.create!(:name => "first card project 2", :card_type_name => "card")
      assert_equal 1, project.cards.count
      assert_equal 1, card_1_p2.number

      card_1_p2.raise_dependency(:name => "dependency for project_2/#1", :resolving_project_id => project.id, :desired_end_date => "2016-02-24").save!
    end

    assert_equal ["dependency for project_2/#1"], card_1_p2.reload.raised_dependencies.map(&:name)
  end

  def test_can_find_raising_card
    dependency = @card.raise_dependency(:resolving_project_id => @project.id, :desired_end_date => "8-11-2014", :name => "some dependency")
    dependency.save!
    assert_equal dependency.raising_card.number, @card.number
  end

  def test_can_find_all_resolving_cards
    dependency = @card.raise_dependency(:resolving_project_id => @project.id, :desired_end_date => "8-11-2014", :name => "some dependency")
    dependency.save!
    card1 = @project.cards.create(:name => "resolving card1", :card_type_name => "card")
    card2 = @project.cards.create(:name => "resolving card2", :card_type_name => "card")

    dependency.link_resolving_cards([card1, card2])

    assert_equal 2, dependency.resolving_cards.length
    assert dependency.resolving_cards.include? card1
    assert dependency.resolving_cards.include? card2
  end

  def test_can_find_all_resolving_cards_for_cross_project_dependencies
    resolving_project = Project.create(:identifier => "resolving_project", :name => "Resolving project")
    dependency = @card.raise_dependency(:resolving_project_id => resolving_project.id, :desired_end_date => "8-11-2014", :name => "some dependency")
    dependency.save!
    card1 = resolving_project.cards.create(:name => "resolving card1", :card_type_name => "card")
    card2 = resolving_project.cards.create(:name => "resolving card2", :card_type_name => "card")
    dependency.link_resolving_cards([card1, card2])

    assert_equal 2, dependency.resolving_cards.length
    assert dependency.resolving_cards.include? card1
    assert dependency.resolving_cards.include? card2
  end

  def test_cannont_create_dependency_from_a_card_that_doesnt_exist
    assert_raise(ActiveRecord::RecordInvalid) { Dependency.create!(:raising_project_id => @project.id, :desired_end_date => "8-11-2014", :raising_card_number => 88*88, :name => "some dependency", :resolving_project_id => @project.id) }
  end

  def test_can_create_dependency_on_raising_project
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal dependency.resolving_project.identifier, dependency.raising_project.identifier
  end

  def test_should_not_be_able_to_access_dependency_controller_when_license_is_not_enterprise
    register_license(:product_edition => Registration::NON_ENTERPRISE)
    assert !CurrentLicense.status.enterprise?
    assert_mingle_admin_cant_access_to(:controller => 'dependencies', :action => 'create')
  end

  def test_dependency_status_is_new_when_created
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal Dependency::NEW, dependency.status
  end

  def test_assign_number
    Sequence.find_table_sequence('dependency_numbers').reset_to(0)

    dep1 = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "dep1")
    dep1.save!
    dep2 = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "dep2")
    dep2.save!
    assert_equal 1, dep1.number
    assert_equal 2, dep2.number

    p = Project.create!(:name => 'test proj', :identifier => 'test_proj')
    p.with_active_project do |project|
      card = p.cards.create!(:name => 'blah', :card_type_name => 'card')
      dep3 = card.raise_dependency(:number => dep2.number + 1, :desired_end_date => "8-11-2014", :resolving_project_id => project.id, :name => "some dependency")
      dep3.save!
      dep4 = card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => project.id, :name => "some dependency")
      dep4.save!

      assert_equal 3, dep3.number
      assert_equal 4, dep4.number
    end
  end

  def test_unlink_resolving_card_by_number
    resolving_project = Project.create(:identifier => "resolving_project", :name => "Resolving project")
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => resolving_project.id, :name => "some dependency")
    dependency.save!

    card1 = resolving_project.cards.create!(:name => "resolving card1", :card_type_name => "card")
    card2 = resolving_project.cards.create!(:name => "resolving card2", :card_type_name => "card")
    dependency.link_resolving_cards([card1, card2])

    assert_equal 2, dependency.reload.resolving_cards.length
    assert dependency.unlink_resolving_card_by_number(card1.number)
    assert_equal 1, dependency.resolving_cards.length

    dependency.unlink_resolving_card_by_number(99999)
    assert_equal 1, dependency.resolving_cards.length
  end

  def test_linking_same_card_twice_does_not_create_copies
    resolving_project = Project.create(:identifier => "resolving_project", :name => "Resolving project")
    dependency = @card.raise_dependency(:resolving_project_id => resolving_project.id, :desired_end_date => "8-11-2014", :name => "some dependency")
    dependency.save!
    card1 = resolving_project.cards.create(:name => "resolving card1", :card_type_name => "card")
    dependency.link_resolving_cards([card1, card1])

    assert_equal 1, dependency.reload.resolving_cards.length
    assert dependency.unlink_resolving_card_by_number(card1.number)
    assert_equal 0, dependency.resolving_cards.length
  end

  def test_dependency_status
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal Dependency::NEW, dependency.status

    card1 = @project.cards.create(:name => "resolving card1", :card_type_name => "card")
    dependency.link_resolving_cards([card1])

    assert_equal Dependency::ACCEPTED, dependency.reload.status
  end

  def test_creating_a_dependency_adds_a_raising_user
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal User.current, dependency.raising_user
  end

  def test_should_be_stay_resolved_if_dep_is_resolved_and_resolving_card_is_deleted
    resolving_project = project_without_cards
    @card.raise_dependency(:name => "resolved dep", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
    resolving_project.with_active_project do |proj|
      card = proj.cards.create!(:name => 'card1', :card_type_name => "Card")
      resolved_dep = proj.resolving_dependencies.find_by_name("resolved dep")
      resolved_dep.link_resolving_cards([card])
      resolved_dep.toggle_resolved_status
      card.destroy

      resolved_dep.reload
      assert_equal Dependency::RESOLVED, resolved_dep.status
    end
  end

  def test_should_change_status_to_new_if_dep_is_accepted_and_resolving_card_is_deleted
    resolving_project = project_without_cards
    @card.raise_dependency(:name => "accepted dep", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
    resolving_project.with_active_project do |proj|
      card = proj.cards.create!(:name => 'card1', :card_type_name => "Card")
      accepted_dep = proj.resolving_dependencies.find_by_name("accepted dep")

      accepted_dep.link_resolving_cards([card])
      assert_equal Dependency::ACCEPTED, accepted_dep.status
      card.destroy

      accepted_dep.reload
      assert_equal Dependency::NEW, accepted_dep.status
    end
  end

  def test_versionize
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal 1, dependency.versions.size
    dependency.update_attribute :name, 'new name'
    assert_equal 2, dependency.versions.size
    assert_equal 'new name', dependency.versions.find_by_version(2).name
  end

  def test_dependency_resolving_cards_are_versioned
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal 0, dependency.dependency_resolving_cards.size
    assert_equal 0, dependency.versions.find_by_version(1).dependency_resolving_cards.size

    resolving_card = @project.cards.create!(:name => 'resolving card', :card_type_name => 'card')
    dependency.link_resolving_cards([resolving_card])

    dependency.reload
    assert_equal 1, dependency.dependency_resolving_cards.size
    assert_equal 2, dependency.versions.size
    assert_equal 0, dependency.versions.find_by_version(1).dependency_resolving_cards.size
    assert_equal 1, dependency.versions.find_by_version(2).dependency_resolving_cards.size

    second_resolving_card = @project.cards.create!(:name => 'second resolving card', :card_type_name => 'card')
    dependency.link_resolving_cards([second_resolving_card])

    assert_equal 1, dependency.versions.find_by_version(2).dependency_resolving_cards.size
    assert_equal 2, dependency.versions.find_by_version(3).dependency_resolving_cards.size
    dependency.unlink_resolving_card_by_number(second_resolving_card.number)

    assert_equal 4, dependency.versions.size
    assert_equal 2, dependency.versions.find_by_version(3).dependency_resolving_cards.size
    assert_equal 1, dependency.versions.find_by_version(4).dependency_resolving_cards.size
  end

  def test_one_version_is_created_on_linking_multiple_cards_on_a_dependency
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    resolving_card1 = @project.cards.create!(:name => 'resolving card1', :card_type_name => 'card')
    resolving_card2 = @project.cards.create!(:name => 'resolving card2', :card_type_name => 'card')
    dependency.link_resolving_cards([resolving_card1, resolving_card2])

    assert_equal 2, dependency.reload.versions.size
    assert_equal 2, dependency.versions.latest.dependency_resolving_cards.size
    assert_equal 0, dependency.versions.first.dependency_resolving_cards.size
  end

  def test_should_create_one_event_when_dependency_is_raising_to_same_project
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    events = dependency.versions.last.events
    assert_equal 1, events.size
    assert_equal @project, events.first.project
  end

  def test_should_create_events_for_both_raising_and_resolving_projects
    project2 = project_without_cards
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => project2.id, :name => "some dependency")
    dependency.save!
    events = dependency.versions.last.events
    assert_equal 2, events.size
    assert_equal ['first_project', 'project_without_cards'], events.map(&:deliverable).map(&:identifier).sort
  end

  def test_dependency_and_dependency_version_should_have_raising_card_number
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => @project.id, :name => "some dependency")
    dependency.save!
    assert_equal @card.number, dependency.raising_card_number
    assert_equal @card.number, dependency.versions.last.raising_card_number
  end

  def test_destroying_dependency_destroy_versions_and_events
    project2 = project_without_cards
    dependency = @card.raise_dependency(:desired_end_date => "8-11-2014", :resolving_project_id => project2.id, :name => "some dependency")
    dependency.save!
    latest_version = dependency.versions.last

    dependency.destroy

    assert_false Dependency::Version.exists?(:dependency_id => dependency.id)
    assert_false Event.exists?(:origin_id => latest_version.id, :origin_type => 'Dependency::Version', :deliverable_id => project2.id )
    assert_false Event.exists?(:origin_id => latest_version.id, :origin_type => 'Dependency::Version', :deliverable_id => @project.id )
  end
end
