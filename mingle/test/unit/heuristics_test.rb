# -*- coding: utf-8 -*-

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

class HeuristicsTest < ActiveSupport::TestCase

  def setup
    mock_project = OpenStruct.new(:identifier => "mock_project_identifier")
    @excel_content_file = SwapDir::CardImportingPreview.file(mock_project)
     import = <<-EVAL
       heading1    \tHeading2\tHeading3\tHeading4            \tHeading5
       one         \t1       \tfoo     \t1 person good description\tmore description still
       one         \t2       \tbar bar \t22 people still attending \tstil more description yet
       word another\t3       \tbaz bar \t34                  \tyet more description and then some
     EVAL
    write_content(import)
    @heuristics = Heuristics.new(CardImport::ExcelContent.new(@excel_content_file.pathname))
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_should_not_identify_column_with_all_numbers_if_any_number_is_greater_than_max_int
    import = <<-EVAL
      Heading2\tHeading3\tHeading4            \tHeading5
      1       \tfoo     \t1 person description\tmore description
      5000000000000000000000000000       \tbar bar \t22 people attending \tstil more description
    EVAL

    write_content(import)
    assert_equal nil, @heuristics.index_of(:only_first_column, :number_column)
  end

  def test_should_identify_only_first_column_with_all_numbers
    assert_equal nil, @heuristics.index_of(:only_first_column, :number_column)
  end

  def test_should_identify_column_index_with_at_least_one_space
    assert_equal 0, @heuristics.index_of(:first_non_zero_column, :two_words)
  end

  def test_should_identify_multiple_verbose_columns
    assert_equal [3,4], @heuristics.index_of(:all_columns, :many_words)
  end

  def test_should_be_able_to_identify_a_column_with_a_large_number_of_distinct_values
    content = <<-IMP
    Title\tId\tNumber\tDescription
      This is card 1\tOne\t1\tA B C D
      This is card 2\tTwo+v\t2\tA B C E
      This is card 3\tECB-4031\t3\tA B E D
      This is card 4\tID:4131\t4\tA E C D
      This is card 5\t6 O'Clock\t5\tE B C D
      This is card 6\twhereforth art thou\t6\tF B C D
      This is card 7\tSeven\t7\tA F C D
      This is card 8\tEight\t8\tA B F D
      This is card 9\tNine\t9\tA B C F
      This is card 9\tTen\t10\tA B G D
      This is card 9\tEleven\t11\tA G C D
      This is card 9\tNine\t12\tG B C D
    IMP
    
    write_content(content)
    assert_equal [1, 2], @heuristics.index_of(:diverse_columns, :less_than_three_words)
  end
  
  def test_foo
    assert_equal [1,1,1,1,1], Heuristics.new([]).send(:less_than_three_words, ['One', 'Two+v', 'ECB-4031', 'ID:4131', "6 O'Clock"] )
  end  
  
  def test_should_identify_a_column_with_dates_and_blanks
    content = <<-IMP
    Title\tDate
      This is card 1\t12 Aug 2007
      This is card 2\t
      This is card 3\t13 Oct 2006
    IMP
    write_content(content)
    assert_equal [1], @heuristics.index_of(:all_columns_with_full_match, :date_values)
  end
  
  def test_should_identify_multiple_columns_with_dates
    content = <<-IMP
    Title\tDate\tMore Date
      This is card 1\t12 Aug 2007\t14 Aug 2008
      This is card 3\t13 Oct 2006\t15 Aug 2008
    IMP
    
    write_content(content)
    assert_equal [1, 2], @heuristics.index_of(:all_columns_with_full_match, :date_values)
  end
  
  def test_should_not_identify_a_column_with_a_non_date_value
    content = <<-IMP
    Title\tDate
      This is card 1\t12 Aug 2007
      This is card 2\t40 Jim 1234
    IMP
    
    write_content(content)
    assert_equal [], @heuristics.index_of(:all_columns_with_full_match, :date_values)
  end
  
  def test_should_recognize_columns_with_large_amounts_of_data_as_description
    big_word = 'a' * 256
    chinese_word = "作为财 务 人  员 一 旦通过 银行执行了 支付 指令，我希望可以 标示 交易完成，这样我 可以 保 持  关 于事件 的 精确 纪录 作为财 务 人  员 一 旦通过 银行执行了 支付 指令，我希望可以 标示 交易完成，这样我 可以 保 持"
    content = <<-IMP
      Title\tName\tChinese Title
      #{big_word}\tcard 1\t#{chinese_word}
    IMP
    
    write_content(content)
    assert_equal [0, 2], @heuristics.index_of(:all_columns, :verbose_content)
  end  
  
  def test_should_recognize_empty_columns
    content = <<-IMP
      Title\tEmpty1\tEmpty2\tSomething
      card 1\t\t \tone
      card 2\t\t    \ttwo
    IMP
    
    write_content(content)
    assert_equal [1, 2], @heuristics.index_of(:all_columns_with_full_match, :empty)
  end
  
  def test_should_not_recognize_empty_columns_when_data_is_present_in_any_row
    content = <<-IMPORT
      Title\tNotEmpty\tSomething
      card 1\t \tone
      card 2\ta\ttwo
      card 2\t    \ttwo
    IMPORT
    write_content(content)
    assert_equal [], @heuristics.index_of(:all_columns_with_full_match, :empty)
  end
  
  def test_should_recognize_numeric_columns_even_when_empty_values_exist
    content = <<-IMPORT
      Title\tNumeric
      card 1\t2.5
      card 2\t
      card 2\t     
    IMPORT
    write_content(content)
    assert_equal [1], @heuristics.index_of(:all_columns_with_full_match, :all_numeric)
  end
  
  private
  
  def write_content(content)
    @excel_content_file.write(content)
  end
  
end
