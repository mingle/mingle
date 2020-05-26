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

class SourceControllerTest < ActionController::TestCase

  def setup
    does_not_work_without_subversion_bindings do
      @driver = with_cached_repository_driver(name + '_setup') do |driver|
        driver.create
        driver.import("#{Rails.root}/test/data/test_repository")
        driver.checkout
      end
      @repos = Repository.new(@driver.repos_dir)

      @controller = create_controller SourceController, :skip_project_caching => false
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new

      login_as_admin
      @project = create_project({:repository_path => @driver.repos_dir})
      @project.reload
    end
  end

  def teardown
    does_not_work_without_subversion_bindings do
      cleanup_repository_drivers_on_failure
    end
  end

  def test_display_error_in_connection_message_when_path_is_hooky
    does_not_work_without_subversion_bindings do
      assert !File.exist?('/very/bogus/path')
      SubversionConfiguration.find_by_project_id(@project.id).update_attribute(:repository_path, '/very/bogus/path')
      get :index, :rev => 'HEAD', :project_id => @project.identifier
      assert_response :success
      assert @response.body.include?('Error in connection with repository')
    end
  end

  # bug 4797
  def test_display_repository_location_has_invalid_path_error
    does_not_work_without_subversion_bindings do
      requires_jruby do
        config = SubversionConfiguration.find_by_project_id(@project.id)
        config.update_attributes :repository_path => config.repository_path + "/badpath", :initialized => true

        get :index, :rev => 'HEAD', :project_id => @project.identifier
        assert_response :success
        assert_error "Mingle can connect to the repository but cannot find the given location. Please check that your project repository settings are configured correctly."
      end
    end
  end

  def test_display_repository_is_empty_message
    does_not_work_without_subversion_bindings do
      @project.delete_repository_configuration
      new_one = with_cached_repository_driver(name) do |driver|
        driver.create
      end
      config = SubversionConfiguration.create!(:project_id => @project.id, :repository_path => new_one.repos_dir, :initialized => true)

      get :index, :rev => 'HEAD', :project_id => @project.identifier
      assert_response :success
      assert @response.body.include?('The repository is empty.')
    end
  end

  def test_view_svn_non_binary_file
    does_not_work_without_subversion_bindings do
      @driver.unless_initialized do |driver|
        driver.add_file('afile.txt', 'file content123')
        driver.commit "add file"
      end
      @project.repository_configuration.plugin.update_attribute :initialized, true
      get :index, :rev => 'HEAD', :path => ['afile.txt'], :project_id => @project.identifier

      assert_response :success
      assert_template 'file'
      assert @response.body.include?('afile.txt')
      assert @response.body.include?('file content123')
    end
  end

  # bug 5775
  def test_view_svn_binary_file
    does_not_work_without_subversion_bindings do
      get :index, :rev => 'HEAD', :path => ['binary.gif'], :project_id => @project.identifier
      assert_response :success
    end
  end

  def test_should_display_parent_dir_link_when_displaying_file
    does_not_work_without_subversion_bindings do
      @driver.unless_initialized do |driver|
        driver.add_directory('foo')
        driver.add_directory('foo/bar')
        driver.add_directory('foo/bar/baz')
        driver.add_file('foo/bar/baz/afile.txt', 'file content123')
        driver.add_file('root_file.txt', 'file content123')
        driver.commit "add dirs and file"
      end
      @project.repository_configuration.plugin.update_attribute :initialized, true

      get :index, :rev => 'HEAD', :path => ['foo/bar/baz/afile.txt'], :project_id => @project.identifier
      assert_response :success
      assert_tag :a, :attributes => {:href => "/projects/#{@project.identifier}/source/HEAD/foo/bar/baz"}, :content => 'foo/bar/baz/'

      get :index, :rev => 'HEAD', :path => ['root_file.txt'], :project_id => @project.identifier
      assert_response :success
      assert_tag :a, :attributes => {:href => "/projects/#{@project.identifier}/source/HEAD"}, :content => '/'
    end
  end

  def test_view_revision_does_not_exist_should_display_warning_message_and_redirect_to_head
    does_not_work_without_subversion_bindings do
      @driver.unless_initialized do |driver|
        driver.add_directory('adir')
        driver.commit "add a dir"
        driver.add_file('adir/another_file.txt', 'xyz')
        driver.commit "add another_file"
      end

      @project.repository_configuration.plugin.update_attribute :initialized, true
      get :index, :rev => '1', :path => ['adir'], :project_id => @project.identifier
      assert_not_nil flash[:not_found]
      assert_redirected_to :action => 'index', :path => ['adir'], :rev => 'HEAD'

      get :index, :rev => '1', :path => ['adir', 'another_file.txt'], :project_id => @project.identifier
      assert_not_nil flash[:not_found]
      assert_redirected_to :action => 'index', :path => ['adir', 'another_file.txt'], :rev => 'HEAD'
    end
  end

  # bug 5485
  def test_should_not_escape_path_seperator
    does_not_work_without_subversion_bindings do
      @driver.unless_initialized do |driver|
        driver.add_directory('another')
        driver.add_directory('another/location')
        driver.add_directory('another/location/here')
        driver.add_file('another/location/here/afile.txt', 'file content123')
        driver.commit "add dirs and file"
      end

      @project.repository_configuration.plugin.update_attribute :initialized, true
      get :index, :rev => 'HEAD', :path => ['another', 'location'], :project_id => @project.identifier
      assert_select "a[href=/projects/#{@project.identifier}/source/HEAD/another/location/here]"
    end
  end

  def test_index_should_not_warn_user_when_repository_is_source_browser_ready
    does_not_work_without_subversion_bindings do
      @project.delete_repository_configuration
      new_one = with_cached_repository_driver(name) { |driver| driver.create }
      configuration = SubversionConfiguration.create! :project_id => @project.id, :repository_path => new_one.repos_dir

      get :index, :rev => 'HEAD', :project_id => @project.identifier
      assert_response :success
      assert_nil flash[:info]
    end
  end

  # bug #3115
  def test_should_make_card_keywords_in_commit_messages_links_on_source_list
    does_not_work_without_subversion_bindings do
      @driver.unless_initialized do |driver|
        driver.add_file('afile.txt', 'file content123')
        driver.commit "#1 add file"
      end
      @project.repository_configuration.plugin.update_attribute :initialized, true
      get :index, :rev => 'HEAD', :project_id => @project.identifier
      assert_response :success
      assert_select "a", :text => "#1"
    end
  end

  def test_index_should_warn_user_when_repository_is_not_completely_initialized
    does_not_work_without_subversion_bindings do
      requires_jruby do
        @project.delete_repository_configuration
        new_one = HgRepositoryDriver.create(Time.now.to_i.to_s)

        configuration = HgConfiguration.create! :initialized => false, :project_id => @project.id, :repository_path => new_one.repos_dir

        get :index, :rev => 'HEAD', :project_id => @project.identifier
        assert_response :success
        assert_info Regexp.new("Mingle has not finished processing your project repository information. Depending on the size of your repository, this may take a while. Please continue to work as normal.")

        HgConfiguration.update configuration.id, :initialized => true
        get :index, :rev => 'HEAD', :project_id => @project.identifier
        assert_response :success
        assert_nil flash[:info]
      end
    end
  end

  def test_displays_appropriate_message_when_project_is_not_browsable
    requires_jruby do
      @project.delete_repository_configuration

      configuration = TfsscmConfiguration.create!({:project => @project, :server_url => "a-non-empty-url", :collection => 'a-non-empty-collection',
                                                   :tfs_project  => 'a-non-empty-project', :domain => 'a-non-empty-domain',
                                                   :username => 'a-non-empty-username', :password => 'a-non-empty-password' })

      get :index, :rev => 'HEAD', :project_id => @project.identifier
      assert_response :success
      assert_info Regexp.new("Mingle does not currently support Team Foundation Server repository browsing.")
    end
  end

end
