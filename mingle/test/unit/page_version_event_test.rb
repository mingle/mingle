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

class PageVersionEventTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @project = first_project
    @project.activate
    view_helper.default_url_options = {:project_id => @project.identifier, :host => "example.com"}
  end

  def test_source_link_should_point_to_page_url
    page = @project.pages.create!(:name => 'hello')
    assert_equal 'http://example.com/projects/first_project/wiki/hello', page.versions.last.event.source_link.html_href(view_helper)
    assert_equal 'http://example.com/api/v2/projects/first_project/wiki/hello.xml', page.versions.last.event.source_link.xml_href(view_helper, 'v2')
  end

  def test_source_link_point_to_a_deleted_page
    page = @project.pages.create!(:name => 'hello')
    page.destroy
    assert_equal "http://example.com/projects/first_project/wiki/hello", page.versions.last.event.source_link.html_href(view_helper)
    assert_equal "http://example.com/api/v2/projects/first_project/wiki/hello.xml", page.versions.last.event.source_link.xml_href(view_helper, 'v2')
  end

end
