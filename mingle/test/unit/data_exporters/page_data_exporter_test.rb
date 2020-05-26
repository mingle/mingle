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

class PageDataExporterTest <  ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    with_new_project do
      assert PageDataExporter.new('').exports_to_sheet?
      assert_equal 'Pages', PageDataExporter.new('').name
    end
  end

  def test_sheet_should_contain_correct_page_data
    login_as_admin
    with_new_project do |project|
      page_one = project.pages.create!(:name => 'first test page', :content => '<p>this is the content {{  test-macro  }} of  {{ abc }}the page {{ abc }}</p>')
      page_two = project.pages.create!(:name => 'second test page', :content => '')
      page_two.attach_files(sample_attachment('attachment1.jpg'),sample_attachment('attachment2.jpg'))
      page_two.save!

      large_page3_content = generate_random_string(36900)
      page_three = project.pages.create!(:name => 'third test page', :content => large_page3_content)
      page_one.tag_with(['important', 'not so important'])
      page_one.save!

      Favorite.create!(:project_id => project.id, :favorited_type => Page.name, :favorited_id => page_one.id, :tab_view => true)
      Favorite.create!(:project_id => project.id, :favorited_type => Page.name, :favorited_id => page_two.id, :tab_view => false)

      page_data_exporter = PageDataExporter.new(RailsTmpDir::RailsTmpFileProxy.new('exports').pathname)
      sheet = ExcelBook.new('test').create_sheet(page_data_exporter.name)
      page_data_exporter.export(sheet)

      assert_equal 10, sheet.headings.count
      assert_equal project.pages.all.count + 1, sheet.number_of_rows
      assert_equal ['Title', 'Description(Plain text)',	 'Description(HTML)', 'Tags', 'Tab',	'Team favorite', 'Attachments', 'Has macros', 'Charts and macros', 'Data exceeding 32767 character limit'], sheet.headings
      assert_equal [page_one.name,'this is the content {{  test-macro  }} of  {{ abc }}the page {{ abc }}',
                             page_one.content, 'important, not so important', 'Y', 'N','', 'Y', ['1 Test macro', '2 Abcs'].join(CardExport::LIST_ITEM_EXPORT_SEPARATOR) ], sheet.row(1)
      page_two_attachments = page_two.reload.attachments.map {|attachment| "Attachments/second test page/#{attachment.file_name}"}.join(CardExport::LIST_ITEM_EXPORT_SEPARATOR)
      assert_equal [page_two.name, '', page_two.content, '', 'N', 'Y', page_two_attachments, 'N', ''], sheet.row(2)
      assert_equal [page_three.name, "Content too large. Written to file:Large descriptions/third test page_#{page_three.id}_Description(Plain text).txt", "Content too large. Written to file:Large descriptions/third test page_#{page_three.id}_Description(HTML).txt", '', 'N', 'N','', 'N', '', "Description(Plain text)\rDescription(HTML)"], sheet.row(3)
      assert_equal "#{MingleConfiguration.site_url}/projects/#{project.identifier}/wiki/#{page_one.identifier}", sheet.cell_link_address(1,0)
      assert_equal "#{MingleConfiguration.site_url}/projects/#{project.identifier}/wiki/#{page_two.identifier}", sheet.cell_link_address(2,0)
      assert_equal "#{MingleConfiguration.site_url}/projects/#{project.identifier}/wiki/#{page_three.identifier}", sheet.cell_link_address(3,0)
    end
  end

  def test_should_be_exportable_when_project_have_pages
    login_as_admin
    with_new_project do |project|
      project.pages.create!(:name => 'first test page', :content => '<p>this is the content {{  test-macro  }} of  {{ abc }}the page {{ abc }}</p>')
      page_data_exporter = PageDataExporter.new(RailsTmpDir::RailsTmpFileProxy.new('exports').pathname)

      assert page_data_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_project_does_not_have_pages
    login_as_admin
    with_new_project do
      page_data_exporter = PageDataExporter.new(RailsTmpDir::RailsTmpFileProxy.new('exports').pathname)

      assert_false page_data_exporter.exportable?
    end
  end

end
