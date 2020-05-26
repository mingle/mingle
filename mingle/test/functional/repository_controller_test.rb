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

class RepositoryControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller RepositoryController 
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    

    @proj_admin = User.find_by_login('proj_admin')
    @project = create_project :admins => [@proj_admin]
    login_as_proj_admin
  end

  def test_should_render_index_if_no_repository_configured
    get :index, :project_id => @project.identifier
    assert_response :success
  end

  def test_should_render_svn_specific_form_when_configured
    setup_svn
    get :index, :project_id => @project.identifier

    assert_response :success
    assert_select "#repository_config_repository_path", :value => "foorepository_path"
  end

  def test_should_return_svn_configuration_xml_if_configured
    setup_svn
    get :index, :project_id => @project.identifier, :format => 'xml', :api_version => "v2"

    assert_response :success
    assert_select "repository_path", "foorepository_path"
  end

  def test_should_return_error_xml_when_not_configured
    get :index, :project_id => @project.identifier, :format => 'xml', :api_version => "v2"

    assert_response :not_found
    assert_include "No repository configuration found in project", @response.body
  end

  def test_should_rerender_with_errors
    post :save, :project_id => @project.identifier, :repository_config => { :username => "", :password => "", :repository_path => "repo_path" }, :repository_type => "GitConfiguration"
    
    assert @project.reload.has_source_repository?
    post :save, :project_id => @project.identifier, :id => @project.repository_configuration.plugin.id, :repository_config => { :username => "", :password => "", :repository_path => "" }, :repository_type => "GitConfiguration"

    assert_equal "Repository path can't be blank", flash.now[:error]
    assert @project.reload.has_source_repository?
  end

  def test_jruby_repository_configurations
    does_not_work_without_jruby do
      {
       "TfsscmConfiguration"  => {:server_url => "tfs server", :collection => "my collection", :tfs_project => "a project", 
                                  :domain => "domain", :username => "bob",:password => "password"}, 
       "HgConfiguration" => {:username => "bob", :password => "pass123", :repository_path => "//p4/path" }, 
      }.each do | repo_type, repo_config |
        should_return_xml_response_on_successful_update_when_no_repository_configuration_exists({:repository_config => repo_config, :repository_type => repo_type})
        should_return_error_xml_response_on_update_when_repository_configuration_exists({:repository_config => repo_config, :repository_type => repo_type})
      end
    end
  end

  def test_all_repository_configurations
    {
     "GitConfiguration" => {:username => "bob", :password => "pass123", :repository_path => "//p4/path" }, 
     "SubversionConfiguration" => {:username => "bob", :password => "pass123", :repository_path => "//p4/path" }, 
     "PerforceConfiguration"  => {:repository_path => "p4 repo", :host => "p4server", :port => "123", :username => "bob", :password => "password"}
    }.each do | repo_type, repo_config |
      should_return_xml_response_on_successful_update_when_no_repository_configuration_exists({:repository_config => repo_config, :repository_type => repo_type})
      should_return_error_xml_response_on_update_when_repository_configuration_exists({:repository_config => repo_config, :repository_type => repo_type})
    end
  end

  def test_should_show_index_for_corresponding_repo
    get :index, :repository_type => 'GitConfiguration', :project_id => @project.identifier
    assert_template 'git_configurations/index.rhtml'
  end
  
  def test_should_delete_after_invalid_save
    setup_svn
    post :save, :project_id => @project.identifier, :repository_config => { :username => "", :password => "", :repository_path => "" }, :repository_type => "SubversionConfiguration"
    assert @project.reload.has_source_repository?
    assert !flash.now[:error].blank?
    
    post :delete, :project_id => @project.identifier
    
    assert !@project.reload.has_source_repository?
  end

  private
  
  def should_return_xml_response_on_successful_update_when_no_repository_configuration_exists(params)
    default_params = {:project_id => @project.identifier, :format => 'xml', :api_version => "v2"}
    post :update, default_params.merge(params)

    assert_response :created
    assert @project.reload.has_source_repository?
    params[:repository_type].classify.constantize.destroy_all
  end

  def should_return_error_xml_response_on_update_when_repository_configuration_exists(params)
    default_params = {:project_id => @project.identifier, :format => 'xml', :api_version => "v2"}
    post :update, default_params.merge(params)
    assert_response :created

    post :update, default_params.merge(params)
    assert_response :unprocessable_entity
    assert @project.reload.has_source_repository?
    assert_include "Could not create the new repository configuration because a repository configuration already exists.", @response.body
    params[:repository_type].classify.constantize.destroy_all
  end
  
  
  def setup_svn
    svn_config = SubversionConfiguration.create!(:project_id => @project.id, :username => 'foousername',
      :password => 'foopassword',  :repository_path => 'foorepository_path',  :card_revision_links_invalid => true,
      :initialized => false, :marked_for_deletion => false)

    svn_config.username = 'barusername'
    svn_config.password = 'barpassword'
    svn_config.repository_path = 'barrepository_path'
    RepositoryConfiguration.new(svn_config).mark_valid
    svn_config
  end

end
