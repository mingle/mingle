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
require File.expand_path(File.dirname(__FILE__) + '/../../renderable_test_helper')

class MacroSubstitutionTest < ActiveSupport::TestCase
  include RenderableTestHelper

  class DummyMacro < Macro
    def execute
      "DUMMY #{name} #{parameters.sort.join}"
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

  def setup
    @project = first_project
    @project.activate
    Macro.register('dummy', DummyMacro)
    Macro.register('error', DummyMacro)
    Macro.register('dummy_print_projects', DummyProjectsCustomMacro)

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
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    s.apply("sdfvsdf {{ dummy }} fghdfgh")
    assert_equal ['dummy'], s.rendered_macros
  end

  def test_should_be_able_to_dry_run_render_macros
    s = Renderable::MacroSubstitution.new(:dry_run => true, :project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    assert_equal 'sdfvsdf {{ dummy }} fghdfgh', s.apply("sdfvsdf {{ dummy }} fghdfgh")
    assert_equal ['dummy'], s.rendered_macros
  end

  def test_can_parse_macros
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    assert_equal_ignoring_spaces 'sdfvsdf DUMMY dummy  fghdfgh', s.apply("sdfvsdf {{ dummy }} fghdfgh")
    assert_equal_ignoring_spaces 'sdfvsdf DUMMY dummy  fghdfgh DUMMY dummy', s.apply("sdfvsdf {{ dummy }} fghdfgh {{ dummy }}")
    assert_equal_ignoring_spaces "sdfvsdf \n DUMMY dummy   fgh \r\n dfgh", s.apply("sdfvsdf \n {{ dummy }} fgh \r\n dfgh")
    assert_equal_ignoring_spaces 'sdfvsdf DUMMY dummy  blah blah  fghdfgh', s.apply("sdfvsdf {{ dummy blah: blah }} fghdfgh")
    assert_equal_ignoring_spaces "sdfvsdf DUMMY dummy blahblahblah1blah1 fghdfgh", s.apply("sdfvsdf {{ dummy blah: blah \n blah1: blah1 }} fghdfgh")
  end

  def test_graceful_about_non_existent_macros
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_dom_content %{sdfvsdf No such macro: #{'doesntexist'.bold} fghdfgh}, s.apply("sdfvsdf {{ doesntexist }} fghdfgh")
  end

  def test_graceful_about_non_existent_project
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_include "There is no project with identifier #{'doesntexist'.bold}", s.apply("{{ macroname project: doesntexist}}")
  end

  def test_graceful_about_non_accessible_project
    login_as_member
    np = create_project :name => 'access test'
    np.remove_member(User.find_by_login('member'))
    with_new_project do |p|

      s = Renderable::MacroSubstitution.new(:project => p, :content_provider => p.pages.create(:name => 'First Page'), :view_helper => view_helper)
      macro = <<-MACRO
      {{
        table
          query: SELECT number, name
          project: access_test
      }}

      MACRO
      assert_match /not a member.*access test/, s.apply(macro)
    end
  end

  def test_should_report_project_in_use_when_error_happened
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)

    def s.instantiate_macro(*args)
      error = Macro::ProcessingError.new('errrrr', Project.find_by_identifier('first_project'))
      ErrorMacro.new(error)
    end
    assert_include "Error in error macro using Project One project: errrrr", s.apply("{{ error }}")
  end

  def test_should_not_report_project_if_in_use_project_not_given
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)

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

    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => this_card, :view_helper => view_helper)
    assert_include "DUMMY dummy", s.apply("{{ dummy project: this card.status }}")

    cp_status.update_card(this_card, 'nonexistentproject')
    this_card.save!
    assert_include "There is no project with identifier #{'nonexistentproject'.bold}", s.apply("{{ dummy project: this card.status }}")
  end

  # bug 8703
  def test_should_show_nice_error_message_when_using_this_card_in_project_parameter_with_wrong_data_type
    this_card = @project.cards.first
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => this_card, :view_helper => view_helper)
    assert_include %{Data types for parameter #{'project'.bold} and #{"this card.&#39;start date&#39;".bold} do not match. Please enter the valid data type for #{'project'.bold}.}, s.apply("{{ dummy project: this card.&#39;start date&#39; }}")
  end

  # bug 8703 reopening criteria
  def test_should_show_nice_error_message_if_putting_in_a_number_as_a_project_identifier
    this_card = @project.cards.first
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => this_card, :view_helper => view_helper)
    assert_include "There is no project with identifier #{'53'.bold}", s.apply("{{ dummy project: 53 }}")
  end

  # bug 8703 reopening criteria
  def test_should_show_nice_error_message_if_putting_in_a_number_as_a_project_identifier_for_a_custom_macro
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    MinglePlugins::Macros.register(DummyProjectsCustomMacro, 'dummy_print_projects')
    assert_include "There is no project with identifier #{'53'.bold}", s.apply("{{ dummy_print_projects project: 53 }}")
  ensure
    $mingle_plugins['macros']['dummy_print_projects'] = nil
  end

  # bug 9088
  def test_should_not_show_error_when_there_is_no_space_after_macro_name
    # it is important for this test that there be no space between 'project' and the closing braces of the macro
    markup_without_space = <<-BLAH
{{ project}}

{{
  value
    query: SELECT number
}}
    BLAH

    markup_with_space = <<-BLAH
{{ project }}

{{
  value
    query: SELECT number
}}
    BLAH

    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    assert_equal "first_project\n\n1\n", s.apply(markup_with_space)
    assert_equal "first_project\n\n1\n", s.apply(markup_without_space)
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
    login_as_member
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
    MinglePlugins::Macros.register(DummyProjectsCustomMacro, 'dummy_print_projects')

    result = s.apply("{{ dummy_print_projects #{Renderable::PROJECT_GROUP}: #{@project.identifier}, three_level_tree_project  }}")
    assert_not_include "error", result
    assert_include @project.identifier, result
    assert_include "three_level_tree_project", result
  ensure
    $mingle_plugins['macros']['dummy_print_projects'] = nil
  end

  def test_single_project_should_be_passed_to_custom_macro_if_specified
    login_as_member
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper, :content_provider_project => @project)
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
    s = Renderable::MacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    MinglePlugins::Macros.register(DummyCustomMacro, 'dummy_custom_macro')
    assert_include "Error in dummy_custom_macro macro: errrrr",  s.apply("{{ dummy_custom_macro }}")
  ensure
    $mingle_plugins['macros']['dummy_custom_macro'] = nil
  end


  # bug minglezy/#397
  def test_handles_error_when_parameters_are_not_a_yaml_hash
    mock_error_handler = Object.new

    mock_error_handler.class_eval do

      attr_reader :macro_error

      def add_macro_execution_error(error)
        @macro_error = error
      end

    end

    context = { :project => first_project, :content_provider_project => first_project, :content_provider => mock_error_handler }
    sub = Renderable::MacroSubstitution.new(context)

    sub.apply "{{ FakeMacro: 123 }}"

    assert_equal "Could not understand macro parameters:  123 ",  mock_error_handler.macro_error.message
  end

  def test_should_extract_name_for_given_macro
    assert_equal("pie-chart", Renderable::MacroSubstitution.new.macro_name("{{ pie-chart\n    data}}"))
    assert_equal("pie-chart", Renderable::MacroSubstitution.new.macro_name("{{ pie-chart:\n  query: Select name where type=story}}"))
  end

  def test_should_return_empty_string_when_extracting_name_for_invalid_macro
    assert_equal("", Renderable::MacroSubstitution.new.macro_name("random text"))
    assert_equal("", Renderable::MacroSubstitution.new.macro_name("{{ {{ {{))"))
  end

  def test_should_extract_parameters_from_macro
    params = Renderable::MacroSubstitution.new.macro_parameters("{{pie-chart\n    query: Select name where type=story\n    radius: 150}}")
    expected = {'pie-chart' => {'query' => 'Select name where type=story', 'radius' => 150}}
    assert_equal(expected, params)

    params = Renderable::MacroSubstitution.new.macro_parameters("{{pie-chart:\n    query: Select name where type=story\n    radius: 150}}")
    expected = {'pie-chart' => {'query' => 'Select name where type=story', 'radius' => 150}}
    assert_equal(expected, params)
  end

  def test_should_extract_parameters_from_macro_with_no_parameters
    params = Renderable::MacroSubstitution.new.macro_parameters("{{pie-chart  }}")
    expected = {'pie-chart' => {}}
    assert_equal(expected, params)
  end

  def test_should_extract_empty_parameters_from_macro_when_no_name_present
    params = Renderable::MacroSubstitution.new.macro_parameters("{{}}")
    assert_equal({}, params)
  end

  def test_should_return_nil_when_error_parsing
    params = Renderable::MacroSubstitution.new.macro_parameters("{{foobar\nfoobar}}")
    assert_nil(params)
  end

  def test_should_return_macro_count
    assert_equal({'foobar' => 1}, Renderable::MacroSubstitution.new.macro_count("{{foobar}}"))
    assert_equal({'foobar' => 1}, Renderable::MacroSubstitution.new.macro_count("{{foobar\n blah}}"))
    assert_equal({'foobar' => 2, 'daily-history-chart' => 1}, Renderable::MacroSubstitution.new.macro_count("{{foobar\n blah}}  {{ daily-history-chart}}  {{foobar}}"))
    assert_equal({}, Renderable::MacroSubstitution.new.macro_count("{{ should not match"))
  end
end
