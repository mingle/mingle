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

class WYSIWYGMacroSubstitutionTest < ActiveSupport::TestCase
  include RenderableTestHelper

  class TestChartMacro < Macro
    def execute
      "<img src=\"image_source\"/>"
    end
  end

  class TestWithClassMacro < Macro
    def execute
      "<div class='macro-placeholder'/>"
    end
  end

  class ErrorMacro < Macro
    def initialize(e)
      @e = e
    end
    def execute
      raise @e
    end
  end

  class BlankMacro < Macro
    def execute
      ""
    end
  end

  def setup
    @project = first_project
    @project.activate
    Macro.register('dummy', DummyMacro)
    Macro.register('error', DummyMacro)
    Macro.register('dummy_print_projects', DummyProjectsCustomMacro)
    Macro.register('macro_with_class', TestWithClassMacro)

    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')
  end

  def teardown
    Macro.unregister('dummy')
    Macro.unregister('error')
    Macro.unregister('dummy_print_projects')
    logout_as_nil
  end

  def test_should_know_all_macro_rendered
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    s.apply("sdfvsdf {{ dummy }} fghdfgh")
    assert_equal ['dummy'], s.rendered_macros
  end

  def test_should_be_able_to_dry_run_render_macros
    s = Renderable::WYSIWYGMacroSubstitution.new(:dry_run => true, :project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    assert_equal "sdfvsdf {{ dummy }} fghdfgh", s.apply("sdfvsdf {{ dummy }} fghdfgh")
    assert_equal ['dummy'], s.rendered_macros
  end

  def test_can_parse_macros
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    assert_dom_equal "sdfvsdf #{macro_with_content("{{ dummy }}", "DUMMY dummy")}  fghdfgh", s.apply("sdfvsdf {{ dummy }} fghdfgh")
    assert_dom_equal "sdfvsdf #{macro_with_content("{{ dummy }}", "DUMMY dummy")}  fghdfgh #{macro_with_content("{{ dummy }}", "DUMMY dummy")}", s.apply("sdfvsdf  {{ dummy }} fghdfgh {{ dummy }}")
    assert_dom_equal "sdfvsdf \n #{macro_with_content("{{ dummy }}", "DUMMY dummy")}   fgh \r\n dfgh", s.apply("sdfvsdf \n {{ dummy }} fgh \r\n dfgh")
    assert_dom_equal "sdfvsdf #{macro_with_content("{{ dummy blah: blah }}", "DUMMY dummy blahblah")}  fghdfgh", s.apply("sdfvsdf {{ dummy blah: blah }} fghdfgh")
    assert_dom_equal "sdfvsdf #{macro_with_content("{{ dummy blah: blah \n blah1: blah1 }}", "DUMMY dummy blahblahblah1blah1")} fghdfgh", s.apply("sdfvsdf {{ dummy blah: blah \n blah1: blah1 }} fghdfgh")
    assert_dom_equal "sdfvsdf #{macro_with_content("{{ dummy }}", "DUMMY dummy")}  fghdfgh", s.apply("sdfvsdf {{ dummy }} fghdfgh")
  end

  def test_should_preserve_classes_when_adding_macro_class
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    result = s.apply("{{ macro_with_class }}")
    assert result.include?("class=\"macro-placeholder macro\""), "should contain class='macro-placeholder macro' but was #{result}"
  end

  def test_handles_whitespace_in_raw_text
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)

    contentless_macro_with_whitespace_in_raw_text = " {{project}} "
    macro_with_whitespace_in_raw_text = macro_with_content("{{project}}", "first_project")

    assert_dom_equal macro_with_whitespace_in_raw_text, s.apply(contentless_macro_with_whitespace_in_raw_text)
  end

  def test_handles_macro_divs_that_span_multiple_lines
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)

    contentless_macro_with_multiple_lines_in_raw_text = " {{project}} "
    macro_with_multiple_lines_in_raw_text = macro_with_content("{{project}}", "first_project")

    assert_dom_equal macro_with_multiple_lines_in_raw_text, s.apply(contentless_macro_with_multiple_lines_in_raw_text)
  end

  def test_graceful_about_non_existent_macros
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    macro_definition = "{{ doesntexist }}"

    substitution_result = s.apply("sdfvsdf #{macro_definition} fghdfgh")

    assert_dom_equal "sdfvsdf<div contenteditable=\"false\" raw_text=\"#{URI.escape macro_definition}\" class=\"error macro\">No such macro: #{'doesntexist'.bold}</div>fghdfgh", substitution_result
  end

  def test_graceful_about_non_existent_project
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_include "There is no project with identifier #{'doesntexist'.bold}", s.apply("{{ macroname project: doesntexist}}")
  end

  def test_should_report_project_in_use_when_error_happened
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)

    def s.instantiate_macro(*args)
      error = Macro::ProcessingError.new('errrrr', Project.find_by_identifier('first_project'))
      ErrorMacro.new(error)
    end
    assert_include "Error in error macro using Project One project: errrrr", s.apply("{{ error }}")
  end

  def test_should_not_report_project_if_in_use_project_not_given
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)

    def s.instantiate_macro(*args)
      error = Macro::ProcessingError.new('errrrr')
      ErrorMacro.new(error)
    end
    assert_include "Error in error macro: errrrr", s.apply("{{ error }}")
  end

  # bug 8703
  def test_should_be_able_to_use_this_card_in_project_parameter
    login_as_proj_admin
    cp_status = @project.find_property_definition('status')
    this_card = @project.cards.first
    cp_status.update_card(this_card, @project.identifier)
    this_card.save!

    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => this_card, :view_helper => view_helper)
    assert_include "DUMMY dummy", s.apply("{{ dummy project: this card.status }}")

    cp_status.update_card(this_card, 'nonexistentproject')
    this_card.save!
    assert_include "There is no project with identifier #{'nonexistentproject'.bold}", s.apply("{{ dummy project: this card.status }}")
  end

  # bug 8703
  def test_should_show_nice_error_message_when_using_this_card_in_project_parameter_with_wrong_data_type
    this_card = @project.cards.first
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => this_card, :view_helper => view_helper)
    assert_include %{Data types for parameter #{'project'.bold} and #{"this card.'start date'".bold} do not match. Please enter the valid data type for #{'project'.bold}.}, s.apply("{{ dummy project: this card.'start date' }}")
  end

  # bug 8703 reopening criteria
  def test_should_show_nice_error_message_if_putting_in_a_number_as_a_project_identifier
    this_card = @project.cards.first
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => this_card, :view_helper => view_helper)
    assert_include "There is no project with identifier #{'53'.bold}", s.apply("{{ dummy project: 53 }}")
  end

  # bug 8703 reopening criteria
  def test_should_show_nice_error_message_if_putting_in_a_number_as_a_project_identifier_for_a_custom_macro
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    MinglePlugins::Macros.register(DummyProjectsCustomMacro, 'dummy_print_projects')
    assert_include "There is no project with identifier #{'53'.bold}", s.apply("{{ dummy_print_projects project: 53 }}")
  ensure
    $mingle_plugins['macros']['dummy_print_projects'] = nil
  end

  # bug 9088
  def test_should_not_show_error_when_there_is_no_space_after_macro_name
    # it is important for this test that there be no space between 'project' and the closing braces of the macro
    project_macro = "{{ project}}"
    value_macro = "{{
      value
        query: SELECT number
    }}"
    markup_without_space = <<-BLAH
#{project_macro}

#{value_macro}
BLAH

    markup_with_space = <<-BLAH
#{project_macro}

#{value_macro}
BLAH

    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    assert_dom_equal "#{macro_with_content(project_macro, "first_project")}\n\n#{macro_with_content(value_macro, "1")}\n", s.apply(markup_with_space)
    assert_dom_equal "#{macro_with_content(project_macro, "first_project")}\n\n#{macro_with_content(value_macro, "1")}\n", s.apply(markup_without_space)
  end

  class DummyCustomMacro
    def initialize(*args)
    end

    def execute
      raise 'errrrr'
    end
  end



  class DummyProjectsCustomMacro < Macro
    def initialize(parameters, projects, user)
     @projects = projects
    end

    def self.supports_project_group?
     true
    end

    def execute()
     @projects.collect(&:identifier).join(', ')
    end
  end

  def test_projects_should_be_passed_to_custom_macro_if_specified
    #make sure three_level_tree_project exists
    with_three_level_tree_project {}

    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    MinglePlugins::Macros.register(DummyProjectsCustomMacro, 'dummy_print_projects')

    result = s.apply("{{ dummy_print_projects #{Renderable::PROJECT_GROUP}: #{@project.identifier}, three_level_tree_project  }}")
    assert_not_include "error", result
    assert_include @project.identifier, result
    assert_include "three_level_tree_project", result
  ensure
     $mingle_plugins['macros']['dummy_print_projects'] = nil
  end

  def test_single_project_should_be_passed_to_custom_macro_if_specified
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    MinglePlugins::Macros.register(DummyProjectsCustomMacro, 'dummy_print_projects')

    result = s.apply("{{ dummy_print_projects #{Renderable::PROJECT_GROUP}: #{@project.identifier}}}")

    assert_not_include "error", result
    assert_include @project.identifier, result
  ensure
     $mingle_plugins['macros']['dummy_print_projects'] = nil
  end

  def test_should_report_error_from_custom_macro
    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    MinglePlugins::Macros.register(DummyCustomMacro, 'dummy_custom_macro')
    assert_include "Error in dummy_custom_macro macro: errrrr",  s.apply("{{ dummy_custom_macro }}")
  ensure
    $mingle_plugins['macros']['dummy_custom_macro'] = nil
  end

  def test_should_substitute_image_tag_for_macro_results_containing_an_image_tag
    Macro.register('chart', TestChartMacro)
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    content = s.apply("{{ chart }}")
    assert_dom_equal "<img src=\"image_source\" raw_text=\"#{URI::escape("{{ chart }}")}\" class=\"macro\"/>",  content
  end

  def test_should_handle_empty_content_in_edit_mode
    Macro.register('blank-macro', BlankMacro)
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :edit => true)
    content = s.apply("{{ blank-macro }}")
    assert_dom_equal "<div raw_text=\"#{URI::escape("{{ blank-macro }}")}\" class=\"macro-placeholder macro\">Your blank macro will display upon saving</div>",  content
  end

  def test_should_handle_empty_content
    Macro.register('blank_macro', BlankMacro)
    s = Renderable::WYSIWYGMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    content = s.apply("{{ blank_macro }}")
    assert_dom_equal "<span contenteditable=\"false\" raw_text=\"#{URI::escape("{{ blank_macro }}")}\" class=\"macro\"></span>",  content
  end

  private
    def macro_with_content(macro_definition, macro_content)
      "<span contenteditable=\"false\" raw_text=\"#{URI::escape(macro_definition)}\" class=\"macro\">#{macro_content}</span>"
    end
end
