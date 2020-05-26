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

class ApplicationHelperLazyLoadingCollapsibleTest < ActionView::TestCase
  include ApplicationHelper
  def setup
    @member = login_as_member
    @project = first_project
    @project.activate
  end


  def test_lazy_loading_collapsible_should_not_double_escape_the_page_identifier_in_url
    page = @project.pages.create(:name => "A & B", :content => 'bar')
    collapsible = lazy_loading_collapsible('history', {:controller => 'pages', :action => 'history', :page_identifier => page.identifier, :project_id => @project.identifier }, :html => {:id => 'history' })
    assert_include "new Ajax.Updater('history_collapsible_content', '/projects/first_project/wiki/A_&_B/history'", collapsible
  end

  def test_lazy_loading_collapsible_should_escape_javascripts_in_the_page_history_url
    page = @project.pages.create(:name => "A');alert('foo')</script>B", :content => 'bar')
    collapsible = lazy_loading_collapsible('history', {:controller => 'pages', :action => 'history', :page_identifier => page.identifier, :project_id => @project.identifier }, :html => {:id => 'history' })
    assert_include "new Ajax.Updater('history_collapsible_content', '/projects/first_project/wiki/history?page_identifier=A%27%29%3Balert%28%27foo%27%29%3C%2Fscript%3EB'", collapsible
  end

end
