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

class BufferTest < ActiveSupport::TestCase
  
  def setup
    @buffer = CardImport::Buffer.new
  end  
  
  def test_should_retrieve_complete_word_after_pushing_cell_boundary_into_buffer
    @buffer << 'c'.ord << 'a'.ord << 't'.ord << "\t".ord
    assert 'cat', @buffer.value
  end  
  
  def test_should_retrieve_value_without_spaces
    @buffer << 'c'.ord << 'a'.ord << 't'.ord << "\s".ord << "\s".ord << "\t".ord
    assert 'cat', @buffer.value
  end  
  
  def test_should_return_nil_if_value_is_blank
    @buffer << "\s".ord << "\s".ord << "\s".ord << "\s".ord << "\s".ord << "\t".ord
    assert_nil @buffer.value
  end  
  
  def test_should_return_nil_value_if_does_not_have_value
    @buffer << 'c'.ord << 'a'.ord << 't'.ord
    assert_nil @buffer.value
  end  
  
  def test_should_get_full_when_null_is_pushed_into_buffer
    @buffer << 'c'.ord << 'a'.ord << 't'.ord << nil
    assert_equal 'cat', @buffer.value
  end  
  
  def test_should_respond_true_has_value_when_complete_word_is_present
    @buffer << 'c'.ord << 'a'.ord << 't'.ord
    assert !@buffer.has_value?
    @buffer << "\t".ord
    assert @buffer.has_value?
  end  
  
  def test_should_return_last_pushed_character_for_current
    @buffer << 'c'.ord << 'a'.ord
    assert_equal 'a'.ord, @buffer.current
  end  

  def test_should_return_nil_for_current_if_has_value
    @buffer << 'c'.ord << 'a'.ord << 't'.ord << "\t".ord
    assert_nil @buffer.current
  end

  def test_should_return_escaped_value
    @buffer << 'q'.ord << 'u'.ord << '"'.ord << 'o'.ord << 't'.ord << '"'.ord << 'e'.ord << 'd'.ord << "\t".ord
    assert_equal "qu\"ot\"ed", @buffer.value
  end

  def test_should_return_value_even_if_quotes_are_unbalanced
    @buffer << 'q'.ord << 'u'.ord << '"'.ord << 'o'.ord << '"'.ord << 't'.ord << '"'.ord << 'e'.ord << 'd'.ord << "\t".ord
    assert_equal "qu\"o\"t\"ed", @buffer.value
  end  

  def test_should_complete_value_if_new_line_is_reached
    @buffer << 'e'.ord << 'n'.ord << 'd'.ord << "\n".ord
    assert_equal "end", @buffer.value
  end  

  def test_should_preserve_carriage_returns_in_cell_contents
    @buffer << 'q'.ord << 'u'.ord << '"'.ord << 'o'.ord << "\n".ord << 't'.ord << '"'.ord << 'e'.ord << 'd'.ord << "\t".ord
    assert_equal "qu\"o\nt\"ed", @buffer.value
  end
end  
