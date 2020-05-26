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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class RevisionsControllerTest < ActionController::TestCase

  def setup
    does_not_work_without_subversion_bindings do
      @controller = create_controller RevisionsController
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new

      @member_user = User.find_by_login('member')
      login_as_member

      @driver = with_cached_repository_driver(name + '_setup') do |driver|
        driver.create
        driver.import("#{Rails.root}/test/data/test_repository")
        driver.checkout
      end
      @repos = Repository.new(@driver.repos_dir)
      @project = create_project(:users => [@member_user],:repository_path => @driver.repos_dir)
      @project.reload
    end
  end

  def test_show_uses_long_revision_name
    does_not_work_without_subversion_bindings do
      @project.cache_revisions
      @project.revisions.first.update_attribute(:identifier, '123asldfkjoieru123sldfkjlkjsdaflsjk')
      get :show, :project_id => @project.identifier, :rev => '123asldfkjoieru123sldfkjlkjsdaflsjk'
      assert_select "h1", :text => "Revision 123asldfkjoieru123sldfkjlkjsdaflsjk"
    end
  end

  def test_displays_helpful_message_when_revision_not_in_mingle
    does_not_work_without_subversion_bindings do
      get :show, :project_id => @project.identifier, :rev => '9999'
      expected_error = "Revision 9999 does not yet exist in this project. Most likely Mingle has not yet cached this revision and you can check back in a few minutes. If this is not a recent revision please check that it exists in your source repository."
      assert_select "#revision-error-message", {:html => expected_error}
    end
  end

  def test_displays_helpful_message_when_revision_in_mingle_but_content_not_yet_cached
    does_not_work_without_subversion_bindings do
      @project.cache_revisions
      get :show, :project_id => @project.identifier, :rev => '1'
      expected_error = "The content of this revision has not yet been cached by Mingle."
      assert_select "p#revision-content-not-cached-error-msg", :text => expected_error
    end
  end

  def test_show_removes_any_pre_existing_error_file
    does_not_work_without_subversion_bindings do
      error_file = "#{SwapDir::RevisionCache.pathname}/#{@project.id.to_s}/#{@project.send(:repository_configuration).plugin_db_id}/1.error"
      FileUtils.mkdir_p(File.dirname(error_file))
      FileUtils.touch(error_file)
      assert File.exist?(error_file)
      get :show, :project_id => @project.identifier, :rev => "1"
      assert !File.exist?(error_file)
    end
  end

  # bug 9900
  def test_should_show_error_message_when_can_not_connect_to_repository_server
    does_not_work_without_subversion_bindings do
      login_as_admin
      with_new_project do |project|
        get :show, :project_id => project.identifier, :rev => "1"
        assert_select 'div#error', :text => /Error in connection with repository/
        assert_select 'div#error', :text => /&lt;/, :count => 0
      end
    end
  end
end
