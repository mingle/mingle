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

class DependencyExporterTest <  ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    assert DependencyExporter.new('').exports_to_sheet?
    assert_equal 'Dependencies', DependencyExporter.new('').name
  end

  def test_sheet_should_contain_dependencies_data
    login_as_admin

    first_raising_card, second_raising_card, first_resolving_card, second_resolving_card, first_dependency, second_dependency = nil
    raising_project = with_new_project do |project|
      project.add_member(User.current)
      first_raising_card = create_card!(name: 'card 1')
      second_raising_card = create_card!(name: 'card 2')
    end

    resolving_project = with_new_project do |project|
      first_resolving_card = create_card!(name: 'resolving card 1')
      second_resolving_card = create_card!(name: 'resolving card 2')
    end

    second_dep_large_content = generate_random_string(39000)
    raising_project.with_active_project do |p|
      first_dependency = first_raising_card.raise_dependency(
          :desired_end_date => '12-11-2018',
          :resolving_project_id => resolving_project.id,
          :name => 'First dependency',
          :description => '<html><body>help with this</body></html>')
      first_dependency.save!
      first_dependency.link_resolving_cards([first_resolving_card, second_resolving_card])
      second_dependency = second_raising_card.raise_dependency(
          :desired_end_date => '12-12-2018',
          :resolving_project_id => resolving_project.id,
          :name => 'Second dependency',
          :description => second_dep_large_content)
      second_dependency.save!
      second_dependency.attach_files(sample_attachment, another_sample_attachment)
    end

    temp_dir = RailsTmpDir::RailsTmpFileProxy.new('dep_exports').pathname
    dependency_exporter = DependencyExporter.new(temp_dir)
    sheet = ExcelBook.new('test_dependencies').create_sheet(dependency_exporter.name)
    dependency_exporter.export(sheet)

    assert(File.directory?(File.join(temp_dir, 'Large descriptions')))
    assert(File.exists?(File.join(temp_dir, 'Large descriptions', "dependency_#{second_dependency.number}_Description (Plain text).txt")))
    assert(File.exists?(File.join(temp_dir, 'Large descriptions', "dependency_#{second_dependency.number}_Description (HTML).txt")))

    assert_equal 14, sheet.headings.count
    assert_equal ['Number', 'Name', 'Description (Plain text)', 'Description (HTML)',
                  'Status	', 'Date raised', 'Desired completion date', 'Raising project',
                  'Raising card', 'Raising user', 'Resolving project', 'Resolving cards', 'Attachments', 'Data exceeding 32767 character limit'], sheet.headings

    assert_equal 3, sheet.number_of_rows
    assert_equal [first_dependency.number, 'First dependency', 'help with this', '<html><body>help with this</body></html>',
                  'ACCEPTED', Date.today.strftime('%d %b %Y'), '12 Nov 2018', raising_project.name, first_raising_card.number_and_name,
                  User.current.login, resolving_project.name, "#{first_resolving_card.number_and_name}\r#{second_resolving_card.number_and_name}", ''], sheet.row(1)
    assert_equal [second_dependency.number, 'Second dependency', large_content_message(second_dependency, 'Description (Plain text)'), large_content_message(second_dependency, 'Description (HTML)'),
                  'NEW', Date.today.strftime('%d %b %Y'), '12 Dec 2018', raising_project.name, second_raising_card.number_and_name,
                  User.current.login, resolving_project.name, '', attachments(second_dependency), "Description (Plain text)\rDescription (HTML)"], sheet.row(2)
  end


  def test_should_be_exportable_when_dependencies_exists
    login_as_admin
    first_raising_card, time = nil
    raising_project = with_new_project do |project|
      project.add_member(User.current)
      first_raising_card = create_card!(name: 'card 1')
    end
    resolving_project = with_new_project {}
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
    end

    dependency_exporter = DependencyExporter.new(RailsTmpDir::RailsTmpFileProxy.new('dep_exports').pathname)
    assert dependency_exporter.exportable?
  end

  def test_should_not_be_exportable_when_dependencies_does_not_exists
    login_as_admin
    with_new_project(name: 'Random project', time_zone: 'London', date_format: '%m/%d/%Y') do |project|
      dependency_exporter = DependencyExporter.new(RailsTmpDir::RailsTmpFileProxy.new('dep_exports').pathname)
      assert_false dependency_exporter.exportable?
    end
  end

  private

  def large_content_message(second_dependency, column)
    "Content too large. Written to file:Large descriptions/dependency_#{second_dependency.number}_#{column}.txt"
  end

  def attachments(dep)
    dep.reload.attachments.map {|a| "Attachments/#D#{dep.number}/#{a.file_name}"}.join("\r")
  end
end
