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

class DependencyHistoryExporterTest < ActiveSupport::TestCase

  def setup
    Dependency.delete_all
    DependencyVersionEvent.delete_all
    DependencyDeletionEvent.delete_all
  end

  def test_should_export_to_sheet_and_name
    card_history_exporter = DependencyHistoryExporter.new('')
    assert card_history_exporter.exports_to_sheet?
    assert_equal 'History', card_history_exporter.name
  end

  def test_should_export_dependency_data_to_sheet
    with_temp_dir do |tmp|
      login_as_admin
      dependency_history_exporter = DependencyHistoryExporter.new(tmp, export_id: Export.create.id)
      sheet = ExcelBook.new('test_dependencies_history').create_sheet(dependency_history_exporter.name)

      first_raising_card, second_raising_card, first_resolving_card, first_dependency, second_dependency, time = nil
      raising_project = with_new_project do |project|
        project.add_member(User.current)
        first_raising_card = create_card!(name: 'card 1')
        second_raising_card = create_card!(name: 'card 2')
      end

      resolving_project = with_new_project do |project|
        first_resolving_card = create_card!(name: 'resolving card 1')
      end
      large_second_desc = generate_random_string(37672)

      raising_project.with_active_project do |p|
        time = DateTime.now.yesterday.utc
        Timecop.travel(time) do
          first_dependency = first_raising_card.raise_dependency(
              :desired_end_date => '12-11-2018',
              :resolving_project_id => resolving_project.id,
              :name => 'First dependency',
              :description => '<html><body>help with this</body></html>')
          first_dependency.save!
        end
        Timecop.travel(time + 1.minute) do
          first_dependency.link_resolving_cards([first_resolving_card])
        end
        Timecop.travel(time + 2.minute) do
          first_dependency.update_attribute(:desired_end_date, '14-11-2018')
        end
        Timecop.travel(time + 5.minute) do
          second_dependency = second_raising_card.raise_dependency(
              :desired_end_date => '12-12-2018',
              :resolving_project_id => resolving_project.id,
              :name => 'Second dependency',
              :description => large_second_desc)
          second_dependency.save!
        end
        Timecop.travel(time + 6.minute) do
          second_dependency.attach_files(sample_attachment)
          second_dependency.save!
        end
      end

      generate_changes_for_versions(first_dependency.versions)
      generate_changes_for_versions(second_dependency.versions)

      dependency_history_exporter.export(sheet)
      second_dep_time = time + 5.minute


      description_filename = File.basename(Dir[File.join(tmp, "Large descriptions/*.txt")].first)
      assert(File.directory?(File.join(tmp, 'Large descriptions')))

      assert_equal("--- \n+++ \n@@ -1,1 +1,1 @@\n-\n+#{large_second_desc}", File.read(File.join(tmp, 'Large descriptions', description_filename)))

      assert_equal ['Date','Time (UTC)','Modified by','Dependency','Event','Property','From','To', 'Description changes', 'Attachment name', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal 19, sheet.number_of_rows

      assert_equal [(second_dep_time + 1.minute).strftime('%d-%b-%Y'), (second_dep_time + 1.minute).strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Attachment added', 'attachment', '', '', '', 'sample_attachment.txt'], sheet.row(1)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Resolving project set', 'Resolving project', '', resolving_project.name, '', ''], sheet.row(2)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Name set', 'Name', '', 'Second dependency', '', ''], sheet.row(3)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Raising card set', 'Raising card', '', "#{raising_project.identifier}/#{second_raising_card.prefixed_number}" , '', ''], sheet.row(4)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Description changed', 'Description', '', '', "Content too large. Written to file:Large descriptions/#{description_filename}", '', 'Description changes'], sheet.row(5)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Property set', 'Desired end date', '', '12 Dec 2018' , '', ''], sheet.row(6)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Property set', 'Status', '', 'NEW' , '', ''], sheet.row(7)
      assert_equal [second_dep_time.strftime('%d-%b-%Y'), second_dep_time.strftime('%H:%M'), User.current.login, "#D#{second_dependency.number}", 'Dependency created', '', '', '', '', ''], sheet.row(8)

      assert_equal [(time + 2.minute).strftime('%d-%b-%Y'), (time + 2.minute).strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Property changed', 'Desired end date', '12 Nov 2018', '14 Nov 2018' , '', ''], sheet.row(9)
      assert_equal [(time + 1.minute).strftime('%d-%b-%Y'), (time + 1.minute).strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Card linked', 'New cards linked', '', "#{resolving_project.identifier}/#{first_resolving_card.prefixed_number}" , '', ''], sheet.row(10)
      assert_equal [(time + 1.minute).strftime('%d-%b-%Y'), (time + 1.minute).strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Property changed', 'Status', 'NEW', 'ACCEPTED' , '', ''], sheet.row(11)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Resolving project set', 'Resolving project', '', resolving_project.name , '', ''], sheet.row(12)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Name set', 'Name', '', 'First dependency' , '', ''], sheet.row(13)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Raising card set', 'Raising card', '', "#{raising_project.identifier}/#{first_raising_card.prefixed_number}", '', ''], sheet.row(14)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Description changed', 'Description', '', '', "--- \n+++ \n@@ -1,1 +1,1 @@\n-\n+<html><body>help with this</body></html>", ''], sheet.row(15)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Property set', 'Desired end date', '', '12 Nov 2018', '', ''], sheet.row(16)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Property set', 'Status', '', 'NEW', '', ''], sheet.row(17)
      assert_equal [time.strftime('%d-%b-%Y'), time.strftime('%H:%M'), User.current.login, "#D#{first_dependency.number}", 'Dependency created', '', '', '', '', ''], sheet.row(18)
    end
  end

  def test_should_be_exportable_when_dependency_history_is_present
    login_as_admin


    first_raising_card, first_resolving_card, first_dependency, time = nil
    raising_project = with_new_project do |project|
      project.add_member(User.current)
      first_raising_card = create_card!(name: 'card 1')
    end

    resolving_project = with_new_project do |project|
      first_resolving_card = create_card!(name: 'resolving card 1')
    end

    raising_project.with_active_project do |p|
      time = DateTime.now.yesterday.utc
      Timecop.travel(time) do
        first_dependency = first_raising_card.raise_dependency(
            :desired_end_date => '12-11-2018',
            :resolving_project_id => resolving_project.id,
            :name => 'First dependency',
            :description => '<html><body>help with this</body></html>')
        first_dependency.save!
      end
      Timecop.travel(time + 1.minute) do
        first_dependency.link_resolving_cards([first_resolving_card])
      end
      Timecop.travel(time + 2.minute) do
        first_dependency.update_attribute(:desired_end_date, '14-11-2018')
      end
    end

    generate_changes_for_versions(first_dependency.versions)
    dependency_history_exporter = DependencyHistoryExporter.new('', export_id: Export.create.id)
    assert dependency_history_exporter.exportable?
  end

  def test_should_not_be_exportable_when_there_is_no_dependency_history
    login_as_admin
    with_new_project(name: 'Random project', time_zone: 'London', date_format: '%m/%d/%Y') do |project|
      page_data_exporter = PageHistoryExporter.new('', export_id: Export.create.id)
      assert_false page_data_exporter.exportable?
    end
  end

  private

  def generate_changes_for_versions(versions)
    versions.each do |version|
      version.events.each {|e| e.send(:generate_changes) }
    end
  end


end
