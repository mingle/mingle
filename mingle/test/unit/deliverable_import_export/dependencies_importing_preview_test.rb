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

class DependenciesImportingPreviewTest < ActiveSupport::TestCase

  def setup
    @user = login_as_admin
    @project1 = create_project(:name => "Project1", :identifier => "project1")
    @project2 = create_project(:name => "Project2", :identifier => "project2")
    @project3 = create_project(:name => "Project3", :identifier => "project3")
    @projects = [ @project1, @project2]
    setup_dependencies_for_projects
  end

  def setup_dependencies_for_projects
    @project1.with_active_project do |p1|
      @raising_card_1 = p1.cards.create!(:name => 'p1 card', :card_type_name => 'card')
      @dependency_1 = @raising_card_1.raise_dependency(
        :name => "First Dependency",
        :resolving_project_id => @project2.id,
        :desired_end_date => "2016-01-31"
      )
      @dependency_1.save!
    end
    @project2.with_active_project do |p2|
      @resolving_card_1 = p2.cards.create!(:name => 'resolving card 1', :card_type_name => 'card')
      @resolving_card_2 = p2.cards.create!(:name => 'resolving card 2', :card_type_name => 'card')
      @dependency_1.link_resolving_cards([@resolving_card_1, @resolving_card_2])

      @raising_card_2 = p2.cards.create!(:name => 'p2 card', :card_type_name => 'card')
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
  end

  def test_should_fail_for_invalid_zip_file
    tmp_file = Tempfile.new(["test",".dependencies"])
    preview = create_dependencies_importing_preview!(User.current, tmp_file)
    preview.process!
    assert preview.completed?
    assert preview.failed?
    assert_equal ["Invalid import file"], preview.reload.error_details
    assert_equal 'completed failed', preview.status
  ensure
    tmp_file.delete
  end

  def test_should_show_error_when_raising_or_resolving_project_does_not_exist
    export_file = create_dependencies_exporter!(@projects, @user).process!
    preview = create_dependencies_importing_preview!(@user, uploaded_file(export_file))
    @project1.update_attribute(:identifier, "new_project1_identifier")
    preview.process!
    assert_equal ["Extracting import file", "Creating importing dependencies preview", "Could not find raising or resolving project"], preview.progress_messages
    assert preview.completed?
    assert preview.failed?
    assert_equal ["Could not find raising or resolving project"], preview.reload.error_details
    assert_equal 'completed failed', preview.status
  end

  def test_should_create_dependencies_map
    export_file = create_dependencies_exporter!(@projects, @user).process!
    preview = create_dependencies_importing_preview!(@user, uploaded_file(export_file))
    preview.process!

    assert_equal ["Extracting import file", "Creating importing dependencies preview"], preview.progress_messages
    assert preview.completed?
    assert preview.success?

    sorted_deps = preview.dependencies.sort do |a, b|
      a["number"].to_i <=> b["number"].to_i
    end
    first_dep = sorted_deps.first

    assert_equal 0, preview.dependencies_errors.size
    assert_equal 2, sorted_deps.size, "should exclude dependencies associated with project 3"
    assert_equal "First Dependency", first_dep["name"]
    assert_equal "p1 card", first_dep["raising_card"]["name"]
    assert_equal @dependency_1.number, first_dep["number"].to_i
    assert_equal 2, first_dep["resolving_cards"].size

    sorted_resolving_cards = first_dep["resolving_cards"].sort do |a, b|
      a["name"] <=> b["name"]
    end

    assert_equal(["resolving card 1", "resolving card 2"], sorted_resolving_cards.map {|drc| drc["name"]})
    assert_equal([@resolving_card_1.number, @resolving_card_2.number], sorted_resolving_cards.map {|drc| drc["number"].to_i})

    assert_equal @dependency_2.number, sorted_deps.second["number"].to_i
  end

  def test_should_upgrade_old_dependencies_export
    Dependency::Version.find_each(&:destroy)
    Dependency.find_each(&:destroy)

    # these are expected in the export
    @upgrade_test_project_1 = create_project(:name => "test raising project for upgrade", :identifier => "test_raising_project_for_upgra") do |project|
      project.cards.create!(:number => 1, :name => "Raising Card 1", :card_type_name => "card")
    end

    @upgrade_test_project_2 = create_project(:name => "test resolving project for upgrade", :identifier => "test_resolving_project_for_upg") do |project|
      project.cards.create!(:number => 1, :name => "Resolving Card 1", :card_type_name => "card")
      project.cards.create!(:number => 2, :name => "Resolving Card 2", :card_type_name => "card")
    end

    preview = create_dependencies_importing_preview!(@user, uploaded_file(dependencies_export_file("upgrade_test.dependencies")))
    preview.process!

    assert_equal ["Extracting import file", "Creating importing dependencies preview", "Upgrading from a previous version, could take a long time..."], preview.progress_messages
    assert preview.completed?
    assert preview.success?

    assert_equal 2, preview.dependencies.size
    assert_equal 0, preview.dependencies_errors.size
    assert_equal [1, 1], (preview.dependencies.map {|dep| dep["raising_card"]["number"].to_i})

    assert_not_nil preview.table("dependencies"), "upgraded export should contain data"
    assert !(preview.table("dependencies").any? {|record| record.has_key?("raising_card_id")}), "upgraded export should not contain column from old table structure"
  ensure
    @upgrade_test_project_1.destroy
    @upgrade_test_project_2.destroy
  end

  def test_dependencies_without_raising_cards_should_be_under_errors
    export_file = create_dependencies_exporter!(@projects, @user).process!
    preview = create_dependencies_importing_preview!(@user, uploaded_file(export_file))

    @project1.with_active_project do |project|
      @raising_card_1.destroy
    end

    preview.process!

    assert preview.completed?
    assert preview.success?

    assert_equal 1, preview.dependencies.size
    assert_equal 1, preview.dependencies_errors.size
    assert_not_nil preview.dependencies.first["raising_card"]
    assert_nil preview.dependencies_errors.first["raising_card"]
  end

  def test_should_exclude_resolving_cards_that_do_not_exist
    export_file = create_dependencies_exporter!(@projects, @user).process!
    preview = create_dependencies_importing_preview!(@user, uploaded_file(export_file))

    @project2.with_active_project do |project|
      @resolving_card_2.destroy
    end

    preview.process!

    assert preview.completed?
    assert preview.success?

    sorted_deps = preview.dependencies.sort do |a, b|
      a["number"].to_i <=> b["number"].to_i
    end

    sorted_resolving_cards = sorted_deps.first["resolving_cards"].sort do |a, b|
      a["number"].to_i <=> b["number"].to_i
    end

    assert_equal 2, sorted_deps.size
    assert_equal([@resolving_card_1.number], sorted_resolving_cards.map {|drc| drc["number"].to_i})
  end

  def dependencies_export_file(name)
    File.join(Rails.root, "test", "data", "dependencies_exports", name)
  end

end
