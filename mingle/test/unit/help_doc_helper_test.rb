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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class HelpDocHelperTest < ActiveSupport::TestCase
  include HelpDocHelper

  def test_contextual_help_file_name_gets_controller_action_file_name
    assert_equal 'projects_index', contextual_help_file_name(HashWithIndifferentAccess.new(:controller => 'projects', :action => 'index'))
    assert_equal 'projects_index', contextual_help_file_name(HashWithIndifferentAccess.new('controller' => 'projects', 'action' => 'index'))
  end

  def test_should_strip_multiple_space_separators_to_ensure_page_can_be_found
    expected_help_link = %Q[<a href="#{HELP_DOC_DOMAIN}/mingle_licenses.html" target="blank" title="Click to open help document" style="" class="page-help">Help</a>].html_safe

    assert_equal expected_help_link, render_help_link("Mingle      Licenses")
  end

  def test_should_render_default_link_when_name_is_blank
    expected_help_link = %Q[<a href="#{HELP_DOC_DOMAIN}" target="blank" title="Click to open help document" style="" class=""></a>].html_safe

    assert_equal expected_help_link, render_help_link(nil)
  end

end
