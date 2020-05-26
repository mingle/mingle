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

class ManuallyEnteredBangBangImageEscaperTest < ActiveSupport::TestCase

  def test_escape_should_leave_wysiwyg_image_alone
    wysiwyg_img = %[
      <p>
        <img class="mingle-image" src="some_attachment"/>
      </p>
      ]
    assert_equal wysiwyg_img, ManuallyEnteredBangBangImageEscaper.new(wysiwyg_img).escape
  end

  def test_escape_should_escape_bangs_with_entities
    assert_equal '&#33;bangbang&#33;', ManuallyEnteredBangBangImageEscaper.new('!bangbang!').escape
  end

  def test_escape_should_make_content_no_longer_match_image_substitution
    escaped_content = ManuallyEnteredBangBangImageEscaper.new('<p>!bangbang!</p>').escape
    assert_nil escaped_content =~ Renderable::InlineImageSubstitution.pattern
  end
  
end

