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

class CardQueryLexerTest < ActiveSupport::TestCase
  
  def test_should_take_number_as_identifier
    assert_equal [[:IDENTIFIER, "chapter"], [:IDENTIFIER, "2.2"]], tokenlize(%{ chapter 2.2 })
  end
  
  def test_should_take_empty_string_as_identifier
    assert_equal [[:IDENTIFIER, ""]], tokenlize(%{ '' })
  end
  
  def test_push_single_word_should_appear_as_idenfitier
    assert_equal [[:IDENTIFIER, "hello"]], tokenlize(%{ hello })
  end
  
  def test_should_connect_quoted_string_parts_splited_by_escaped_quote
    assert_equal [[:IDENTIFIER, "hello\'world"]], tokenlize(%{ hello\\'world })
    assert_equal [[:IDENTIFIER, "hello\"world"]], tokenlize(%{ hello\\"world })
  end
  
  def test_mix_unescaped_single_and_double_quotes
    assert_equal [[:IDENTIFIER, "hello\'world"]], tokenlize(%{ "hello'world" })
    assert_equal [[:IDENTIFIER, "hello\"world"]], tokenlize(%{ 'hello"world' })    
  end
  
  def test_escaped_quotes_as_start_or_end_of_word
    assert_equal [[:IDENTIFIER, "hello\'"], [:IDENTIFIER, "world"]], tokenlize(%{ hello\\' world })
    assert_equal [[:IDENTIFIER, "hello"], [:IDENTIFIER, "\'world"]], tokenlize(%{ hello \\'world })
    assert_equal [[:IDENTIFIER, "hello"], [:IDENTIFIER, "'"], [:IDENTIFIER, "world"]], tokenlize(%{ hello \\' world })
  end
  
  def test_should_take_words_between_quotes_as_identifier_token
    assert_equal [[:IDENTIFIER, "hello world"]], tokenlize(%{ 'hello world' })
    assert_equal [[:IDENTIFIER, "hello world"]], tokenlize(%{ "hello world" })
  end
  
  def test_should_take_number_as_identifier
    assert_equal [[:IDENTIFIER, '2.2']], tokenlize(%{ 2.2 })
  end
  
  def test_mixed_number_word_and_escaped_quote
    assert_equal [[:IDENTIFIER, '2'], [:IDENTIFIER, 'words'], [:IDENTIFIER, "hello'world"]], 
      tokenlize(%{ 2 "words" hello\\'world })
  end
  
  def test_escaped_quote_in_middle_of_quoted_identifier_should_not_break_it
    assert_equal [[:IDENTIFIER, "hello' world"]], tokenlize(%{ 'hello\\' world' })
    assert_equal [[:IDENTIFIER, "hello' wor'ld"]], tokenlize(%{ 'hello\\' wor\\'ld' })
    assert_equal [[:IDENTIFIER, "hello\" world"]], tokenlize(%{ "hello\\" world" })
    assert_equal [[:IDENTIFIER, "hello\" wor\"ld"]], tokenlize(%{ "hello\\" wor\\"ld" })
  end

  module ParserAsLexerMocking
    attr_accessor :lexer_tokens
    def yyparse(recv, mid)
      self.lexer_tokens = recv
      lexer_tokens.pop
      lexer_tokens
    end
  end
  
  def tokenlize(str)
    parser = CardQueryParser.new
    parser.extend(ParserAsLexerMocking)
    parser.parse(str)
    parser.lexer_tokens
  end
end
