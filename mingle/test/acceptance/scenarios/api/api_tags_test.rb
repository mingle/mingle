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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')

# Tags: properties, api_version_2
class ApiTagsTest < ActiveSupport::TestCase
  fixtures :users, :login_access


  def setup
    @version = 'v2'
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
     project_name = unique_name('Zebra')
     @project = with_new_project(:name => project_name, :identifier => project_name.underscore, :users => [User.find_by_login('member')]) do |project|
          @tags = create_tags(project, 3)
      end
      @project.add_member(User.find_by_login('member'), :readonly_member)
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_can_get_list_of_tags_as_json
    json = get_project_tags_as_json(@project)
    tags = JSON.parse(json)

    assert_equal @tags.collect(&:name), tags.collect { |tag| tag['name'] }
    assert_equal @tags.collect(&:color), tags.collect { |tag| tag['color'] }
  end

  protected

  def get_project_tags_as_json(project)
    get("#{url_prefix(project)}/tags.json", {}).body
  end

  def url_prefix(project)
    "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{project.identifier}"
  end
end
