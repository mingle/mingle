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

class InlineLinkSubstitutionTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    @substitution = Renderable::InlineLinkSubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
  end

  def test_substitute_textile_inline_link
    assert_equal "hello <a href=\"https://mingle.thoughtworks.com\">Mingle</a>, we love you", @substitution.apply('hello "Mingle":https://mingle.thoughtworks.com, we love you')
  end

  def test_substitute_markdown_inline_link
    assert_equal "hello <a href=\"https://mingle.thoughtworks.com\">Mingle</a>, we love you", @substitution.apply('hello [Mingle](https://mingle.thoughtworks.com), we love you')
  end
end
