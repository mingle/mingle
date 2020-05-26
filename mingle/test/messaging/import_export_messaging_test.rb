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

class ImportExportMessagingTest < ActiveSupport::TestCase
  include Zipper, TreeFixtures::PlanningTree
  include MessagingTestHelper

  def setup
    # this test will fail if there's residue in the database
    # and we are having trouble with transactionality in this test
    # let's ensure there's nothing weird there before we start the test
    login_as_member

    project_icon = uploaded_file(icon_file_path("icon.png"))
    unique_name = unique_project_name
    @project = Project.create!(:name => unique_name, :identifier => unique_name, :icon => project_icon)
    setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]

    @tag = @project.tags.create!(:name => 'Exported Tag')
    @card = create_card!(:name => 'Exported Card').tag_with(['Exported Tag', 'Another Tag'])
    @card.attach_files(sample_attachment)
    assert_equal 1, @card.attachments.size
    @member = User.find_by_login("member")
    @project.add_member(@member)
  end

  def teardown
    Clock.reset_fake
    # FileUtils.rm_f(@export_file) if @export_file

    User.find_by_login('bug4627').destroy if User.find_by_login('bug4627')
    # we are in a transaction, commit it and start a new one
    Project.connection.commit_db_transaction
    Project.connection.begin_db_transaction
  end

  def test_history_generated_for_dependencies_import
    admin = login_as_admin

    # wipe these out in case they are left over from another test
    ["test_raising_project_for_upgra", "test_resolving_project_for_upg"].each do |identifier|
      Project.find_by_identifier(identifier).tap do |project|
        project.destroy unless project.nil?
      end
    end

    # these are expected to exist by the export file
    @raising_project = create_project(:name => "test raising project for upgrade", :identifier => "test_raising_project_for_upgra") do |project|
      project.cards.create!(:number => 1, :name => "Raising Card 1", :card_type_name => "card")
    end

    @resolving_project = create_project(:name => "test resolving project for upgrade", :identifier => "test_resolving_project_for_upg") do |project|
      project.cards.create!(:number => 1, :name => "Resolving Card 1", :card_type_name => "card")
      project.cards.create!(:number => 2, :name => "Resolving Card 2", :card_type_name => "card")
    end

    assert_equal 0, Dependency.count, "should start with a clean slate (no Dependencies)"
    assert_equal 0, Dependency::Version.count, "should start with a clean slate (no Dependency::Versions)"
    assert_equal 0, DependencyVersionEvent.count, "should start with a clean slate (no dependency Events)"

    importer = create_dependencies_importer!(admin, dependencies_export_file("upgrade_test.dependencies"))
    importer.process!

    assert importer.completed?
    assert importer.success?

    # loose assertions here as a sanity check; worry not, we have other tests that make more thorough assertions
    assert_equal 2, Dependency.count, "dependencies were not imported"
    assert_equal 4, Dependency::Version.count, "dependency versions were not imported"

    assert_equal 4, DependencyVersionEvent.count(:conditions => ["deliverable_id = ?", @raising_project.id]), "raising project should have dependency events"
    assert_equal 4, DependencyVersionEvent.count(:conditions => ["deliverable_id = ?", @resolving_project.id]), "resolving project should have dependency events"

    # initial state has history_generated set to false
    assert(DependencyVersionEvent.find_all_by_deliverable_id(@raising_project.id).none? {|ev| ev.history_generated?})
    assert(DependencyVersionEvent.find_all_by_deliverable_id(@resolving_project.id).none? {|ev| ev.history_generated?})

    HistoryGeneration.run_once(:batch_size => 1000)

    # prove that history generation touched these events
    assert(DependencyVersionEvent.find_all_by_deliverable_id(@raising_project.id).all? {|ev| ev.history_generated?})
    assert(DependencyVersionEvent.find_all_by_deliverable_id(@resolving_project.id).all? {|ev| ev.history_generated?})

    # prove that changes were indeed generated
    assert(DependencyVersionEvent.find_all_by_deliverable_id(@raising_project.id).all? { |event| event.changes.count > 0 })
    assert(DependencyVersionEvent.find_all_by_deliverable_id(@resolving_project.id).all? { |event| event.changes.count > 0 })
  ensure
    [@raising_project, @resolving_project].each do |project|
      project.destroy unless project.nil?
    end
  end

  def test_export_and_import_of_history_and_changes
    export = create_project_exporter!(@project, @member).export
    imported_project = create_project_importer!(@member, export).process!.reload
    HistoryGeneration.run_once
    imported_project.with_active_project do
      assert_equal 2, imported_project.cards.last.versions.first.changes.size
      assert_equal 2, imported_project.cards.first.versions.first.changes.size
    end
  end

  def assert_same_card(expected, actual)
    assert_equal expected.name, actual.name
    assert_equal expected.number, actual.number
    assert_equal expected.version, actual.version
  end

  private

  def pretend_smtp_configuration_is_not_loaded
    SmtpConfiguration.class_eval do
      def self.load_with_always_disabled(file_name=SMTP_CONFIG_YML)
        return false
      end

      class << self
        alias_method_chain :load, :always_disabled
      end
    end
  end

  def reenable_smtp_configuration_load_method
    SmtpConfiguration.class_eval do
      class << self
        alias_method "load", "load_without_always_disabled"
      end
    end
  end

end
