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

class MurmurExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    assert MurmurExporter.new('').exports_to_sheet?
    assert_equal 'Murmurs', MurmurExporter.new('').name
  end

  def test_sheet_should_contain_correct_murmurs_data
    login_as_admin
    with_new_project do |project|
      card = create_card!(:number => 7, :name => 'card seven', :card_type_name => 'Card')
      card.add_comment :content => "#7 is great"
      card_murmur = find_murmur_from(card)
      default_murmur = create_murmur(:murmur => "I am a default type murmur", :created_at => "24 Jul 2018 11:00 IST")

      murmur_exporter = MurmurExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(murmur_exporter.name)
      murmur_exporter.export(sheet)

      assert_equal 5, sheet.headings.count
      assert_equal Murmur.all.count + 1, sheet.number_of_rows
      assert_equal ['Murmur', 'Timestamp', 'User', 'Card', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal [card_murmur.murmur, project.format_time(card_murmur.created_at), card_murmur.author.name, card_murmur.origin_type_description], sheet.row(1)
      assert_equal [default_murmur.murmur, project.format_time(default_murmur.created_at), default_murmur.author.name, default_murmur.origin_type_description], sheet.row(2)
    end
  end

  def test_should_be_exportable_when_project_have_murmurs
    login_as_admin
    with_new_project do
      card = create_card!(:number => 7, :name => 'card seven', :card_type_name => 'Card')
      card.add_comment :content => "#7 is great"
      create_murmur(:murmur => "I am a default type murmur", :created_at => "24 Jul 2018 11:00 IST")

      murmur_exporter = MurmurExporter.new('')

      assert murmur_exporter.exportable?
    end
  end

  def test_should_be_exportable_when_project_does_not_have_murmurs
    login_as_admin
    with_new_project do
      murmur_exporter = MurmurExporter.new('')
      assert_false murmur_exporter.exportable?
    end
  end

  def test_sheet_should_export_large_murmur_data_into_separate_text_file
    login_as_admin
    with_new_project do |project|
      create_card!(:number => 7, :name => 'card seven', :card_type_name => 'Card')
      default_murmur = create_murmur(:murmur => "I am a large murmur #{ "aaa" * 11000 }", :created_at => "24 Jul 2018 11:00 IST")
      tmp_dir = RailsTmpDir::RailsTmpFileProxy.new('exports').pathname
      murmur_exporter = MurmurExporter.new(tmp_dir)
      sheet = ExcelBook.new('test').create_sheet(murmur_exporter.name)
      murmur_exporter.export(sheet)

      assert_equal 5, sheet.headings.count
      assert_equal Murmur.all.count + 1, sheet.number_of_rows
      assert_equal ['Murmur', 'Timestamp', 'User', 'Card', 'Data exceeding 32767 character limit'], sheet.headings
      large_murmur_place_holder = "Content too large. Written to file:Large descriptions/Murmur - #{default_murmur.id}_Murmur.txt"
      expected_row_data = [large_murmur_place_holder, project.format_time(default_murmur.created_at), default_murmur.author.name, default_murmur.origin_type_description, 'Murmur']
      assert_equal expected_row_data, sheet.row(1)

      large_murmur_file_path = File.join(tmp_dir, 'Large descriptions', "Murmur - #{default_murmur.id}_Murmur.txt")
      assert File.exists?(large_murmur_file_path)
      assert_equal default_murmur.murmur, File.read(large_murmur_file_path)
    end
  end

  def test_should_export_non_murmur_comment
    login_as_admin
    time = DateTime.now
    with_new_project(time_zone: 'London', date_format: '%Y/%d/%m') do |project|
      card_1 = create_card!(:number => 1, :name => 'card 1', :card_type_name => 'Card')
      card_2 = create_card!(:number => 2, :name => 'card 2', :card_type_name => 'Card')
      card_1.add_comment :content => "Similar murmur"
      Timecop.travel(time + 10.minutes) do
        card_2.add_comment :content => "Similar murmur"
      end
      Timecop.travel(time + 1.days) do |x|
        card_1.add_comment :content => "Admin 1st murmur"
        login_as_longbob
        Timecop.travel(time + 1.days + 2.minutes) do
          card_1.add_comment :content => "longbob's reply to Admin 1st murmur"
        end
      end
      Timecop.travel(time + 2.days) do |x|
        login_as_bob
        card_1.add_comment :content => "bob's 1st comment without murmur"
      end
      login_as_admin

      card_1.add_comment :content => "Admin final comment without murmur"


      first_murmur = Murmur.all.first
      second_murmur = Murmur.all.second
      third_murmur = Murmur.all.third
      fourth_murmur = Murmur.all.fourth
      fifth_murmur = Murmur.all.fifth
      sixth_murmur = Murmur.all[5]

      first_murmur_data = [first_murmur.murmur, project.format_time(first_murmur.created_at), first_murmur.author.name, first_murmur.origin_type_description]
      second_murmur_data = [second_murmur.murmur, project.format_time(second_murmur.created_at), second_murmur.author.name, second_murmur.origin_type_description]
      third_murmur_data = [third_murmur.murmur, project.format_time(third_murmur.created_at), third_murmur.author.name, third_murmur.origin_type_description]
      fourth_murmur_data = [fourth_murmur.murmur, project.format_time(fourth_murmur.created_at), fourth_murmur.author.name, fourth_murmur.origin_type_description]
      fifth_murmur_data = [fifth_murmur.murmur, project.format_time(fifth_murmur.created_at), fifth_murmur.author.name, fifth_murmur.origin_type_description]
      sixth_murmur_data = [sixth_murmur.murmur, project.format_time(sixth_murmur.created_at), sixth_murmur.author.name, sixth_murmur.origin_type_description]
      fifth_murmur.delete
      sixth_murmur.delete

      tmp_dir = RailsTmpDir::RailsTmpFileProxy.new('exports').pathname
      murmur_exporter = MurmurExporter.new(tmp_dir)
      sheet = ExcelBook.new('test').create_sheet(murmur_exporter.name)
      murmur_exporter.export(sheet)

      assert_equal 5, sheet.headings.count
      assert_equal 7, sheet.number_of_rows
      assert_equal ['Murmur', 'Timestamp', 'User', 'Card', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal fourth_murmur_data, sheet.row(1)
      assert_equal third_murmur_data, sheet.row(2)
      assert_equal first_murmur_data, sheet.row(3)
      assert_equal second_murmur_data, sheet.row(4)
      assert_equal sixth_murmur_data, sheet.row(5)
      assert_equal fifth_murmur_data, sheet.row(6)
    end
  end

end
