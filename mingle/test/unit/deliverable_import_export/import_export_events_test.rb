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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

# this test will fail if there's residue in the database
# and we are having trouble with transactionality in this test
# let's ensure there's nothing weird there before we start the test
class ImportExportEventsTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def setup
    @user = login_as_member
  end

  def test_should_import_events_but_not_changes
    with_new_project do |project|
      create_card!(:name => 'a card')
      export_file = create_project_exporter!(project, @user).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_project.reload

      imported_event = imported_project.cards.find_by_name("a card").versions.first.event
      assert_not_nil imported_event
      assert_equal 0, imported_event.changes.size
    end
  end

  def test_should_reset_history_generated_flag_for_events_imported
    with_new_project do |project|
      create_card!(:name => 'a card')
      project.events.map(&:generate_changes)
      export_file = create_project_exporter!(project, @user).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_project.reload

      imported_event = imported_project.cards.find_by_name("a card").versions.first.event
      assert_false imported_event.history_generated?
    end
  end

  def test_export_import_correction_event
    with_new_project do |project|
      setup_property_definitions :iteration => [1,2]
      project.find_property_definition('iteration').update_attributes(:name => 'sprint')
      export_file = create_project_exporter!(project, @user).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_project.reload
      imported_correction_events = CorrectionEvent.all(:conditions => {:deliverable_id => imported_project.id})
      assert_equal 1, imported_correction_events.size
      correction_events_origins = imported_correction_events.collect(&:origin_type)
      assert_equal ['PropertyDefinition'].sort, correction_events_origins.sort
      assert_equal 'sprint', imported_correction_events[correction_events_origins.index('PropertyDefinition')].origin.name
    end
  end

  def test_export_import_correction_event_when_event_origin_is_deleted
    with_new_project do |project|
      setup_property_definitions :iteration => [1,2]
      project.find_property_definition('iteration').update_attributes(:name => 'sprint')
      project.find_property_definition('sprint').destroy
      assert_equal 3, CorrectionEvent.count(:conditions => {:deliverable_id => project.id})

      export_file = create_project_exporter!(project, @user).export
      project_import = create_project_importer!(User.current, export_file)
      imported_project = project_import.process!
      imported_project.reload
      imported_correction_events = CorrectionEvent.all(:conditions => {:deliverable_id => imported_project.id}, :order => :id)
      assert_equal 3, imported_correction_events.size
      assert_equal ['PropertyDefinition', 'CardType', 'PropertyDefinition'], imported_correction_events.collect(&:origin_type)
      assert_equal imported_correction_events[0].origin_id, imported_correction_events[2].origin_id

    end
  end

  # Bugs 6540 and 6578
  def test_history_events_should_be_available_after_import
    project = create_project(:users => [@user])

    my_page = project.pages.create(:name => "my_page")
    my_card = create_card!(:name => 'my_card')

    export_file = create_project_exporter!(project, @user).export
    project_importer = create_project_importer!(User.current, export_file)
    imported_project = project_importer.process!

    my_page = imported_project.pages.find_by_name('my_page')
    my_card = imported_project.cards.find_by_name('my_card')
    assert_not_nil my_page.versions.first.event
    assert_not_nil my_card.versions.first.event
  end
end
