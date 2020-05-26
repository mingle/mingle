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

class ObjectivesExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    login_as_admin

    program = create_program

    assert ObjectivesExporter.new('', {program_id: program.id}).exports_to_sheet?
    assert_equal 'Objectives', ObjectivesExporter.new('', {program_id: program.id}).name
  end

  def test_sheet_should_contain_correct_program_objective_data
    admin = login_as_admin
    program = create_program
    time = DateTime.now.yesterday.utc

    large_value_statement = generate_random_string(36698)
    end_date_for_second_objective = nil
    Timecop.travel(time) do
      Timecop.travel(time + 1.minute) do
        program.objectives.backlog.create!(:name => "first_objective", :value => 50, :size => 60, :value_statement => large_value_statement, :modified_by_user_id => admin.id)
      end
      Timecop.travel(time + 2.minute) do
        end_date_for_second_objective = 1.year.from_now
        program.objectives.planned.create!(:name => "second_objective", :value => 30, :size => 40, :value_statement => '<p>It is a planned objective</p>', :modified_by_user_id => admin.id, :start_at => time, :end_at => end_date_for_second_objective)
      end
    end
    with_temp_dir do |tmp|
      objectives_exporter = ObjectivesExporter.new(tmp, {program_id: program.id})
      sheet = ExcelBook.new('test').create_sheet(objectives_exporter.name)
      objectives_exporter.export(sheet)

      assert(File.directory?(File.join(tmp, 'Large descriptions')))
      assert(File.exists?(File.join(tmp, 'Large descriptions', "objective_1_Value Statement(Plain Text).txt")))
      assert(File.exists?(File.join(tmp, 'Large descriptions', "objective_1_Value Statement(HTML).txt")))

      assert_equal 13, sheet.headings.count
      assert_equal program.objectives.all.count + 1, sheet.number_of_rows
      assert_equal ['Number', 'Title', 'Value Statement(Plain Text)', 'Value Statement(HTML)', 'Value', 'Size', 'Created on(UTC)', 'Last modified by', 'Last modified on(UTC)', 'Status', 'Planned start date', 'Planned end date', 'Data exceeding 32767 character limit'], sheet.headings
      row_1 = ['#1','first_objective', "Content too large. Written to file:Large descriptions/objective_1_Value Statement(Plain Text).txt", "Content too large. Written to file:Large descriptions/objective_1_Value Statement(HTML).txt", 50, 60, format_date_with_timestamp(time + 1.minute), 'admin', format_date_with_timestamp(time + 1.minute),'BACKLOG', '', '', "Value Statement(Plain Text)\rValue Statement(HTML)"]
      row_2 = ['#2','second_objective', 'It is a planned objective', '<p>It is a planned objective</p>', 30, 40, format_date_with_timestamp(time + 2.minutes), 'admin', format_date_with_timestamp(time + 2.minute), 'PLANNED', format_date(time), format_date(end_date_for_second_objective)]

      assert_equal row_1, sheet.row(1)
      assert_equal row_2, sheet.row(2)
    end
  end

  def test_should_be_exportable_when_program_have_objectives
    admin = login_as_admin
    program = create_program
    program.objectives.backlog.create!(:name => "first_objective", :value => 50, :size => 60, :value_statement => '<p>very good</p>', :modified_by_user_id => admin.id)
    program.objectives.planned.create!(:name => "second_objective", :value => 30, :size => 40, :value_statement => '<p>It is a planned objective</p>', :modified_by_user_id => admin.id, :start_at => DateTime.now.utc, :end_at => 1.year.from_now)
    objectives_exporter = ObjectivesExporter.new('', {program_id: program.id})
    assert objectives_exporter.exportable?
  end

  def test_should_not_be_exportable_when_program_does_not_have_objectives
    login_as_admin
    program = create_program
    objectives_exporter = ObjectivesExporter.new('', {program_id: program.id})
    assert_false objectives_exporter.exportable?
  end

  private
  def format_date(time)
    time.strftime('%d %b %Y')
  end

  def format_date_with_timestamp(time)
    time.strftime('%d %b %Y  %H:%M')
  end
end
