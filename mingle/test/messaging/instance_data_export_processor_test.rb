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

# Tags: messaging
class InstanceDataExportProcessorTest < ActiveSupport::TestCase

  def test_should_not_include_user_icons_exporter
    instance_data_export_processor = InstanceDataExportProcessor.new
    assert_equal [UserDataExporter, ProjectAdminExporter],   instance_data_export_processor.data_exporters({include_users_and_projects_admin: true, include_user_icons: false})
  end

  def test_should_not_include_users_data_and_project_admin_exporter
    instance_data_export_processor = InstanceDataExportProcessor.new
    assert_equal [UserIconExporter],   instance_data_export_processor.data_exporters({include_users_and_projects_admin: false, include_user_icons: true})
  end
end
