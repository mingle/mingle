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

class TemplatesControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller(TemplatesController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @user = login_as_admin
    @template = create_project
    @template.update_attributes(:template => true)
    @project = create_project(:name => 'project')
  end

  def test_should_only_show_templates_in_list_view
    get :index
    assert_response :success
    assert_equal count(:template => true), assigns(:templates).size
  end

  def test_should_have_link_to_delete_template_from_list
    get :index
    assert_response :success
    assert_tag :a, :attributes => {:href => "/admin/templates/delete/#{@template.identifier}"}
  end

  def test_should_be_able_to_delete_a_template
    before_delete_count = count(:template => true)
    get :delete, :project_id => @template.identifier
    assert_template 'delete'
    assert_tag :a, :content => "Continue to delete"

    post :confirm_delete, :project_id => @template.identifier
    follow_redirect
    assert_template 'index'
    after_delete_count = count(:template => true)
    assert_equal 1, before_delete_count - after_delete_count
  end

  def test_should_not_generate_weird_url_after_template_delete
    post :confirm_delete, :project_id => @template.identifier
    assert_redirected_to :action => 'index'
    assert @response.headers['Location'] =~ /\/admin\/templates/
  end

  def test_should_not_generate_weird_url_after_templatize
    post :templatize, :project_id => @project.identifier
    assert_redirected_to :action => 'index'
    assert @response.headers['Location'] =~ /\/admin\/templates/
  end
  # bug1740
  def test_new_template_name_should_not_appended_with_underscore_when_templatize
    post :templatize, :project_id => @project.identifier
    new_template = Project.find_by_identifier("#{@project.identifier}_template")
    assert_equal "#{@project.name} template", new_template.name
  end

  # bug 5918
  def test_changing_case_on_template_name_should_not_cause_error_when_creating_another_template_from_same_project
    @project.name = 'XYZ'
    @project.save!
    post :templatize, :project_id => @project.identifier

    new_template = Project.find_by_name("XYZ template")
    new_template.activate
    new_template.name = "XYZ Template"
    new_template.save!

    post :templatize, :project_id => @project.identifier
    brand_new_template = Project.find_by_name("XYZ template1")
    assert_not_nil brand_new_template
  end

  def test_should_be_shown_a_list_of_all_projects_when_creating_a_new_template
    get :new
    assert_template 'new'
    assert_include @project, assigns(:projects)
    assert_not_include @template, assigns(:projects)
    assert_tag :content => @project.name
  end

  def test_creating_a_template_from_a_project_should_redirect_to_template_list_and_show_new_template
    before_delete_count = count(:template => true)
    post :templatize, :project_id => @project.identifier
    follow_redirect
    after_delete_count = count(:template => true)
    assert_equal 1, after_delete_count - before_delete_count
    Project.find(:all, :conditions => ["template = ? AND hidden = ?", true, false]).each do |project|
      assert_tag :a, :attributes => {:href => "/admin/templates/delete/#{project.identifier}"}
    end
  end

  def test_routes
    assert_generates '/admin/templates', :controller => 'templates', :action => 'index'
    assert_generates '/admin/templates/new', :controller => 'templates', :action => 'new'
  end
  # Bug 6767
  def test_should_clear_project_cache_when_template_was_deleted
    @controller = create_controller(TemplatesController, :skip_project_caching => false)
    project = ProjectCacheFacade.instance.load_project(@template.identifier)
    ProjectCacheFacade.instance.cache_project(project)
    post :confirm_delete, :project_id => @template.identifier
    assert ProjectCacheFacade.instance.send(:load_cached_project, @template.identifier).nil?
  end

  def test_should_include_icons_for_templates
    create_project :template => true, :icon => sample_attachment('user_icon.png')
    get :index
    assert_select '.project-icon-holder img'
  end

  def test_should_list_templates_with_overview_url
    get :index
    assert_response :success
    assert_select "a[href=/projects/#{@template.identifier}]", :count => 1
    assert_select "a[href=/projects/first_project/#{@template.identifier}]", :count => 0
  end

  def count(options={})
    Project.find(:all, :conditions => {:template => options[:template]}).reject(&:hidden?).size
  end
end
