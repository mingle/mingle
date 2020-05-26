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

class ManuallyEnteredMacroEscaperTest < ActiveSupport::TestCase

  def test_escape_should_leave_wysiwyg_macros_alone
    wysiwyg_macro = %[
      <div class="macro-placeholder macro" raw_text="%7B%7B%0A%20%20pie-chart%0A%20%20%20%20data:%20SELECT%20'Simple%20Status',%20Count(*)%20WHERE%20Type%20=%20Story%20and%20Owner%20=%20this%20card.owner%0A%7D%7D">
        Your pie chart will display upon saving
      </div>
      ]
    assert_equal wysiwyg_macro, ManuallyEnteredMacroEscaper.new(wysiwyg_macro).escape
  end

  def test_escape_should_make_content_no_longer_match_macro_substitution
    escaped_content = ManuallyEnteredMacroEscaper.new('{{ project }}').escape
    assert_nil escaped_content =~ Renderable::MacroSubstitution::MATCH
  end

  def test_escape_should_make_multiline_content_no_longer_match_macro_substitution
    escaped_content = ManuallyEnteredMacroEscaper.new("<p>{{&nbsp;</p>\r\n\r\n<p>project</p>\r\n\r\n<p>}}</p>\r\n").escape
    assert_nil escaped_content =~ Renderable::MacroSubstitution::MATCH
  end

  def test_escape_should_make_multiple_macros_no_longer_match_macro_substitution
    escaped_content = ManuallyEnteredMacroEscaper.new("{{ project }}\n{{ project }}").escape
    assert_nil escaped_content =~ Renderable::MacroSubstitution::MATCH
  end

end

