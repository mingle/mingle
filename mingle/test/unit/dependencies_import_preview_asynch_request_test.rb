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

class DependenciesImportPreviewAsynchRequestTest < ActiveSupport::TestCase

  def setup
    @user = login_as_admin
    @project1 = create_project(:name => 'project 1', :identifier => 'project_1')
    @project2 = create_project(:name => 'project 2', :identifier => 'project_2')
  end

  def test_should_fetch_all_dependencies_to_import
    with_temp_file do |tmp|
      asynch_request = @user.asynch_requests.create_dependencies_import_preview_asynch_request(Time.now.strftime("%Y-%m-%d"), tmp)
      asynch_request.add_dependency({'number' => 1, 'raising_car' => {:number => 10, :name => 'raise1'}})
      asynch_request.add_dependency({'number' => 2, 'raising_card' => {:number => 11, :name => 'raise2'}})

      asynch_request.add_dependencies_error({'number' => 3, 'raising_card' => {:number => 12, :name => 'raise3'}})
      asynch_request.add_dependencies_error({'number' => 4})

      assert_equal 3, asynch_request.dependencies_to_import.size
      sorted_deps = asynch_request.dependencies_to_import.sort do |a, b|
        a["number"].to_i <=> b["number"].to_i
      end
      assert_equal [1, 2, 3], sorted_deps.map {|d| d["number"].to_i}
    end
  end
end
