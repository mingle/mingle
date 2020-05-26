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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class CustomMacroWrapperTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
  end

  def test_should_not_apply_redcloth_for_macro_content_result
    wrapper = Renderable::MacroSubstitution::CustomMacroWrapper.new(TextileCustomMacro, {},  {}, nil)
    assert wrapper.execute.include?('%{color: red}text%')
  end

  def test_should_handle_custom_macro_returns_nil_as_content
    wrapper = Renderable::MacroSubstitution::CustomMacroWrapper.new(DummyCustomMacro, {},  {}, nil)
    assert_equal '', wrapper.execute
  end

  def test_should_raise_if_projects_specified_contain_unknown_project
    assert_raise Macro::ProcessingError do
      Renderable::MacroSubstitution::CustomMacroWrapper.new(DummySupportsProjectGroupMacro, {},  {Renderable::PROJECT_GROUP => "unknown" }, nil )
    end
  end
  
  def test_should_not_raise_if_project_group_supported_and_project_exists
    assert_raise Macro::ProcessingError do
      Renderable::MacroSubstitution::CustomMacroWrapper.new(DummySupportsProjectGroupMacro, {},  {Renderable::PROJECT_GROUP => "unknown" }, nil )
    end
  end

  def test_should_escape_project_identifier_if_no_project_group_exists
    assert_raise_message(Macro::ProcessingError, /There is no project with identifier #{'<h1>unknown</h1>'.bold}/) do
      Renderable::MacroSubstitution::CustomMacroWrapper.new(DummySupportsProjectGroupMacro, {},  {Renderable::PROJECT_GROUP => "<h1>unknown</h1>" }, nil )
    end
  end
  
  def test_should_raise_if_project_group_specified_and_macro_does_not_support_project_groups
    assert_raise Macro::ProcessingError do
      Renderable::MacroSubstitution::CustomMacroWrapper.new(DummyDoesNotSupportsProjectGroupMacro, {},  {Renderable::PROJECT_GROUP => "first_project" }, nil )
    end
  end
  
  def test_should_raise_if_project_group_specified_and_macro_does_not_define_support_project_groups
    assert_raise Macro::ProcessingError do
      Renderable::MacroSubstitution::CustomMacroWrapper.new(DummySupportsProjectGroupUndefinedMacro, {},  {Renderable::PROJECT_GROUP => "first_project" }, nil )
    end
  end
  
  def test_should_not_corrupt_script_tags_emitted_by_custom_macros
    assert_equal_ignoring_spaces ScriptEmittingMacro::OUTPUT, wrapper(ScriptEmittingMacro).execute
  end
  
  def test_should_not_corrupt_style_tags_emitted_by_custom_macros
    assert_equal_ignoring_spaces StyleEmittingMacro::OUTPUT, wrapper(StyleEmittingMacro).execute
  end

  def wrapper(macro, project_group={})
    Renderable::MacroSubstitution::CustomMacroWrapper.new(macro, {}, project_group, nil)
  end
  
  class DummyCustomMacro
    def initialize(*args)
    end
    
    def execute
    end
  end

  class ScriptEmittingMacro
    OUTPUT = <<-JS
    <script type="text/javascript">
      initialize_card_prioritizer({"priorityProperty":"Priority","properties":["Number","Name","Priority"]});
    </script>
    something
    <SCRIPT type="text/javascript">
      initialize_card_prioritizer({"priorityProperty":"Priority","properties":["Number","Name","Priority"]});
    </SCRIPT>
    JS
    
    def initialize(*do_not_care)
    end
    
    def execute
      OUTPUT
    end
  end

  class StyleEmittingMacro
    OUTPUT = <<-JS
    <style>
      .a_class {
        background-color: 'red'
      }
    </style>
    <STYLE>
      .a_class {
        background-color: 'red'
      }
    </STYLE>
    JS

    def initialize(*do_not_care)
    end

    def execute
      OUTPUT
    end
  end

  class TextileCustomMacro < DummyCustomMacro
    def execute
      %Q{
        %{color: red}text%
        something
      }
    end
  end
  
  class DummySupportsProjectGroupMacro < DummyCustomMacro
    def self.supports_project_group?
      true
    end
  end
  
  class DummyDoesNotSupportsProjectGroupMacro < DummyCustomMacro
    def self.supports_project_group?
      false
    end
  end
  
  class DummySupportsProjectGroupUndefinedMacro < DummyCustomMacro
    
  end
end
