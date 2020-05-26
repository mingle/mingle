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

class RoutesTest < ActionController::TestCase

  def test_old_card_list_views_route_should_work
    assert_recognizes({:controller=>"favorites", :project_id=>"mike", :action=>"list"}, '/projects/mike/card_list_views/list')
    assert_routing '/projects/mike/favorites/list', {:controller=>"favorites", :project_id=>"mike", :action=>"list"}
  end

  def test_about_page_should_not_set_project_id
    assert_routing '/projects/mike/about', {:controller => 'about', :action => 'index', :ignored_project_id => 'mike'}
    assert_routing '/about', {:controller => 'about', :action => 'index'}
  end

  #bug 5475 cannot create any wiki page if wiki name contains the period (.)
  def test_should_allow_dot_appear_in_page_name
    assert_routing '/projects/phoenix/wiki/phoenix.1.1', {:controller => 'pages', :action => 'show', :project_id => 'phoenix', :pagename => 'phoenix.1.1'}
    assert_routing 'api/v2/projects/phoenix/wiki/phoenix.1.1.xml', {:controller => 'pages', :action => 'show', :project_id => 'phoenix', :page_identifier => 'phoenix.1.1', :format => 'xml', :api_version => 'v2'}
  end

  def test_should_allow_filename_with_multiple_dots
    assert_recognizes({:controller => 'legacy_attachments', :action => 'show', :id => '12', :hash => 'random_hash', :filename => 'filename.with.multiple.dots-and-01-11-2013.png'}, '/attachments/random_hash/12/filename.with.multiple.dots-and-01-11-2013.png')
  end
  
  def test_should_properly_route_attachments_from_the_secondary_attachment_directory
    assert_recognizes({:controller => 'legacy_attachments', :action => 'show', :id => '12', :hash => 'random_hash', :filename => 'filename.txt'}, '/attachments_2/random_hash/12/filename.txt')
  end

  def test_objective_api_routes_to_objectives_controller
    assert_routing '/api/v2/programs/prog1/plan/objectives/obj1.xml', {:controller => 'objectives', :action => 'restful_show', :id => 'obj1', :program_id => 'prog1', :api_version => 'v2', :format => 'xml'}
  end

  def test_objective_update_api_routes_to_objectives_controller
    assert_routing({ :method => 'put', :path => '/api/v2/programs/prog1/plan/objectives/obj1.xml' },
                   {:controller => 'objectives', :action => 'restful_update', :id => 'obj1', :program_id => 'prog1', :api_version => 'v2', :format => 'xml'})
  end

  def test_objective_create_api_routes_to_objectives_controller_restful_create
    assert_routing({ :method => 'post', :path => '/api/v2/programs/prog1/plan/objectives.xml' },
                   {:controller => 'objectives', :action => 'restful_create', :program_id => 'prog1', :api_version => 'v2', :format => 'xml'})
  end

  def test_objective_delete_api_routes_to_objectives_controller_restful_delete
    assert_routing({ :method => 'delete', :path => '/api/v2/programs/prog1/plan/objectives/obj1.xml' },
                   {:controller => 'objectives', :action => 'restful_delete', :id => 'obj1', :program_id => 'prog1', :api_version => 'v2', :format => 'xml'})
  end

  def test_saas_tos_get_routes_to_saas_tos_controller
    assert_routing({ :method=> 'get', :path => '/saas_tos' },
                   { :controller => 'saas_tos', :action => 'show' })
  end

  def test_saas_tos_post_routes_to_saas_tos_controller
    assert_routing({ :method=> 'post', :path => '/saas_tos' },
                   { :controller => 'saas_tos', :action => 'accept' })
  end

end
