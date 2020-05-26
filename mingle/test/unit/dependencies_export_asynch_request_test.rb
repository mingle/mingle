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

class DependenciesExportAsynchRequestTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @project1 = create_project(:name => 'project 1', :identifier => 'project_1')
    @project2 = create_project(:name => 'project 2', :identifier => 'project_2')
    @project3 = create_project(:name => 'project 3', :identifier => 'project_3')
  end

  def test_should_store_export_tmp_file_as_current_date_dot_dependencies
    asynch_request = create_dependencies_export_request([@project1, @project2, @project3])
    assert_equal asynch_request.tmp_file.split('/').last, "#{Time.now.strftime('%Y-%m-%d')}.dependencies"
  end

  def test_should_give_download_url_for_s3_storage
    asynch_request = create_dependencies_export_request(@program)
    MingleConfiguration.with_tmp_file_bucket_name_overridden_to('tmp_file') do
      assert_equal asynch_request.tmp_file_download_url(nil), asynch_request.success_url(nil, nil)
    end
  end

  def test_should_return_local_success_url_when_s3_storage_not_configured
    asynch_request = create_dependencies_export_request([@project1, @project2, @project3])
    assert_equal({:controller=>"dependencies_import_export", :export_date=>asynch_request.deliverable_identifier, :id=> asynch_request.id, :action=>"download"}, asynch_request.success_url(nil, nil))
  end

  def create_dependencies_export_request(projects)
    User.current.asynch_requests.create_dependencies_export_asynch_request(Time.now.strftime("%Y-%m-%d")).tap do |asynch_request|
      asynch_request.message = {}
      f = SwapDir::DependencyExport.file(asynch_request.deliverable_identifier)
      FileUtils.mkdir_p(f.dirname)
      File.open(f.pathname, 'w') {|io| io.write("something")}
      asynch_request.store_exported_filename(f.pathname)
    end
  end
end
