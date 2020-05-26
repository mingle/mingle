#encoding: utf-8

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

class TableTest < ActiveSupport::TestCase
  
  def setup
    login_as_admin
    @project = project_without_cards
    @project.activate
    @export_directory = RailsTmpDir.file_path('test', 'table_test', SecureRandomHelper.random_32_char_hex[0..8])
    FileUtils.mkdir_p(@export_directory)
    @table_name = Card.table_name
  end

  def teardown
    FileUtils.rm_rf(@export_directory)
  end

  def test_multi_page_roundtrip
    cards = create_cards(@project, 24)
    table = ImportExport::TableWithModel.new(@export_directory, @table_name, Card, 10)
    table.write_pages(:select_by_project_sql, @project)
    assert_equal(
      ["#{@table_name}_0.yml", "#{@table_name}_1.yml", "#{@table_name}_2.yml"], 
      Dir[File.join(@export_directory, '*.yml')].collect{|f| File.basename(f)}.sort
    )
    assert_equal  (1..24).to_a, table.collect{|record| record['number'].to_i}.sort
  end
  
  def test_can_read_old_style_import
    cards = create_cards(@project, 2)
    table = ImportExport::TableWithModel.new(@export_directory, @table_name, Card, 10)
    table.write_pages(:select_by_project_sql, @project)
    FileUtils.mv(File.join(@export_directory, "#{@table_name}_0.yml"), File.join(@export_directory, "#{@table_name}.yml"))
    assert_equal  (1..2).to_a, table.collect{|record| record['number'].to_i}.sort
  end

  class DangerousClass
    @@deserialized_by_yaml = false

    def yaml_initialize(tag, val)
      @@deserialized_by_yaml = true
    end

    def self.deserialized_by_yaml
      @@deserialized_by_yaml
    end
  end

  def test_should_not_import_ruby_objects_when_loading_yaml
    table = ImportExport::TableWithModel.new(@export_directory, @table_name, Card)
    file_name = 'test.yml'
    data = "--- !ruby/object:TableTest::DangerousClass {}\n\n"
    File.write(File.join(@export_directory, file_name), data )
    assert_raises Psych::DisallowedClass do
      table.load(file_name)
    end
    assert !DangerousClass.deserialized_by_yaml
  end

  def test_should_import_utf_characters_properly
    table = ImportExport::TableWithModel.new(@export_directory, @table_name, Card)
    file_name = 'test.yml'
    data = <<-EOS
---
- nbsp: "\\xc2\\_"
  euro: "\\xe2\\x82\\xac"
  basic: "basic"
EOS
    File.write(File.join(@export_directory, file_name), data)
    objs = table.load(file_name)

    assert_equal(1, objs.size)
    assert_equal('€', objs[0]['euro'].force_encoding('utf-8'))
    assert_equal('basic', objs[0]['basic'].force_encoding('utf-8'))
    nbsp_char = "\xC2\xA0"
    assert_equal(nbsp_char, objs[0]['nbsp'].force_encoding('utf-8'))
  end

end
