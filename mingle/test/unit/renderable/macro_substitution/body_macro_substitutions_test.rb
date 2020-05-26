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


class BodyMacroSubstitutionTest < ActiveSupport::TestCase
  include RenderableTestHelper

  def setup
    @project = first_project
    @project.activate
    Macro.register('dummy', DummyBodyMacro)
  end

  def teardown
    Macro.unregister('dummy')
  end

  def test_pattern
    s = Renderable::BodyMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert s.pattern =~ "{% dummy %} dummy body {% dummy %}"
    assert s.pattern =~ "sdfvsdf {% doesntexist %} fghdfgh {% doesntexist %}"
    assert s.pattern =~ "asdas {% dummy %} dummy body {% dummy %} asdfsd"
    assert !(s.pattern =~ "blah")
    assert !(s.pattern =~ "{% dummy %} dummy body {% dummy-blah %}")
    assert !(s.pattern =~ "{% dummy %} dummy body {% dummy }")
    assert !(s.pattern =~ "{ dummy %} dummy body {% dummy %}")
    assert s.pattern =~ %{
      {% two-columns %}
        {% left-column %}
          {% dashboard-panel %}
          {% dashboard-panel %}

          {% dashboard-panel %}
          {% dashboard-panel %}
        {% left-column %}

        {% right-column %}
          {% dashboard-panel %}
          {% dashboard-panel %}

          {% dashboard-panel %}
          {% dashboard-panel %}
        {% right-column %}
      {% two-columns %}
    }
  end

  def test_can_parse_and_substitute_macros
    s = Renderable::BodyMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_equal_ignoring_spaces 'sdfvsdf DUMMY dummy   dummy body  fghdfgh', s.apply("sdfvsdf {% dummy %} dummy body {% dummy %} fghdfgh")
  end

  def test_handles_errors_gracefully
    # reload the file, other tests override the handle_macro_error method
    load File.join(Rails.root, '/app/models/renderable.rb')

    s = Renderable::BodyMacroSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_equal_ignoring_spaces "sdfvsdf No such macro: #{'doesntexist'.bold}", Nokogiri::HTML::DocumentFragment.parse(s.apply("sdfvsdf {% doesntexist %} fghdfgh {% doesntexist %}")).inner_text
  end
end
