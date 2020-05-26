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

class AsynchRequestTest < ActiveSupport::TestCase
  def setup
    @project = create_project
    @member = login_as_member
    @async_request = User.current.asynch_requests.create_project_export_asynch_request(@project.identifier)
    @async_request.error_count = 0
  end

  def teardown
    logout_as_nil
  end

  def test_progress_percent
    @async_request.total = 100
    @async_request.completed = 50
    assert_equal 0.5, @async_request.progress_percent
  end

  def test_completed_status
    @async_request.total = 100
    @async_request.completed = 50
    assert !@async_request.completed?
    @async_request.completed = 100
    assert !@async_request.completed?
    @async_request.mark_completed_successfully
    assert @async_request.completed?
  end

  def test_should_be_failed_status_after_error_added
    assert @async_request.success?
    assert !@async_request.failed?
    @async_request.add_error("error msg")
    assert !@async_request.success?
    assert @async_request.failed?
    assert_equal ['error msg'], @async_request.error_details
  end

  def test_should_be_completed_after_ran_with_progress
    @async_request.with_progress do
    end
    assert @async_request.completed?
    assert @async_request.success?
    assert_equal 'completed successfully', @async_request.status
  end

  def test_should_rescue_errors_while_ran_with_progress
    @async_request.with_progress do
      raise "error"
    end
    assert @async_request.completed?
    assert @async_request.failed?
    assert_equal 'completed failed', @async_request.status
    assert_equal ['error'], @async_request.error_details
    assert_nil @async_request.progress_message
  end

  def test_should_mark_completed_and_failed_when_there_is_error
    @async_request.with_progress do
      raise "error"
    end
    assert @async_request.completed?
    assert @async_request.failed?
    assert_equal ['error'], @async_request.error_details
  end

  def test_update_progress_by_proc_in_progress
    @async_request.in_progress_proc.call("progress message", 100, 50)
    assert_equal "progress message", @async_request.progress_message
    assert_equal 0.5, @async_request.progress_percent
  end

  def test_should_not_update_completed_and_total_when_they_decreased_current_progress_percent
    @async_request.in_progress_proc.call("progress message 1", 100, 50)
    @async_request.in_progress_proc.call("progress message 2", 100, 40)
    assert_equal "progress message 2", @async_request.progress_message
    assert_equal 0.5, @async_request.progress_percent
  end

  def test_should_not_update_progress_message_when_it_is_blank
    @async_request.in_progress_proc.call("progress message", 100, 40)
    @async_request.in_progress_proc.call(nil, 100, 50)
    assert_equal "progress message", @async_request.progress_message
  end

  def test_partial_completion_without_error_count_should_produce_info_message
    @async_request.update_attributes(:total => 10, :completed => 5)
    assert_equal :info, @async_request.info_type
  end

  def test_completion_without_error_count_should_produce_notice_message
    @async_request.update_attributes(:total => 10, :completed => 10)
    @async_request.mark_completed_successfully
    assert_equal :notice, @async_request.info_type
  end

  def test_any_error_count_should_produce_error_message
    @async_request.update_attribute(:error_count, 1)
    assert_equal :error, @async_request.info_type
  end

  def test_delete_user_should_delete_asynch_request
    user_to_be_destroyed = create_user!
    asynch_request = user_to_be_destroyed.asynch_requests.create_project_import_asynch_request('does_not_matter', nil)

    assert AsynchRequest.find_by_id(asynch_request.id)
    user_to_be_destroyed.destroy
    assert_nil AsynchRequest.find_by_id(asynch_request.id)
  end

  def test_mark_completed
    export = create_project_exporter!(@project, User.current)
    export.mark_completed(false)
    assert_equal "completed failed", export.status
    assert export.completed_status?
    export.mark_completed(true)
    assert_equal "completed successfully", export.status
    assert export.completed_status?
  end

  def test_status_while_importing_project
    export_project = create_project_exporter!(@project, User.current).export
    import = create_project_importer!(User.current, export_project)

    assert_equal "queued", import.status

    import.process!

    assert import.project
    assert_equal "completed successfully", import.status
  end

  def test_should_show_the_error_message_when_import_project_failed
    import_request = User.current.asynch_requests.create_project_import_asynch_request(@project.identifier, nil)
    import_request.add_error("failed when import the project")
    assert_equal "failed when import the project", import_request.progress_msg
  end

  # bug 6341
  def test_should_truncate_progress_message
    @async_request.update_progress_message('a'*1350)
    @async_request.save!
    assert_equal 1300, @async_request.reload.progress_message.size
  end

  def test_store_tmp_file_into_swap_dir
    f = uploaded_file("#{File.expand_path(Rails.root)}/test/data/sample_attachment.txt", 'f.txt')
    @async_request.tmp_file = f
    @async_request.save!
    assert_equal "#{SwapDir::SwapFileProxy.new.pathname}/asynch_request/tmp_file/#{@async_request.id}/f.txt", @async_request.tmp_file
  end

  def test_localize_tmp_file_into_rails_tmp_dir
    f = uploaded_file("#{File.expand_path(Rails.root)}/test/data/sample_attachment.txt", 'f.txt')
    @async_request.tmp_file = f
    @async_request.save!
    tmp_file = @async_request.localize_tmp_file
    assert tmp_file.start_with?(RAILS_TMP_DIR)
  end

  def test_validate_tmp_file_size
    MingleConfiguration.with_asynch_request_tmp_file_size_limit_overridden_to("0") do

      f = uploaded_file("#{File.expand_path(Rails.root)}/test/data/sample_attachment.txt", 'f.txt')
      @async_request.tmp_file = f
      @async_request.validate_tmp_file_size
      assert_equal 'File cannot be larger than 0MB.', @async_request.errors.full_messages.join
    end

  end

  def test_validate_tmp_file_size_is_only_called_on_create
    MingleConfiguration.asynch_request_tmp_file_size_limit = '100'
    tmp_file = uploaded_file("#{File.expand_path(Rails.root)}/test/data/sample_attachment.txt", 'f.txt')
    import_request = User.current.asynch_requests.create_project_import_asynch_request(@project.identifier, tmp_file)
    assert_equal 0, import_request.errors.count

    MingleConfiguration.asynch_request_tmp_file_size_limit = '0'
    import_request.update_attributes(:message => 'Hello')
    assert_equal 0, import_request.errors.count
  ensure
    MingleConfiguration.asynch_request_tmp_file_size_limit = nil
  end

  def test_project_import_success_url_should_be_show_project_url
    User.current.reload
    import_request = User.current.asynch_requests.create_project_import_asynch_request("importing_identifier", nil)
    assert_equal "show", import_request.complete_url(ProjectsController.new, {})[:action]
    assert_equal 'importing_identifier', import_request.complete_url(ProjectsController.new, {})[:project_id]
    assert_equal "projects", import_request.complete_url(ProjectsController.new, {})[:controller]
  end
end
