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

class BuiltInTemplatesTest < ActiveSupport::TestCase

  def test_all_templates_have_overview_page
    login_as_admin
    ConfigurableTemplate.templates.each do |template|
      project = create_project
      assert_nil project.reload.overview_page
      ConfigurableTemplate.new(template.identifier).copy_into(project)
      assert_not_nil project.reload.overview_page, "Overview page not found when importing #{template.identifier}. Check yml syntax."
    end
  end

end
