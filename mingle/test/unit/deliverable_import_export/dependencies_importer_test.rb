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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class DependenciesImporterTest < ActiveSupport::TestCase

  def setup
    @admin = login_as_admin

    create_test_projects
    setup_dependencies_for_projects
  end

  def teardown
    clear_dependency_data
    clear_test_projects
  end

  def create_test_projects
    @project1 = create_project(:name => "Project1", :identifier => "project1").tap do |p1|
      p1.with_active_project do
        @raising_card_1 = p1.cards.create!(:name => 'p1 card', :card_type_name => 'card')
      end
    end

    @project2 = create_project(:name => "Project2", :identifier => "project2").tap do |p2|
      p2.with_active_project do
        @resolving_card_1 = p2.cards.create!(:name => 'resolving card 1', :card_type_name => 'card')
        @resolving_card_2 = p2.cards.create!(:name => 'resolving card 2', :card_type_name => 'card')
        @raising_card_2 = p2.cards.create!(:name => 'p2 card', :card_type_name => 'card')
      end
    end

    @project3 = create_project(:name => "Project3", :identifier => "project3")
    @projects = [@project1, @project2]
  end

  def setup_dependencies_for_projects
    @dependency_1 = @raising_card_1.raise_dependency(
      :name => "First Dependency",
      :resolving_project_id => @project2.id,
      :desired_end_date => "2016-01-31"
      )
    @dependency_1.save!

    @dependency_1.link_resolving_cards([@resolving_card_1, @resolving_card_2])

    @dependency_2 = @raising_card_2.raise_dependency(
      :name => "Second Dependency",
      :resolving_project_id => @project1.id,
      :desired_end_date => "2016-01-31"
    )
    @dependency_2.save!

    @dependency_3 = @raising_card_2.raise_dependency(
      :name => "Third Dependency",
      :resolving_project_id => @project3.id,
      :desired_end_date => "2016-01-31"
    )
    @dependency_3.save!

    @dependencies = [ @dependency_1, @dependency_2, @dependency_3 ]
  end

  def test_should_create_missing_users_and_maps_them_correctly
    expendable = create_user!(
      :name => "the first ensign that gets killed in every episode of star trek",
      :icon => sample_attachment('user_icon.png')
    )

    @project2.with_active_project do |project|
      project.add_member(expendable)
      User.with_current(expendable) do
        @raising_card_2.raise_dependency(
          :name => "Fourth Dependency",
          :resolving_project_id => @project1.id,
          :desired_end_date => "2016-01-31"
        ).save!
      end
    end

    export_file = create_dependencies_exporter!(@projects, @admin).process!
    clear_dependency_data

    expected_login = expendable.login
    original_user_id = expendable.id
    expendable.destroy # he's dead, Jim.

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    assert_not_nil (imported_user = User.find_by_login(expected_login)), "missing user was not imported"
    assert_not_equal original_user_id, imported_user.id, "should truly be a new user"

    assert File.exists? File.join(Rails.root, "public", imported_user.icon_path[1..-1])

    assert_not_nil (dependency = Dependency.find_by_name("Fourth Dependency"))
    assert_equal imported_user.id, dependency.raising_user_id, "imported user should be mapped to associated dependency"
  end

  def test_should_ensure_raising_users_memberships_in_respective_raising_projects
    outsider = create_user!(:name => "nobody likes me")

    @project2.with_active_project do |project|
      project.add_member(outsider)
      User.with_current(outsider) do
        @raising_card_2.raise_dependency(
          :name => "Fourth Dependency",
          :resolving_project_id => @project1.id,
          :desired_end_date => "2016-01-31"
        ).save!
      end
    end

    export_file = create_dependencies_exporter!(@projects, @admin).process!

    clear_dependency_data
    clear_test_projects
    create_test_projects

    assert !is_member_of_project?(outsider, @project2)

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    assert_not_nil (dependency = Dependency.find_by_name("Fourth Dependency"))
    assert_equal outsider.id, dependency.raising_user_id

    assert is_member_of_project?(outsider, @project2), "raising user should have been added as a member to raising project"
  end

  def test_attachments_are_imported
    @dependency_1.attach_files(sample_attachment("attachment_for_dep_1.txt"))
    @dependency_1.save!

    @dependency_2.attach_files(sample_attachment("attachment_for_dep_2.txt"))
    @dependency_2.save!

    export_file = create_dependencies_exporter!(@projects, @admin).process!
    clear_dependency_data

    @project2.with_active_project do
      # we will skip importing dependency 2 to validate no orphaned attachings are created
      @raising_card_2.destroy
    end

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    imported_dep1 = Dependency.find_by_name(@dependency_1.name)
    assert_not_nil imported_dep1

    assert_nil Dependency.find_by_name(@dependency_2.name)
    assert_nil Dependency::Version.find_by_name(@dependency_2.name)

    has_orphaned_attachings = Attaching.all.any? do |at|
      at.attachment.nil? || at.attachable.nil?
    end
    assert !has_orphaned_attachings

    assert_equal ["attachment_for_dep_1.txt"], imported_dep1.attachments.map(&:file_name)

    version_attachments = imported_dep1.versions.inject([]) do |memo, version|
      memo += version.attachments.map(&:file_name) if (version.attachments.size > 0)
      memo
    end

    assert_equal ["attachment_for_dep_1.txt"], version_attachments
    assert_equal 1, Attaching.count(:conditions => ["attachable_type = ?", "Dependency"])
    assert_equal 1, Attaching.count(:conditions => ["attachable_type = ?", "Dependency::Version"])
  end

  def test_events_are_imported
    assert_equal 2, @dependency_1.versions.count
    assert_equal 2, @dependency_1.versions.map(&:event).compact.size

    assert_equal 1, @dependency_2.versions.count
    assert_equal 1, @dependency_2.versions.map(&:event).compact.size

    export_file = create_dependencies_exporter!(@projects, @admin).process!
    clear_dependency_data

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    imported_dep1 = Dependency.find_by_name(@dependency_1.name)
    assert_not_nil imported_dep1
    assert_equal 2, imported_dep1.versions.count
    assert_equal 2, imported_dep1.versions.map(&:event).compact.size

    imported_dep2 = Dependency.find_by_name(@dependency_2.name)
    assert_not_nil imported_dep2
    assert_equal 1, imported_dep2.versions.count
    assert_equal 1, imported_dep2.versions.map(&:event).compact.size

    Dependency::Version.find_each do |ver|
      assert !ver.event.history_generated?, "events should be ready for history generation"
      assert_equal 0, ver.event.changes.count, "should import events, but not changes"
    end

    assert_equal [@project1.id, @project2.id].sort, importer.history_generated_for.sort, "import should trigger history generation for all involved projects"
  end

  def test_upgrade_dependencies_export_before_import
    clear_dependency_data

    # these are expected in the export
    @upgrade_test_project_1 = create_project(:name => "test raising project for upgrade", :identifier => "test_raising_project_for_upgra") do |project|
      project.cards.create!(:number => 1, :name => "Raising Card 1", :card_type_name => "card")
    end

    @upgrade_test_project_2 = create_project(:name => "test resolving project for upgrade", :identifier => "test_resolving_project_for_upg") do |project|
      project.cards.create!(:number => 1, :name => "Resolving Card 1", :card_type_name => "card")
      project.cards.create!(:number => 2, :name => "Resolving Card 2", :card_type_name => "card")
    end

    importer = create_dependencies_importer!(@admin, dependencies_export_file("upgrade_test.dependencies"))
    importer.process!

    assert importer.completed?
    assert importer.success?

    imported_dep1 = Dependency.find_by_name("First Dependency")
    assert_not_nil imported_dep1

    assert_equal @upgrade_test_project_1.id, imported_dep1.raising_project_id
    assert_equal @upgrade_test_project_2.id, imported_dep1.resolving_project_id
    assert_equal 1, imported_dep1.raising_card_number

    assert !(importer.table("dependencies").any? {|record| record.has_key?("raising_card_id")}), "upgraded export should not contain column from old table structure"
  ensure
    @upgrade_test_project_1.destroy
    @upgrade_test_project_2.destroy
  end

  def test_dependencies_are_imported
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    clear_dependency_data

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    imported_dep1 = Dependency.find_by_name(@dependency_1.name)
    assert_not_nil imported_dep1
    assert_not_equal @dependency_1.number, imported_dep1.number
    assert_equal @project1.id, imported_dep1.raising_project_id
    assert_equal @project2.id, imported_dep1.resolving_project_id
    assert_equal @raising_card_1.number, imported_dep1.raising_card_number

    imported_dep2 = Dependency.find_by_name(@dependency_2.name)
    assert_not_nil imported_dep2
    assert_not_equal @dependency_2.number, imported_dep2.number
    assert_equal @project2.id, imported_dep2.raising_project_id
    assert_equal @project1.id, imported_dep2.resolving_project_id
    assert_equal @raising_card_2.number, imported_dep2.raising_card_number

    assert_equal [1, 2], imported_dep1.versions.map(&:version).sort
  end

  def test_dependencies_are_not_replaced_on_import
    original_dependency_numbers = Dependency.all.map(&:number)
    export_file = create_dependencies_exporter!(@projects, @admin).process!

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    newly_imported_dependencies = get_all_dependencies_excluding(original_dependency_numbers)

    assert_equal 2, newly_imported_dependencies.size
    assert_equal 2, (newly_imported_dependencies.map(&:number) - original_dependency_numbers).size, "newly created dependencies should have unique numbers"

    assert_equal [@dependency_1.name, @dependency_2.name].sort, newly_imported_dependencies.map(&:name).sort

    dep_map = map_by_name(newly_imported_dependencies)

    imported_dep1 = dep_map[@dependency_1.name]
    assert_equal [1, 2], imported_dep1.versions.map(&:version).sort
    assert_equal [1], dep_map[@dependency_2.name].versions.map(&:version).sort

    assert_equal 2, imported_dep1.resolving_cards.size
    assert_equal [@resolving_card_1.name, @resolving_card_2.name], imported_dep1.resolving_cards.map(&:name).sort
  end

  def test_recalculates_dependency_statuses_after_import
    assert_equal Dependency::ACCEPTED, Dependency.find_by_name("First Dependency").status
    export_file = create_dependencies_exporter!(@projects, @admin).process!

    clear_dependency_data

    @project2.with_active_project do |project|
      @resolving_card_1.destroy
      @resolving_card_2.destroy
    end

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    dependency = Dependency.find_by_name("First Dependency")

    assert_not_nil dependency
    assert_equal [], dependency.resolving_cards, "should not have any resolving cards as they were deleted"
    assert_equal Dependency::NEW, dependency.status, "status should have been recalculated to NEW"
  end

  def test_dependencies_with_no_raising_card_are_skipped
    @project1.with_active_project do |project|
      @another_resolving_card = project.cards.create!(:name => "resolves dependency 2", :card_type_name => "card")
    end

    @project2.with_active_project do |project|
      @dependency_2.link_resolving_cards([@another_resolving_card])
    end

    export_file = create_dependencies_exporter!(@projects, @admin).process!

    @project1.with_active_project do |project|
      @raising_card_1.destroy
    end

    clear_dependency_data

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    assert_nil Dependency.find_by_name(@dependency_1.name)
    assert_nil Dependency::Version.find_by_name(@dependency_1.name)

    imported_dep2 = Dependency.find_by_name(@dependency_2.name)
    assert_not_nil imported_dep2
    assert_not_equal @dependency_2.number, imported_dep2.number
    assert_equal [1, 2], imported_dep2.versions.map(&:version).sort

    has_orphaned_drcs = DependencyResolvingCard.all.any? do |drc|
      drc.dependency.nil?
    end
    assert !has_orphaned_drcs
  end

  def test_skip_resolving_cards_if_they_dont_exist
    original_dependency_numbers = Dependency.all.map(&:number)
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    @project2.with_active_project do |p|
      @resolving_card_1.destroy
    end

    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    assert importer.completed?
    assert importer.success?

    imported_deps = map_by_name(get_all_dependencies_excluding(original_dependency_numbers))

    assert_equal 2, imported_deps.size
    imported_dep1 = imported_deps[@dependency_1.name]

    has_orphaned_drcs = DependencyResolvingCard.find_all_by_dependency_type("Dependency").any? do |drc|
      drc.card.nil?
    end

    assert !has_orphaned_drcs, "should not import dependency resolving card associations when no card exists"
    assert_equal [@resolving_card_2.number], DependencyResolvingCard.find_all_by_dependency_id_and_dependency_type(imported_dep1.id, "Dependency").map(&:card_number)
    assert_equal [@resolving_card_2.number], DependencyResolvingCard.find_all_by_dependency_id_and_dependency_type(imported_dep1.versions.last.id, "Dependency::Version").map(&:card_number)
  end

  def test_should_be_able_to_resolve_projects_through_identifier
    orig_p1_id, orig_p2_id = @project1.id, @project2.id
    orig_p1_identifier, orig_p2_identifier = @project1.identifier, @project2.identifier

    export_file = create_dependencies_exporter!(@projects, @admin).process!

    # wipe all data to simulate import on new instance
    clear_dependency_data
    [@project1, @project2, @project3].each(&:destroy)
    @projects = []

    # recreate new projects to simulate projects imported on new instance
    create_test_projects
    importer = create_dependencies_importer!(@admin, export_file)
    importer.process!

    # ids should be different
    assert_not_equal orig_p1_id, @project1.id
    assert_not_equal orig_p2_id, @project2.id

    # but identifiers should be the same so that import can resolve the raising and resolving projects
    assert_equal orig_p1_identifier, @project1.identifier
    assert_equal orig_p2_identifier, @project2.identifier

    assert importer.completed?
    assert importer.success?

    assert_equal 2, Dependency.count
    assert_equal 2, DependencyResolvingCard.count(:conditions => ["dependency_type = ?", "Dependency"])
    assert_equal 2, DependencyResolvingCard.count(:conditions => ["dependency_type = ?", "Dependency::Version"])
    assert_equal ['First Dependency', 'Second Dependency'], Dependency.all.map(&:name).sort
    assert_equal @project1.id, Dependency.find_by_name("First Dependency").raising_project_id

    resolving_card_counts = Dependency.all.inject({}) do |memo, dependency|
      memo[dependency.name] = dependency.dependency_resolving_cards.count
      memo
    end

    assert_equal 2, resolving_card_counts["First Dependency"]
    assert_equal 0, resolving_card_counts["Second Dependency"]
  end

  private

  def is_member_of_project?(user, project)
    project.with_active_project do |project|
      project.team.reload
      project.member?(user)
    end
  end

  def clear_dependency_data
    [Dependency::Version, Dependency, DependencyResolvingCard, Attachment, Attaching].each do |model|
      model.find_each(&:destroy)
      assert_equal 0, model.count
    end
  end

  def clear_test_projects
    [@project1, @project2, @project3].each do |project|
      project.destroy if project
    end
  end

  def map_by_name(dependencies)
    dependencies.inject({}) do |memo, dep|
      memo[dep.name] = dep
      memo
    end
  end

  def get_all_dependencies_excluding(dep_numbers)
    number_column = Dependency.connection.quote_column_name("number")
    bind_variables = (dep_numbers.size.times.map { "?" }).join(", ")
    Dependency.find(:all, :conditions => ["#{number_column} not in (#{bind_variables})", *dep_numbers])
  end

end
