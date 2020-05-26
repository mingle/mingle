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

class ExcelParserTest < ActiveSupport::TestCase
  
  def test_should_know_number_of_lines_in_content_without_final_return
    assert_equal 2, parse(%{
      cell1\tcell2
      cell3\tcell4}).size
  end 
  
  def test_should_know_number_of_lines_in_content
    assert_equal 2, parse(%{
      cell1\tcell2
      cell3\tcell4
    }).size
  end   
  
  def test_should_know_number_of_cells_in_content
    assert_equal 3, parse(%{
      cell1\tcell2\tanother_header
      cell3\tcell4\tcell5
      cell6\tcell7
    })[1].size
  end  

  def test_should_know_contents_of_a_line_without_final_return
    assert_equal ["cell3","cell4","cell5"], parse(%{
     cell1\tcell2\theader_cell
     cell3\tcell4\tcell5})[1]
  end  
  
  def test_should_know_contents_of_a_line
    assert_equal ["cell3","cell4","cell5"], parse(%{
     cell1\tcell2\theader
     cell3\tcell4\tcell5
    })[1]
  end  
  
  def test_should_preserve_newlines_in_quoted_values
    assert_equal ["cell1", "cell2a\ncell2b"], parse(%{
      cell1\t"cell2a\ncell2b"
    })[0]
  end  
  
  def test_should_preserve_quotes_in_unescaped_values
    assert_equal ["Willy Wonka", "says Hello \"W\"orld"], parse(%{
      Willy Wonka\tsays Hello "W"orld
      Next line\twith content
    })[0]
  end    
  
  def test_csv_style_escaped_quotes_follow_with_newline
    assert_equal ["Willy Wonka", "says Hello \"\nW\"orld"], parse(%{
      Willy Wonka\t"says Hello ""\nW""orld"\r\nNext line\twith content
    })[0]
  end    
  
  def xxxtest_unbalanced_quote #is this a realistic scenario?
    assert_equal ["Willy Wonka", "says Hello ''W\"orld"], parse(%{
      Willy Wonka\tsays Hello ''W"orld\r\nNext line\twith content
    })[0]
  end
  
  def test_should_preserve_newlines_and_escaped_quotes
    assert_equal ["Willy Wonka", "says Hello\n\"W\"orld"], parse(%{
      Willy Wonka\t"says Hello\n""W""orld"
      empty\t\tcells
    })[0]
  end
  
  def test_trailing_char
    assert_equal ["Willy Wonka", "says Hello\n\"W\"orld"], parse(%{
      Willy Wonka\t"says Hello\n""W""orld"
      empty\t\tcells
    })[0]    
  end
  
  def test_should_preserve_newlines_and_escaped_quotes_with_leading_and_trailing_spaces
    assert_equal ["Willy Wonka", "says Hello\n\"W\"orld"], parse(%{
      Willy Wonka\t\s\s"says Hello\n""W""orld"\s\s\s
      empty\t\tcells
    })[0]
  end  
  
  def test_should_newlines_and_quotes_near_the_end_of_content
    assert_equal ["Willy Wonka", nil, "says Hello\n\"W\"orld"], parse(%{
      empty\t\tcells
      Willy Wonka\t\t\s\s\s"says Hello\n""W""orld"\s\s\s
    })[1]
  end
  
  #bug 1965
  def test_should_not_split_into_many_lines_if_fields_start_with_carriage_returns
    content_line = parse(%{sss\t"\n\nsnake"})[0]
    assert_equal "sss", content_line[0]
    assert_equal "\n\nsnake", content_line[1]
  end  
  
  def test_encounter_quotes_at_the_end_of_cell
    assert_equal ["287", "Change \"Avg/night\" to \"Per night\"", "component1", 'closed'], parse(%{
      ticket\tsummary\tcomponent\tstatus
      287\tChange "Avg/night" to "Per night"\tcomponent1\tclosed
    })[1]
  end  
  
  
  def test_encounter_quotes_at_the_end_of_line
    assert_equal ["287", "component1", 'closed', "Change \"Avg/night\" to \"Per night\""], parse(%{
      ticket\tcomponent\tstatus\tsummary
      287\tcomponent1\tclosed\tChange "Avg/night" to "Per night"
    })[1]
  end  
  
  def test_conent_rows_get_padded_with_nils_if_smaller_than_header
    assert_equal ["Cell1", "Cell2", nil, nil], parse(%{
      Head1\tHead2\tHead3\tHead4
      Cell1\tCell2
    })[1]
  end  
  
  def test_conent_rows_get_truncated_if_smaller_than_header
    assert_equal ["Cell1", "Cell2"], parse(%{
      Head1\tHead2
      Cell1\tCell2\t\t
    })[1]
  end  
  
  def test_should_only_return_as_many_columns_in_subsequent_rows_as_are_in_first_row
    blank_string = ''
    first_line, *other_lines = parse(%{
      Number\tName\tDescription\t#{blank_string}
      5\tStory 5\tAdd new product new 
      6\tStory 6\tAdd new admin update
    })
    assert_equal 3, first_line.size
    other_lines.each { |line| assert_equal first_line.size, line.size }
  end 
  
  def test_should_not_strip_out_leading_space_in_quoted_cells
    cell2 = parse(%{
      cell1\t"    foo\n    bar\n    baz"\tcell3
    })[0][1]
    assert_equal "    foo\n    bar\n    baz", cell2
  end  
  
  def parse(contents)
    CardImport::ExcelParser.parse(contents)
  end  
end

