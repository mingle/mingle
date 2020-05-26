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

class ProjectImportProcessorTest < ActiveSupport::TestCase

  def setup
    @processor = ProjectImportProcessor.new
    @admin = User.find_by_login('admin')
    login_as_admin
  end

  def test_process_project_import_asynch_request
    with_three_level_tree_project do |project|
      export_file = create_project_exporter!(project, @admin).export

      import = create_project_importer!(@admin, export_file)
      asynch_request = import.progress.reload
      @processor.on_message(
          :user_id => @admin.id,
          :request_id => asynch_request.id)
      asynch_request.reload
      assert_equal 'completed successfully', asynch_request.status
      assert asynch_request.completed?
    end
  end

end
