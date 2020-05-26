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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class Renderable::ScriptTagTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit

  class DummyScriptMacro < Macro
    def execute
      "<script>alert('1')</SCRIPT>"
    end
  end

  class ComplexScriptMacro < Macro
    def execute
      %Q{
        h1. script
        <script src="foo url"></script>
        <script>alert('1')</SCRIPT>
      }
    end
  end
  
  class ComplexScriptCustomMacro
    def initialize(parameters, project, current_user); end
    
    def execute
      %Q{
        h1. script
        <script src="foo url"></script>
        <script>alert('1')</SCRIPT>
      }
    end
  end

  def setup
    login_as_member
    @project = renderable_test_project
    @project.activate
  end

  def test_should_remove_script_tag_in_formatted_content
    card = @project.cards.first
    card.update_attribute :description, '<script>'
    assert_equal '', card.formatted_content(self)

    card.update_attribute :description, '</script>'
    assert_equal '', card.formatted_content(self)

    card.update_attribute :description, '<script></script>'
    assert_equal '', card.formatted_content(self)
    
    card.update_attribute :description, '<script>alert("hello word")</script>'
    assert_equal '', card.formatted_content(self)
    
    card.update_attribute :description, '<script src="xxx"></script>'
    assert_equal '', card.formatted_content(self)
    
    card.update_attribute :description, '<script src="xxx">alert("hello word")</script>'
    assert_equal '', card.formatted_content(self)
  end
  
  def test_should_be_able_to_output_script_tag_without_strip_by_macro
    with_built_in_macro_registered('dummy', DummyScriptMacro) do
      card = @project.cards.first
      card.update_attribute :description, "{{ dummy }}"
      assert_equal "<script>alert('1')</script>", card.formatted_content(self)
    end
  end

  def test_formatted_content_preview_should_not_render_cannot_preview_message_if_macro_is_a_built_in_macro
    with_built_in_macro_registered('dummy', ComplexScriptMacro) do
      card = @project.cards.first
      card.update_attribute :description, "{{ dummy }}"
      assert_match /<div class=\"macro-placeholder\">Your dummy will display upon saving<\/div>/,
                   card.formatted_content_preview(self)
    end
  end

  def test_formatted_content_preview_should_provide_cannot_preview_message_for_each_custom_macro
    with_custom_macro_registered('dummy', ComplexScriptCustomMacro) do
      card = @project.cards.first
      card.update_attribute :description, "{{ dummy }} some content {{ dummy }} some more content"
      assert_match /<div class=\"macro-placeholder\">Your dummy will display upon saving<\/div> some content <div class=\"macro-placeholder\">Your dummy will display upon saving<\/div> some more content/,
                   card.formatted_content_preview(self)
    end
  end
end
