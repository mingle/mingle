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

class HtmlSanitizerTest < ActiveSupport::TestCase

  def setup
    @html_sanitizer = HtmlSanitizer.new
  end

  def test_should_extend_rails_html_white_list_sanitizer
    assert @html_sanitizer.is_a? Rails::Html::WhiteListSanitizer
  end

  def test_should_remove_style_tag_and_its_content
    html_text = "<div>Hello</div><style> div{color:red;}</style>"
    expected_sanitized_html =  "<div>Hello</div>"
    actual_sanitized_html = @html_sanitizer.sanitize html_text

    assert_equal expected_sanitized_html, actual_sanitized_html
  end

  def test_should_not_remove_table_tag
    html_text = "<div>Hello</div><table><thead><tr><th>Head</th></tr></thead><tbody><tr><td>Value</td></tr></tbody></table>"
    actual_sanitized_html = @html_sanitizer.sanitize html_text

    assert_equal html_text, actual_sanitized_html
  end

  def test_should_have_allowed_attributes_from_parent_and_style_attribute
    assert_equal Rails::Html::WhiteListSanitizer.allowed_attributes + %w(style), HtmlSanitizer.allowed_attributes
  end

  def test_should_have_allowed_tags_from_parent
    expected_allowed_tags = Rails::Html::WhiteListSanitizer.allowed_tags + %w(table tbody thead th tr td)
    assert_equal expected_allowed_tags, HtmlSanitizer.allowed_tags
  end

end
