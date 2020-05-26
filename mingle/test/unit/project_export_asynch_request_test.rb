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

class ProjectExportAsynchRequestTest < ActiveSupport::TestCase

  def setup
    login_as_member
  end

  def test_should_store_export_tmp_file_with_name_based_on_project_name
    with_first_project do |project|
      asynch_request = create_project_export_request(project)
      assert_equal asynch_request.tmp_file.split('/').last, 'first_project.mingle'
    end
  end

  def test_should_give_download_url_for_s3_storage
    with_first_project do |project|
      asynch_request = create_project_export_request(project)
      MingleConfiguration.with_tmp_file_bucket_name_overridden_to('tmp_file') do
        assert_equal asynch_request.tmp_file_download_url(nil), asynch_request.success_url(nil, nil)
      end
    end
  end

  def test_project_export_should_not_honor_tmp_file_size_limit
    MingleConfiguration.with_asynch_request_tmp_file_size_limit_overridden_to("0") do
      with_first_project do |project|
        create_project_export_request(project)
      end
    end
  end

  def create_project_export_request(project)
    User.current.asynch_requests.create_project_export_asynch_request(project.identifier).tap do |asynch_request|
      asynch_request.message = {}
      f = SwapDir::ProjectExport.file(project)
      FileUtils.mkdir_p(f.dirname)
      File.open(f.pathname, 'w') {|io| io.write("something")}
      asynch_request.store_exported_filename(f.pathname)
    end
  end
end
