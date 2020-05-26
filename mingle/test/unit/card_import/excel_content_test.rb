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

class ExcelContentTest < ActiveSupport::TestCase

  def setup
    mock_project = OpenStruct.new(:identifier => "mock_project_identifier")
    @excel_content_file = SwapDir::CardImportingPreview.file(mock_project)
    @excel_content = CardImport::ExcelContent.new(@excel_content_file.pathname)
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_asserts_blank_for_missing_files
    assert CardImport::ExcelContent.new('/non_existent_file').blank?
  end

  def test_blank_lines_are_removed_from_file
    raw_content = %{number\ttype\tstatus\titeration\trelease\tpriority

      1\tstory\tnew\t1\t4\tlow
      2\tstory\topen\t2\t3
      \t \t
      3\tbug\topen\t2\t4\tlow
    }

    write_content(raw_content)
    content = @excel_content.cells.collect { |cell_line| cell_line }

    assert_equal [["1", "story", "new", "1", "4", "low"], ["2", "story", "open", "2", "3", nil], ["3", "bug", "open", "2", "4", "low"]], content
  end

  def test_can_iterate_through_columns_with_multiline_descriptions
    raw_content = %{number\ttype\tstatus\titeration\trelease\tdescription\tpriority
      1\tstory\tnew\t1\t4\t\tlow
      2\tstory\topen\t2\t3\t"this is a\nmultiline description"
      3\tbug\topen\t2\t4\tregular description\tlow
    }

    write_content(raw_content)

    columns = {}
    @excel_content.columns.each_with_index do |column, index|
      columns[index] = column
    end

    assert_equal 7, columns.keys.size
    assert_equal ["1", "2", "3"], columns[0]
    assert_equal ["story", "story", "bug"], columns[1]
    assert_equal ["new", "open", "open"], columns[2]
    assert_equal ["1", "2", "2"], columns[3]
    assert_equal ["4", "3", "4"], columns[4]
    assert_equal [nil, "this is a\nmultiline description", "regular description"], columns[5]
    assert_equal ["low", nil, "low"], columns[6]
  end

  def test_can_ignore_lines
    raw_content = %{number\ttype\tstatus\titeration\trelease\tpriority
      1\tstory\tnew\t1\t4\tlow
      2\tstory\topen\t2\t3
      3\tbug\topen\t2\t4\tlow
    }

    write_content(raw_content)
    @excel_content = CardImport::ExcelContent.new(@excel_content_file.pathname, [2])
    content = @excel_content.cells.collect { |cell_line| cell_line }

    assert_equal [["1", "story", "new", "1", "4", "low"], ["3", "bug", "open", "2", "4", "low"]], content
  end

  def test_should_return_header_as_cells
    raw_content = %{number\ttype\tstatus\titeration\trelease\tpriority
      1\tstory\tnew\t1\t4\tlow
      2\tstory\topen\t2\t3
      3\tbug\topen\t2\t4\tlow
    }
    write_content(raw_content)
    assert_equal ["number", "type", "status", "iteration", "release", "priority"], @excel_content.cells.header
  end
  
  def test_can_iterate_through_lines_as_line_objects
    project = first_project
    mock_header = "I am supposed to be an instance of CardImport::Header"
    ignore_fields = []
    raw_content = %{number\ttype\tstatus\titeration\trelease\tpriority
      1\tstory\tnew\t1\t4\tlow
      2\tstory\topen\t2\t3
      3\tbug\topen\t2\t4\tlow
    }
    write_content(raw_content)
    
    lines = @excel_content.lines(project, ignore_fields, mock_header).collect { |line| line }
    
    assert_equal 3, lines.size
    
    assert_equal 1, lines.first.row_number
    assert_equal ["1", "story", "new", "1", "4", "low"], lines.first.values
    assert_equal mock_header, lines.first.headers
    
    assert_equal 2, lines[1].row_number
    assert_equal ["2", "story", "open", "2", "3", nil], lines[1].values
    assert_equal mock_header, lines[1].headers
  end
  
  def test_size_should_return_number_of_content_rows
    raw_content = %{number\ttype\tstatus\titeration\trelease\tpriority
      1\tstory\tnew\t1\t4\tlow
      2\tstory\topen\t2\t3
      3\tbug\topen\t2\t4\tlow
    }
    write_content(raw_content)
    assert_equal 3, @excel_content.size
  end
  
  def test_indexer_of_lines
    project = first_project
    mock_header = "I am supposed to be an instance of CardImport::Header"
    ignore_fields = []
    raw_content = %{number\ttype\tstatus\titeration\trelease\tpriority
      1\tstory\tnew\t1\t4\tlow
      2\tstory\topen\t2\t3
      3\tbug\topen\t2\t4\tlow
    }
    write_content(raw_content)
    
    line_0 = @excel_content.lines(project, ignore_fields, mock_header)[0]
    assert_equal 1, line_0.row_number
    assert_equal ["1", "story", "new", "1", "4", "low"], line_0.values
    assert_equal mock_header, line_0.headers
    
    line_1 = @excel_content.lines(project, ignore_fields, mock_header)[1]
    assert_equal 2, line_1.row_number
    assert_equal ["2", "story", "open", "2", "3", nil], line_1.values
    assert_equal mock_header, line_1.headers
  end
  
  def test_can_get_header_when_content_ends_with_tab
    import = %{Number	Name	Description	a b	
      1	card 1	description	a	}
    write_content(import)
    assert_equal ["Number", "Name", "Description", "a b"], @excel_content.cells.header
  end
  
  def test_blank
    write_content(%{number\ttype
      1\tstory
    })
    assert !@excel_content.blank?
    
    write_content("")
    assert @excel_content.blank?
    
    write_content(" \n\t \n")
    assert @excel_content.blank?
  end
  
  def test_should_handle_fields_with_newlines_if_quoted
    raw_content = %{type\tname\tdescription
    story\tsomename\tdesc
    card\tothername\t"description\nwith newline"
    story\tthreename\tanotherdesc
    }
    write_content(raw_content)
    content = @excel_content.cells.collect { |cell_line| cell_line }
    
    assert_equal ["type", "name", "description"], @excel_content.cells.header
    assert_equal ["story", "somename", "desc"], content[0]
    assert_equal ["card", "othername", "description\nwith newline"], content[1]
  end
  
  def test_can_handle_first_line_being_blank
    raw_content = %{
      num\tname\tdescription\tstatus
      5\tStory 5\tAdd new product\tstatus-new
      6\tStory 6\tAdd new admin\tupdate
    }
    write_content(raw_content)
    content = @excel_content.cells.collect { |cell_line| cell_line }
    assert_equal ["num", "name", "description", "status"], @excel_content.cells.header
    assert_equal ["5", "Story 5", "Add new product", "status-new"], content[0]
    assert_equal ["6", "Story 6", "Add new admin", "update"], content[1]
  end
  
  def test_can_sort_lines_by_card_type_order_in_tree
    with_three_level_tree_project do |project|
      ignore_fields = []
      raw_content = %{number\ttype\tname
        10\tstory\thi there
        11\trelease\twhoa yeah
        12\titeration\thephep
      }
      write_content(raw_content)
      
      card_reader = CardImport::CardReader.new(project, @excel_content, nil, User.current, nil)
      header = CardImport::Header.new(["number", "type", "name"], card_reader)
      
      sorted_lines = []
      @excel_content.lines(project, ignore_fields, header).each_sorted_by_card_type(project.tree_configurations.first) { |line| sorted_lines << line }
      
      assert_equal 3, sorted_lines.size
      assert_equal ["11", "release", "whoa yeah"], sorted_lines[0].values
      assert_equal ["12", "iteration", "hephep"], sorted_lines[1].values
      assert_equal ["10", "story", "hi there"], sorted_lines[2].values
      
      # need to maintain the pre-sorted row numbers so that error messages can refer to them
      assert_equal [2, 3, 1], sorted_lines.map(&:row_number)
    end
  end
  
  def test_should_not_blow_up_if_only_header_is_provided
    raw_content = "testing stuff"
    write_content(raw_content)
    
    lines = []
    @excel_content.cells.each(:yield_header => true) { |cell_line| lines << cell_line }
    assert_equal [["testing stuff"]], lines
    
    columns = {}
    @excel_content.columns.each_with_index do |column, index|
      columns[index] = column
    end
    assert_equal 0, columns.keys.size
  end
  
  def test_can_get_raw_content_back_from_excel_content
    raw_content = %{number\ttype\tdescription\tstatus
      1\tstory\t"Some\ndescription with a new line"\tnew
      2\tstory\tOther description\topen
      3\tbug\t  \topen
    }
    write_content(raw_content)
    assert_equal raw_content, @excel_content.raw_content
  end
  
  def test_double_newlines_within_quotes_are_preserved
    raw_content = %{number\ttype\tdescription\tstatus
      1\tstory\t"Some\n\ndescription\n\nwith double new lines"\tnew
      2\tstory\tOther description\topen
      3\tbug\t  \topen
    }
    write_content(raw_content)
    cell_lines = @excel_content.cells.map { |cell_line| cell_line }
    assert_equal ["1", "story", "Some\n\ndescription\n\nwith double new lines", "new"], cell_lines[0]
  end
  
  def test_single_newline_within_header_is_preserved
    raw_content = %{number\ttype\tdescription\t"sta\ntus"
      1\tstory\t"Some description"\tnew
      2\tstory\tOther description\topen
      3\tbug\t  \topen
    }
    write_content(raw_content)
    assert_equal ["number", "type", "description", "sta\ntus"], @excel_content.cells.header
  end
  
  def write_content(content)
    @excel_content_file.write(content)
  end
  
end
