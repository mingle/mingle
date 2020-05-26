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

class ProgramExportAsynchRequestTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @program = program('simple_program')
  end

  def test_should_store_export_tmp_file_with_name_based_on_project_name
    asynch_request = create_program_export_request(@program)
    assert_equal asynch_request.tmp_file.split('/').last, 'simple_program.program'
  end

  def test_should_give_download_url_for_s3_storage
    asynch_request = create_program_export_request(@program)
    MingleConfiguration.with_tmp_file_bucket_name_overridden_to('tmp_file') do
      assert_equal asynch_request.tmp_file_download_url(nil), asynch_request.success_url(nil, nil)
    end
  end

  def test_should_return_local_success_url_when_s3_storage_not_configured
    asynch_request = create_program_export_request(@program)
    assert_equal({:controller=>"program_export", :program_id=>"simple_program", :id=> asynch_request.id, :action=>"download"}, asynch_request.success_url(nil, nil))
  end

  def create_program_export_request(program)
    User.current.asynch_requests.create_program_export_asynch_request(program.identifier).tap do |asynch_request|
      asynch_request.message = {}
      f = SwapDir::ProgramExport.file(program)
      FileUtils.mkdir_p(f.dirname)
      File.open(f.pathname, 'w') {|io| io.write("something")}
      asynch_request.store_exported_filename(f.pathname)
    end
  end
end
