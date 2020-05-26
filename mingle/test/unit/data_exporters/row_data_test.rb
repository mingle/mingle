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

class RowDataTest < ActiveSupport::TestCase

  def test_should_add_column_size_header_to_existing_headers_when_external_file_data_possible_true
    row_data = RowData.new('', %w(first second third), true)
    assert_equal(['first', 'second', 'third', 'Data exceeding 32767 character limit'], row_data.header_names)
  end

  def test_should_not_add_column_size_header_to_existing_headers_by_default
    row_data = RowData.new('', %w(first second third))
    assert_equal(%w(first second third), row_data.header_names)
  end

  def test_should_not_add_column_size_header_to_existing_headers_when_external_file_data_possible_false
    row_data = RowData.new('', %w(first second third), false)
    assert_equal(%w(first second third), row_data.header_names)
  end

  def test_should_retain_column_cells_when_chars_less_than_32750
    row_data = RowData.new('', %w(first second third))
    assert_equal(['data 1', 'data 2', 'data 3'], row_data.cells(['data 1', 'data 2', 'data 3']))
  end

  def test_should_retain_column_cells_when_chars_equal_or_less_than_32750_and_external_file_data_possible_true
    long_cell_data = generate_random_string(32750)
    row_data = RowData.new('', %w(first second third), true)
    assert_equal(['data 1', 'data 2', long_cell_data], row_data.cells(['data 1', 'data 2', long_cell_data]))
  end

  def test_should_retain_data_cells_when_external_file_data_possible_false
    long_cell_data = generate_random_string(32758)
    row_data = RowData.new('', %w(first second third), false)
    assert_equal(['data 1', 'data 2', long_cell_data], row_data.cells(['data 1', 'data 2', long_cell_data]))
  end

  def test_should_remove_data_cells_and_place_in_file_when_chars_greater_than_32750_and_external_file_data_possible_true
    with_temp_dir do |tmp|
      large_cell_data = generate_random_string(32751)
      row_data = RowData.new(tmp, %w(first second last), true)
      data_cells = row_data.cells(['first cell', large_cell_data, 'last cell'], 'card-24-foo')
      assert_equal(4, data_cells.size)
      assert_equal(['first cell', 'Content too large. Written to file:Large descriptions/card-24-foo_second.txt', 'last cell', 'second'], data_cells)

      cell_data_dir = File.join(tmp, 'Large descriptions')
      cell_data_file = File.join(tmp, 'Large descriptions', 'card-24-foo_second.txt')
      assert(File.directory?(cell_data_dir))
      assert(File.exists?(cell_data_file))
      assert_equal(large_cell_data, File.read(cell_data_file))
    end
  end

  def test_should_remove_data_cells_and_place_in_file_when_chars_greater_than_32750_on_multuple_cells_and_external_file_data_possible_true
    with_temp_dir do |tmp|
      large_cell_data1 = generate_random_string(32751)
      large_cell_data2 = generate_random_string(33000)
      row_data = RowData.new(tmp, %w(first second third fourth fifth), true)
      data_cells = row_data.cells(['first data', large_cell_data1, 3, large_cell_data2, 'fifth data'], 'card-14-foo')
      assert_equal(6, data_cells.size)
      assert_equal(['first data', 'Content too large. Written to file:Large descriptions/card-14-foo_second.txt', 3, 'Content too large. Written to file:Large descriptions/card-14-foo_fourth.txt', 'fifth data', "second\rfourth"], data_cells)


      cell_data_dir = File.join(tmp, 'Large descriptions')
      cell_data_file1 = File.join(tmp, 'Large descriptions', 'card-14-foo_second.txt')
      cell_data_file2 = File.join(tmp, 'Large descriptions', 'card-14-foo_fourth.txt')
      assert(File.directory?(cell_data_dir))
      assert_equal(large_cell_data1, File.read(cell_data_file1))
      assert_equal(large_cell_data2, File.read(cell_data_file2))
    end
  end

end
