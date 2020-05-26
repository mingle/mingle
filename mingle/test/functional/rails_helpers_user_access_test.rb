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

class RailsHelpersUserAccessTest < ActionController::TestCase
  include ActionView::Helpers::PrototypeHelper, ActionView::Helpers::UrlHelper, ActionView::Helpers::JavaScriptHelper, 
      ActionView::Helpers::FormTagHelper, ActionView::Helpers::FormHelper, ActionView::Helpers::TagHelper,
      ActionView::Helpers::CaptureHelper, UserAccess

  def setup
    login_as_member
    @member_user = User.find_by_login('member')
    @project = create_project :users => [@member_user]
    @project.activate
    @rendered = ""
    
    Thread.current[:controller_name] = 'projects'
  end

  def teardown
    Thread.current[:controller_name] = nil
  end

  def test_link_to_with_user_access
    assert_not_blank link_to('remove_attachment', {:controller => 'projects', :action => 'remove_attachment'})
    assert_not_blank link_to('remove_attachment', {:action => 'remove_attachment'})
    assert_not_blank link_to('remove_attachment', {:action => 'remove_attachment', :project_id => @project.identifier})
    assert_not_blank link_to('remove_attachment', {:project_id => @project.identifier, :action => 'remove_attachment', :page_name => 'wiki'})

    assert_blank link_to('new project', {:controller => 'projects', :action => 'new'})
    assert_blank link_to('new project', {:action => 'new'})
    assert_blank link_to('new project', {:action => 'new', :project_id => @project.identifier})
    assert_blank link_to('new project', {:action => 'new', :project_id => @project.identifier})
    assert_blank link_to('new project', {:action => 'new', :project_id => @project.identifier, :template => true})
  end
  
  def test_should_ignore_string_url
    assert_not_blank link_to("new project", "/projects/#{@project.identifier}/new")
  end

  def test_link_to_with_user_access_for_readonly_member
    @project.add_member(@member_user, :readonly_member)
    assert_blank link_to('remove_attachment', {:controller => 'projects', :action => 'remove_attachment'})
  end
  
  def test_link_to_remote_another_controller_action
    assert_blank link_to_remote('remove_attachment', :url => {:action => 'templatize', :project_id => @project.identifier, :controller => "templates"})
  end
  
  def test_link_to_remote
    assert_not_blank link_to_remote('remove_attachment', :url => {:controller => 'projects', :action => 'remove_attachment'})
    assert_not_blank link_to_remote('remove_attachment', :url => {:action => 'remove_attachment'})
    assert_not_blank link_to_remote('remove_attachment', :url => {:action => 'remove_attachment', :project_id => @project.identifier})
    assert_not_blank link_to_remote('remove_attachment', :url => {:project_id => @project.identifier, :action => 'remove_attachment', :page_name => 'wiki'})

    assert_blank link_to_remote('new project', :url => {:controller => 'projects', :action => 'new'})
    assert_blank link_to_remote('new project', :url => {:action => 'new'})
    assert_blank link_to_remote('new project', :url => {:action => 'new', :project_id => @project.identifier})
    assert_blank link_to_remote('new project', :url => {:action => 'new', :project_id => @project.identifier})
    assert_blank link_to_remote('new project', :url => {:action => 'new', :project_id => @project.identifier, :template => true})
  end
  
  def test_link_to_function
    assert_equal '<a href="javascript:void(0)" id="new_project_link_id" onclick="; return false;">New project</a>', link_to_function('New project', :id => 'new_project_link_id')
    assert_equal '<a href="javascript:void(0)" id="remove_attachment_link_id" onclick="; return false;">Remove attachment</a>', link_to_function('Remove attachment', :accessing => {:controller => 'projects', :action => 'remove_attachment'}, :id => 'remove_attachment_link_id')
    assert_blank link_to_function('New project', :accessing => {:controller => 'projects', :action => 'new'}, :id => 'new_project_link_id')
  end
  
  def test_form_tag
    assert_not_blank form_tag({:controller => 'projects', :action => 'new', :card_id => 1}, {:id => 'discussion-form'})
    assert_not_blank form_tag({:controller => 'projects', :action => 'new', :card_id => 1, :validate => false}, {:id => 'discussion-form'})

    assert_not_blank form_tag({:controller => 'projects', :action => 'remove_attachment', :card_id => 1, :validate => true}, {:id => 'discussion-form'})
    assert_blank form_tag({:controller => 'projects', :action => 'new', :card_id => 1, :validate => true}, {:id => 'discussion-form'})
    assert_blank (form_tag({:controller => 'projects', :action => 'new', :card_id => 1, :validate => true}, {:id => 'discussion-form'}){"inside form tag"})
  end
  
  def test_form_remote_tag
    assert_not_blank form_remote_tag(:url => {:controller => 'projects', :action => 'new', :card_id => 1})
    assert_not_blank form_remote_tag(:url => {:controller => 'projects', :action => 'new', :card_id => 1, :validate => false})
    assert_blank form_remote_tag(:url => {:controller => 'projects', :action => 'new', :card_id => 1, :validate => true})
  end
  
  def test_button_to_function
    assert_equal '<input id="new_project_link_id" onclick=";" type="button" value="New project" />', button_to_function('New project', :id => 'new_project_link_id')
    assert_equal '<input id="remove_attachment_link_id" onclick=";" type="button" value="Remove attachment" />', button_to_function('Remove attachment', :accessing => {:controller => 'projects', :action => 'remove_attachment'}, :id => 'remove_attachment_link_id')
    assert_blank button_to_function('New project', :accessing => {:controller => 'projects', :action => 'new'}, :id => 'new_project_link_id')
  end
  
  def test_check_box_should_be_disabled_when_user_have_no_access_and_prefer_disabling
    html = check_box "project", 'new_record?', { :name  => 'check_box_name', :accessing => ':new', :disable_on_access_denied => true }
    assert_equal_ignoring_spaces '<input name="check_box_name" type="hidden" value="0" /><input disabled="disabled" id="project_new_record" name="check_box_name" type="checkbox" value="1" />', html
  end
  
  def test_check_box_tag_should_be_disabled_when_user_have_no_access_and_prefer_disabling
    html = check_box_tag 'check_box_name', '1', false, :onclick => "javascript", :accessing => ':new', :disable_on_access_denied => true
    assert_equal_ignoring_spaces '<input disabled="disabled" id="check_box_name" name="check_box_name" onclick="javascript" type="checkbox" value="1" />', html
  end
  
  def test_disable_content_tag_when_user_has_no_access
    html = content_tag 'textarea', "lalala", :accessing => 'projects:new', :disable_on_access_denied => true
    assert_equal_ignoring_spaces '<textarea disabled="disabled"> lalala </textarea>', html
  end
  
  def test_check_box_should_not_show_unless_user_has_access_to_it
    html = check_box "project", 'new_record?', :name  => 'check_box_name', :accessing => 'projects:new'
    assert_equal_ignoring_spaces "<input name=\"check_box_name\" type=\"hidden\" value=\"0\" />", html
  end
  
  def test_check_box_tag_should_not_show_unless_user_has_access_to_it
    html = check_box_tag 'check_box_name', '1', false, :onclick => "javascript", :accessing => 'projects:new'
    assert_blank html
  end
  
  
  def test_tag_without_options
    assert_equal_ignoring_spaces "<p>update card</p>", content_tag("p", "update card")
  end
  
  def test_content_tag_should_not_show_unless_user_has_access_to_it
    assert_blank content_tag("td", "update card", :accessing => "cards:bulk_destroy")
    login_as_admin
    assert_not_blank content_tag("td", "update card", :accessing => "cards:bulk_destroy")
  end
  
  def test_tag_should_not_show_unless_athorized
    assert_blank tag("br", :accessing => "cards:bulk_destroy")
    login_as_admin
    assert_not_blank tag("br", :accessing => "cards:bulk_destroy") 
  end
  
  def test_content_tag_with_block_and_user_access
    content_tag("td", :accessing => "cards:bulk_destroy") { "update card" }
    assert_blank @rendered
    login_as_admin
    assert_not_blank content_tag("td", :accessing => "cards:bulk_destroy") { "update card" }
    assert_not_blank @rendered
  end
  
  protected
  
  def link_to_without_user_access(a, *args)
    "access to: #{args.inspect}"
  end
  
  def capture(*args, &block)
    @rendered << yield
  end
  
  def concat(string, binding)
    @rendered << string
  end
  
  alias_method :link_to_remote_without_user_access, :link_to_function
  alias_method :form_tag_without_user_access, :link_to_without_user_access
  alias_method :form_remote_tag_without_user_access, :link_to_without_user_access
  
end
