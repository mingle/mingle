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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class StringExtTest < ActiveSupport::TestCase

  def test_shorten
    assert_equal("1234501b3", "1234567890".shorten(9, 4))
    assert_equal("1234567890", "1234567890".shorten(10))
    assert_raise RuntimeError do
      "1234567890".shorten(4)
    end
  end

  def test_strip_all
    assert_equal("", "".strip_all)
    assert_equal("", "\t\n\r ".strip_all)
    assert_equal("x", "x".strip_all)
    assert_equal("x", "\t\n\r x\t\n\r ".strip_all)
    assert_equal("xx", "\t\n\r x\t\n\r x\t\n\r ".strip_all)
    assert_equal("xxx", "x\n\nx\n\nx".strip_all)
    value = "x\n\t x"
    value.strip_all!
    assert_equal('xx', value)
  end

  def test_non_numeric_strings
    assert !"".numeric?
    assert !"a".numeric?
    assert !"1a".numeric?
    assert !"-".numeric?
    assert !".".numeric?
    assert !"-.".numeric?
    assert !",".numeric?
    assert !"1.x".numeric?
    assert !"x.1".numeric?
    assert !"1..".numeric?
    assert !"..1".numeric?
    assert !"1.2.1".numeric?
  end

  def test_numeric_strings
    assert "1".numeric?
    assert "-1".numeric?
    assert "1.1".numeric?
    assert "-1.1".numeric?
    assert ".1".numeric?
    assert "-.1".numeric?
    assert "1.5e8".numeric?
  end

  def test_starts_with
    assert "abc".starts_with?('a')
    assert "abc".starts_with?('ab')
    assert !"abc".starts_with?('A')
    assert !"abc".starts_with?('abcd')
    assert !"abc".starts_with?('b')
  end

  def test_truncate_with_ellipses
    assert_equal 'Short', 'Short'.truncate_with_ellipses(10)
    assert_equal 'This wi...', 'This will be truncated'.truncate_with_ellipses(10)
    assert_equal 'A bit ...', 'A bit longer'.truncate_with_ellipses(9)
    assert_equal 10, 'This will be truncated'.truncate_with_ellipses(10).length
  end

  def test_to_num
    assert_equal '1', '1.0'.to_num.to_s
    assert_equal '1.0', '1.004'.to_num(2).to_s
    assert_equal '1.01', '1.005'.to_num(2).to_s
    assert_equal '2.0', '1.995'.to_num(2).to_s
    assert_equal '1.9', '1.90'.to_num(2).to_s
  end

  def test_plural_adjective
    assert_equal 'this', 'this'.plural_adjective(1)
    assert_equal 'these', 'this'.plural_adjective(2)
  end

  def test_plural
    assert_equal 'card', 'card'.plural(1)
    assert_equal 'cards', 'card'.plural(2)
    assert_equal 'cards', 'card'.plural(0)
  end

  def test_md5
    assert_equal Digest::MD5.hexdigest('ABC').to_s, 'ABC'.md5
  end

  def test_sha2
    assert_equal Digest::SHA256.hexdigest('ABC').to_s, 'ABC'.sha2
  end

  def test_sha1
    assert_equal Digest::SHA1.hexdigest('ABC').to_s, 'ABC'.sha1
  end

  def test_enumerate
    assert_equal "1 card",  "cards".enumerate(1)
    assert_equal "2 cards", "cards".enumerate(2)
  end

  def test_unquote
    assert_equal "linc", "'linc'".unquote
    assert_equal "linc", "\"linc\"".unquote
    assert_equal "'linc\"", "'linc\"".unquote
  end

  def test_unescape_quote
    assert_equal "\"linc", "\\\"linc".unescape_quote
    assert_equal "'linc", "\'linc".unescape_quote
  end

  def test_is_boolean_value
    assert 'true'.is_boolean_value?
    assert 'false'.is_boolean_value?
    assert_equal false, 'blah'.is_boolean_value?
    assert_equal false, ''.is_boolean_value?
  end

  def test_compare_strings_case_insensitively
    assert 'AbC'.ignore_case_equal?('abc')
  end

  def test_compare_strings_case_insensitively_with_unicode_characters
    assert 'áÈß'.ignore_case_equal?('áèß')
  end

  def test_uniquify_with_succession_without_truncation
    assert_equal "foo", "foo".uniquify_with_succession(100) { |str| false }
    assert_equal "foo1", "foo".uniquify_with_succession(100) { |str| str == "foo" }
    assert_equal "foo10", "foo".uniquify_with_succession(100) { |str| str =~ /foo\d?$/ }
  end

  def test_uniquify_with_succession_with_truncation
    assert_equal "foo", "foo".uniquify_with_succession(3) { |str| false }
    assert_equal "fo1", "foo".uniquify_with_succession(3) { |str| str == "foo" }
    assert_equal "f10", "foo".uniquify_with_succession(3) { |str| str =~ /fo(o|\d)/ }
    assert_equal "f100", "fooo".uniquify_with_succession(4) { |str| str =~ /fo(o|\d)(o|\d)/ }

    assert_equal "fooo1", "foooooooooooo".uniquify_with_succession(5) { |str| str == "foooo" }
    assert_equal "fo", "foo".uniquify_with_succession(2) { |str| false }
    assert_equal "f1", "foo".uniquify_with_succession(2) { |str| str == "fo" }
  end

  def test_uniquify_with_succession_with_suffix
    assert_equal "foosuf1", "foo".uniquify_with_succession(7, "suf") { |str| str == "foosuf"}
    assert_equal "fosuf1", "foo".uniquify_with_succession(6, "suf") { |str| str == "foosuf"}
  end
end
