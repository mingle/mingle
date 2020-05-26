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

ActionController::Routing::Routes.draw do |map|
  map.root :action => 'index', :controller => 'projects', :conditions => {:method => :get}
  map.about 'about', :controller => 'about', :action => 'index'

  map.with_options :controller => "search" do |search|
    search.rest_cards_fuzzy_search "projects/:project_id/search/fuzzy_cards.json", :action => "fuzzy_cards", :conditions => {:method => :get}, :format => "json"
    search.rest_cards_recent_search "projects/:project_id/search/recent.json", :action => "recent", :conditions => {:method => :get}, :format => "json"
  end

  map.with_options :controller => "todos" do |todos|
    todos.rest_todos_list "users/:user_id/todos.json", :action => "index", :conditions => {:method => :get}, :format => "json"
    todos.rest_todos_create "users/:user_id/todos.json", :action => "create", :conditions => {:method => :post}, :format => "json"
    todos.rest_todos_update "users/:user_id/todos/:id.json", :action => "update", :conditions => {:method => :put}, :format => "json"
    todos.rest_todos_delete "users/:user_id/todos/:id.json", :action => "delete", :conditions => {:method => :delete}, :format => "json"
    todos.rest_todos_bulk_delete "users/:user_id/todos.json", :action => "bulk_delete", :conditions => {:method => :delete}, :format => "json"
    todos.rest_todos_sort "users/:user_id/todos/sort.json", :action => "sort", :conditions => {:method => :post}, :format => "json"
  end

  map.with_options :controller => 'about' do |about|
    about.connect 'projects/:ignored_project_id/about', :action => 'index'
    about.info 'api/:api_version/info.xml', :action => 'info', :conditions => {:method => :get}, :format => 'xml'
    about.abtesting_info 'api/:api_version/abtesting_info.xml', :action => 'abtesting_info', :conditions => {:method => :get}, :format => 'xml'
  end

  map.with_options :controller => 'profile' do |profile|
    profile.login 'profile/login', :action => 'login'
    profile.forgot_password 'profile/forgot_password', :action => 'forgot_password'
    profile.set_password 'profile/set_password', :action => 'set_password'
  end

  map.with_options :controller => 'license' do |license|
    license.ask_for_upgrade 'license/ask_for_upgrade', :action => 'ask_for_upgrade'
    license.clear_cached_license_status 'api/:api_version/license/clear_cached_license_status', :action => 'clear_cached_license_status'
  end

  map.with_options :controller => "projects" do |projects|
    projects.projects 'projects', :action => 'index'
    projects.project_show 'projects/:project_id', :action => 'show'
    projects.project_overview 'projects/:project_id/overview', :action => 'overview'
    projects.project_health_check 'projects/:project_id/admin/health_check', :action => 'health_check'
    projects.rebuild_card_murmur_linking 'projects/:project_id/admin/rebuild_card_murmur_linking', :action => 'rebuild_card_murmur_linking'

    # RESTful routes, should eventually be refactored with map.resources when we offer full support for REST
    projects.admin_new_project 'admin/projects/new', :action => 'new'
    projects.connect 'admin/projects/create', :action => 'create'
    projects.connect 'admin/projects/list_templates', :action => 'list_templates'
    projects.connect 'admin/projects/install', :action => 'install'
    projects.connect 'admin/projects/delete/:project_id', :action => 'delete'
    projects.connect 'admin/projects/confirm_delete/:project_id', :action => 'confirm_delete'

    projects.connect 'projects/:project_id/admin/:action'

    # RESTful routes, should eventually be refactored with map.resources when we offer full support for REST
    projects.connect 'api/:api_version/projects.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml'
    projects.connect 'api/:api_version/projects.json', :action => 'index', :conditions => {:method => :get}, :format => 'json'
    projects.connect 'api/:api_version/projects.xml', :action => 'create', :conditions => {:method => :post}, :format => 'xml'
    projects.rest_create_via_spec 'api/:api_version/projects/create_with_spec.xml', :action => "create_with_spec", :format => "xml"
    projects.rest_project_show 'api/:api_version/projects/:project_id.xml', :action => 'show_info', :format => 'xml'
    projects.connect 'api/:api_version/lightweight_projects/:project_id.xml', :action => 'lightweight_model', :conditions => {:method => :get}, :format => 'xml'

    projects.connect 'projects/:project_id.xml', :action => 'unsupported_api_call', :format => 'xml'
    projects.connect 'projects.xml', :action => 'unsupported_api_call', :format => 'xml'
    projects.connect 'lightweight_projects/:project_id.xml', :action => 'unsupported_api_call', :format => 'xml'
    projects.connect 'api/:api_version/projects/:project_id/chart_data.json', :action => 'chart_data', :conditions => {:method => :get}, :format => 'json'
  end

  map.with_options :controller => "dependencies", :path_prefix => "/projects/:project_id" do |dependencies|
    dependencies.dependency_unlink_card_popup "/dependencies/unlink_card_popup", :action => "unlink_card_popup"
    dependencies.connect "/dependencies/link_cards_popup", :action => "link_cards_popup"
    dependencies.connect "/dependencies/popup_show", :action => "popup_show"
    dependencies.connect "/dependencies/popup_history", :action => "popup_history"
    dependencies.connect "/dependencies/update/:id", :action => "update"
    dependencies.connect "/dependencies/dependency_name", :action => "dependency_name"
  end

  map.repository_index 'api/:api_version/projects/:project_id/repository.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml', :controller => "repository"

  map.with_options :controller => 'project_import' do |project_import|
    project_import.connect 'admin/:project_type/import'
    project_import.connect 'admin/:project_type/import/start', :action => 'import'
    project_import.connect 'admin/:project_type/import/progress/:id', :action => 'progress'
    project_import.connect 'admin/:project_type/import_from_s3', :action => 'import_from_s3'
  end

  map.with_options :controller => "templates" do |templates|
    templates.connect 'admin/templates', :action => 'index'

    templates.connect 'admin/templates/templatize/:project_id', :action => 'templatize'
    templates.connect 'admin/templates/delete/:project_id', :action => 'delete'
    templates.connect 'admin/templates/confirm_delete/:project_id', :action => 'confirm_delete'

    templates.connect 'admin/templates/new', :action => 'new'
  end

  map.hide_too_many_macros_warning 'hide_too_many_macros_warning', :action => 'hide_too_many_macros_warning', :controller => "pages"

  map.with_options :controller => "pages" do |pages|
    pages.connect 'projects/:project_id/wiki/update_tags', :action => 'update_tags'
    pages.connect 'projects/:project_id/wiki/list', :action => 'list'
    pages.connect 'projects/:project_id/wiki/new', :action => 'new'
    page_regex = /[^\/]+/

    # RESTful routes, should eventually be refactored with map.resources when we offer full support for REST
    pages.rest_page_add_attachment 'api/:api_version/projects/:project_id/wiki/:page_identifier/attachments.xml', :action => 'add_attachment', :page_identifier => page_regex, :conditions => {:method => :post}, :format => 'xml'
    pages.rest_page_get_attachment 'api/:api_version/projects/:project_id/wiki/:page_identifier/attachments/:file_name', :action => 'get_attachment', :page_identifier => page_regex,  :file_name => /.*/, :conditions => {:method => :get}, :format => 'xml'
    pages.rest_page_delete_attachment 'api/:api_version/projects/:project_id/wiki/:page_identifier/attachments/:file_name', :action => 'remove_attachment', :page_identifier => page_regex, :file_name => /.*/, :conditions => {:method => :delete}, :format => 'xml'
    pages.rest_page_list_attachments 'api/:api_version/projects/:project_id/wiki/:page_identifier/attachments.xml', :action => 'attachments', :page_identifier => page_regex,  :conditions => {:method => :get}, :format => 'xml'
    pages.rest_page_list 'api/:api_version/projects/:project_id/wiki.xml', :action => 'all_pages', :conditions => {:method => :get}, :format => 'xml'
    pages.rest_page_create 'api/:api_version/projects/:project_id/wiki.xml', :action => 'create', :conditions => {:method => :post}, :format => 'xml'
    pages.rest_page_show 'api/:api_version/projects/:project_id/wiki/:page_identifier.xml', :action => 'show', :format => 'xml', :page_identifier => page_regex, :conditions => {:method => :get}
    pages.rest_page_show_html 'api/:api_version/projects/:project_id/wiki/:page_identifier.html', :action => 'show', :format => 'html',  :page_identifier => page_regex, :conditions => {:method => :get}
    pages.rest_page_update 'api/:api_version/projects/:project_id/wiki/:page_identifier.xml', :action => 'update', :page_identifier => page_regex, :conditions => {:method => :put}, :format => 'xml'
    pages.rest_unsupported_call_pages 'projects/:project_id/wiki/:anything.xml', :format => 'xml', :action => 'unsupported_api_call'
    pages.rest_unsupported_page_attachment 'projects/:project_id/wiki/:anything/attachments.xml', :action => 'unsupported_api_call', :format => 'xml'
    pages.rest_unsupported_page_get_attachment 'projects/:project_id/wiki/:page_identifier/attachments/:file_name', :action => 'unsupported_api_call', :file_name => /.*/, :format => 'xml'
    pages.map 'projects/:project_id/wiki.xml', :action => 'unsupported_api_call'

    pages.page_show 'projects/:project_id/wiki/:pagename', :action => 'show', :pagename => page_regex
    pages.connect 'projects/:project_id/wiki/:page_identifier/create', :action => 'create', :page_identifier => page_regex
    pages.connect 'projects/:project_id/wiki/:page_identifier/update', :action => 'update', :page_identifier => page_regex
    pages.connect 'projects/:project_id/wiki/:page_identifier/preview', :action => 'preview', :page_identifier => page_regex
    pages.connect 'projects/:project_id/wiki/:page_identifier/:action', :page_identifier => page_regex
    pages.connect 'projects/:project_id/wiki', :action => 'show', :pagename => 'Overview_Page'
    pages.connect 'projects/:project_id/wiki/:action'
    pages.pages_chart_image 'projects/:project_id/wiki/:pagename/chart/:position/:type.png', :action => 'chart', :pagename => page_regex

    pages.pages_chart_data 'projects/:project_id/wiki/:pagename/chart_data/:position/:type', :action => 'chart_data', :pagename => page_regex
    pages.pages_async_macro_data 'projects/:project_id/wiki/:pagename/async_macro_data/:position/:type', :action => 'async_macro_data', :pagename => page_regex
    pages.new_pages_chart_data_preview 'projects/:project_id/wiki/chart_data/:position/:type', :action => 'chart_data'

    pages.preview_chart_image 'projects/:project_id/wiki/chart/:position/:type.png', :action => 'chart'

    pages.chart_as_text 'projects/:project_id/wiki/:pagename/chart_as_text/:position', :action => 'chart_as_text', :pagename => page_regex
  end

  map.connect "global_notifications", :controller => "sysadmin", :action => "user_notification"
  map.connect "global_notifications/update", :controller => "sysadmin", :action => "update_global_user_notification"
  map.connect "global_notifications/delete", :controller => "sysadmin", :action => "delete_global_user_notification"
  map.connect "sysadmin/data_fixes", :controller => "data_fixes", :action => "list", :format => "html"

  map.with_options :controller => 'property_definitions' do |property_definitions|
    number_regex = /\d+/
    property_definitions.property_definitions_list 'projects/:project_id/property_definitions', :action => 'index'
    property_definitions.manage_property_definitions 'projects/:project_id/property_definitions/edit/:id', :action => 'edit'
    property_definitions.property_definition_show 'projects/:project_id/property_definitions/:id', :action => 'show', :id => number_regex
    property_definitions.rest_property_definition_show 'api/:api_version/projects/:project_id/property_definitions/:id.xml', :format => 'xml', :action => 'show', :conditions => {:method => :get}
    property_definitions.map 'projects/:project_id/property_definitions.xml', :format => 'xml', :action => 'unsupported_api_call'
    property_definitions.map 'projects/:project_id/property_definitions.json', :format => 'json', :action => 'unsupported_api_call'
    property_definitions.rest_property_definition_values 'api/:api_version/projects/:project_id/property_definitions/values/:id.json', :action => 'values', :conditions => {:method => :get}, :format => 'json'
  end

  map.with_options :controller => "cards_plans" do |cards_plans|
    cards_plans.assign_to_objectives 'projects/:project_id/programs/:program_id/assign_to_objectives', :action => 'assign_to_objectives'
    cards_plans.card_objectives 'projects/:project_id/programs', :action => 'show'
  end

  map.with_options :controller => "cards" do |cards|
    cards.cards_in_progress "projects/:project_id/cards/in_progress", :action => "in_progress", :conditions => {:method => :get}
    cards.card_tree 'projects/:project_id/cards/list', :action => 'list'
    cards.card_tree 'projects/:project_id/cards/tree', :style => 'tree', :action => 'list'
    cards.card_grid 'projects/:project_id/cards/grid', :style => 'grid', :action => 'list'
    cards.card_hierarchy 'projects/:project_id/cards/hierarchy', :style => 'hierarchy', :action => 'list'
    number_regex = /\d+/
    cards.card_show 'projects/:project_id/cards/:number', :action => 'show', :number=>number_regex
    cards.card_rendered_description 'projects/:project_id/cards/:number/rendered_description', :action => 'rendered_description', :number=>number_regex
    cards.card_destroy 'projects/:project_id/cards/:number/destroy', :action => 'destroy', :number=>number_regex
    cards.card_edit 'projects/:project_id/cards/:number/edit', :action => 'edit', :number=>number_regex
    cards.card_copy_project_selection 'projects/:project_id/cards/:number/copy_to_project_selection', :action => 'copy_to_project_selection', :number => number_regex, :conditions => { :method => :get }
    cards.card_confirm_copy 'projects/:project_id/cards/:number/copy/confirm', :action => 'confirm_copy', :number => number_regex, :conditions => { :method => :get }
    cards.card_name 'projects/:project_id/cards/card_name/:number', :action => 'card_name', :number=>number_regex

    cards.card_transitions 'projects/:project_id/cards/:number/transitions.:format', :action => 'transitions', :number => number_regex

    # RESTful routes, should eventually be refactored with map.resources when we offer full support for REST
    cards.rest_card_add_attachment 'api/:api_version/projects/:project_id/cards/:number/attachments.xml', :action => 'add_attachment', :number => number_regex, :conditions => {:method => :post}, :format => 'xml'
    cards.rest_card_get_attachment 'api/:api_version/projects/:project_id/cards/:number/attachments/:file_name', :action => 'get_attachment', :number => number_regex, :file_name => /.*/, :conditions => {:method => :get}, :format => 'xml'
    cards.rest_card_delete_attachment 'api/:api_version/projects/:project_id/cards/:number/attachments/:file_name', :action => 'remove_attachment', :number => number_regex, :file_name => /.*/, :conditions => {:method => :delete}, :format => 'xml'
    cards.rest_card_list_attachments 'api/:api_version/projects/:project_id/cards/:number/attachments.xml', :action => 'attachments', :number => number_regex,  :conditions => {:method => :get}, :format => 'xml'
    cards.rest_card_list_transitions 'api/:api_version/projects/:project_id/cards/:number/transitions.xml', :action => 'transitions', :number => number_regex,  :conditions => {:method => :get}, :format => 'xml'
    cards.rest_card_murmurs_conv 'projects/:project_id/cards/:number/murmurs.json', :action => 'murmurs', :number=>number_regex, :format => "json"
    cards.rest_card_list_murmurs 'api/:api_version/projects/:project_id/cards/:number/murmurs.xml', :action => 'murmurs', :number => number_regex,  :conditions => {:method => :get}, :format => 'xml'
    cards.rest_card_post_murmurs 'api/:api_version/projects/:project_id/cards/:number/murmurs.xml', :action => 'add_comment', :number => number_regex,  :conditions => {:method => :post}, :format => 'xml'
    cards.rest_card_list 'api/:api_version/projects/:project_id/cards.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml'
    cards.rest_card_create 'api/:api_version/projects/:project_id/cards.xml', :action => 'create', :conditions => {:method => :post}, :format => 'xml'

    cards.rest_card_show 'api/:api_version/projects/:project_id/cards/:number.xml', :action => 'show', :number=>number_regex, :conditions => {:method => :get}, :format => 'xml'
    cards.rest_card_v2_update 'api/:api_version/projects/:project_id/cards/:number.xml', :action => 'update_restfully', :number => number_regex, :conditions => {:method => :put}, :format => 'xml'

    cards.rest_execute_mql 'api/:api_version/projects/:project_id/cards/execute_mql.xml', :format => 'xml', :action => 'execute_mql', :conditions => {:method => :get}
    cards.json_execute_mql 'api/:api_version/projects/:project_id/cards/execute_mql.json', :format => 'json', :action => 'execute_mql', :conditions => { :method => :get }

    cards.map 'projects/:project_id/cards.xml', :format => 'xml', :action => 'unsupported_api_call'
    cards.map 'projects/:project_id/cards/:anything.xml', :format => 'xml', :action => 'unsupported_api_call'
    cards.map 'projects/:project_id/cards/:anything/attachments.xml', :format => 'xml', :action => 'unsupported_api_call'
    cards.map 'projects/:project_id/cards/:number/attachments/:file_name', :action => 'unsupported_api_call', :format => 'xml', :file_name => /.*/
    cards.cards_chart_image 'projects/:project_id/cards/chart/:id', :action => 'chart'

    cards.rest_list_card_comments 'api/:api_version/projects/:project_id/cards/:number/comments.xml', :action => 'comments', :number => number_regex, :conditions => {:method => :get}, :format => 'xml'
    cards.rest_add_card_comments 'api/:api_version/projects/:project_id/cards/:number/comments.xml', :action => 'add_comment_restfully', :number => number_regex, :conditions => {:method => :post}, :format => 'xml'
    cards.rest_add_comments_json 'projects/:project_id/cards/:number/comments.json', :action => 'add_comment_restfully', :number => number_regex, :conditions => {:method => :post}, :format => "json"
    cards.murmur_from_card 'projects/:project_id/cards/:number/murmurs', :action => 'add_comment', :conditions => {:method => :post}
  end

  map.with_options :controller => 'card_trees' do |card_trees|
    card_trees.edit_card_tree 'projects/:project_id/card_trees/edit/:id', :action => 'edit', :id=>/\d+/
    card_trees.new_card_tree 'projects/:project_id/card_trees/new', :action => 'new'
    card_trees.delete_card_tree 'projects/:project_id/card_trees/delete', :action => 'delete'
    card_trees.edit_aggregate_properties 'projects/:project_id/card_trees/edit_aggregate_properties/:id', :action => 'edit_aggregate_properties', :id => /\d+/
  end

  map.with_options :controller => "favorites" do |favorites|
    favorites.connect 'projects/:project_id/favorites/:action'
    favorites.connect 'projects/:project_id/card_list_views/:action'
    favorites.manage_card_list_views 'projects/:project_id/favorites/list'
    favorites.map 'projects/:project_id/favorites.xml', :action => 'unsupported_api_call'
  end

  map.with_options :controller => "tabs" do |tabs|
    tabs.connect "projects/:project_id/tabs/reorder.json", :action => "reorder"
    tabs.connect "projects/:project_id/tabs/rename.json", :action => "rename"
  end

  map.with_options :controller => "tags" do |tags|
    tags.tag_color_update "projects/:project_id/tags/update_color", :action => "update_color", :conditions => {:method => :post}, :format => 'json'
    tags.connect 'projects/:project_id/tags.json', :action => 'unsupported_api_call', :format => 'json'
    tags.connect 'api/:api_version/projects/:project_id/tags.json', :action => 'list', :conditions => {:method => :get}, :format => 'json'
  end


  map.with_options :controller => "source" do |source|
    source.source_index 'projects/:project_id/source/:rev', :action => 'index'
    source.connect 'projects/:project_id/source/:rev/*path'
  end

  map.with_options :controller => "revisions" do |revisions|
    revisions.revision 'projects/:project_id/revisions/:rev', :action => 'show' # because plugin is using this named routes
    revisions.revision_show 'projects/:project_id/revisions/:rev', :action => 'show'
  end

  map.with_options :controller => "export" do |export|
    export.connect 'projects/:project_id/export', :action => 'index'
    export.connect 'projects/:project_id/export/download', :action => 'download'
  end

  map.with_options :controller => "history" do |history|
    history.history_encrypted_feed 'projects/:project_id/feeds/:encrypted_history_spec.:format', :action => 'feed'
    history.history_plain_feed 'projects/:project_id/feeds.:format', :action => 'plain_feed'
  end

  map.with_options :controller => "murmurs" do |murmur|
    murmur.murmurs_list 'projects/:project_id/murmurs.:format', :action => 'index'
    murmur.conversations 'projects/:project_id/conversations.:format', :action => 'conversation'
    murmur.at_user_suggestion 'projects/:project_id/murmurs/at_user_suggestion', :action => 'at_user_suggestion', :format => 'json'
  end

  map.with_options :controller => "card_types" do |card_types|
    number_regex = /\d+/
    card_types.rest_card_types_list 'api/:api_version/projects/:project_id/card_types.xml', :action => 'list', :conditions => {:method => :get}, :format => 'xml'
    card_types.rest_card_type_create 'api/:api_version/projects/:project_id/card_types.xml', :action => 'create_restfully', :conditions => { :method => :post }, :format => 'xml'
    card_types.card_type_show 'projects/:project_id/card_types/:id', :action => 'show', :id => number_regex, :conditions => {:method => :get}
    card_types.rest_card_type_show 'api/:api_version/projects/:project_id/card_types/:id.xml', :action => 'show', :id=>number_regex, :conditions => {:method => :get}, :format => 'xml'
    card_types.map 'api/:api_version/projects/:project_id/card_types.json', :action => 'list', :conditions => {:method => :get}, :format => 'json'
  end
  map.resource :projects, :has_many => :card_types

  map.with_options :controller => "transition_executions" do |transition_executions|
    transition_executions.rest_transition_execution_create_v2 'api/v2/projects/:project_id/transition_executions/:id.xml', :action => 'create', :conditions => { :method => :post }, :format => 'xml'
    transition_executions.map 'api/:api_version/projects/:project_id/transition_executions.xml', :action => 'unsupported_api_call'
    transition_executions.map 'projects/:project_id/transition_executions.xml', :action => 'unsupported_api_call'
  end

  map.with_options :controller => "team" do |team|
    team.rest_invite 'api/:api_version/projects/:project_id/team/invite_user.:format', :action => 'invite_user', :conditions => { :method => :post }
    team.rest_list 'api/:api_version/projects/:project_id/users.xml', :action => 'index', :format => 'xml'
    team.map 'projects/:project_id/users.xml', :action => 'unsupported_api_call', :format => 'xml'
    team.team 'projects/:project_id/team'
    team.team_invite_suggestions 'projects/:project_id/team/invite_suggestions', :action => 'invite_suggestions', :format => 'json'
    team.team_invite_user 'projects/:project_id/team/invite_user', :action => 'invite_user', :format => 'json', :conditions => { :method => :post }
  end

  map.with_options :controller => 'groups' do |groups|
    groups.rest_group_index 'api/:api_version/projects/:project_id/groups.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml'
    groups.rest_group_show 'api/:api_version/projects/:project_id/groups/:id.xml', :action => 'show', :conditions => {:method => :get}, :format => 'xml'
    groups.groups     '/projects/:project_id/groups', :action => 'index', :conditions => {:method => :get}
    groups.group_show '/projects/:project_id/groups/:id', :action => 'show', :conditions => {:method => :get}
  end
  map.resources :groups, :path_prefix => '/projects/:project_id'

  map.with_options :controller => "users" do |users|
    users.user_list 'users/list', :action => 'index'
    users.service_plan 'users/plan', :action => 'plan'
    users.deletable_list 'users/deletable', :action => 'deletable'
    users.user_read_notification 'users/mark_notification_read', :action => 'mark_notification_read'
    users.avatar 'users/:id/avatar', :action => 'avatar', :id => /\d+/
    users.rest_list 'api/:api_version/users.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml'
    users.rest_user_create 'api/:api_version/users.xml', :action => 'create', :conditions => {:method => :post}, :format => 'xml'
    users.rest_user_show 'api/:api_version/users/:id.xml', :project_id => '', :action => 'show', :id => /\d+/, :conditions => {:method => :get}, :format => 'xml'
    users.rest_user_update 'api/:api_version/users/:id.xml', :action => 'update_profile', :id=>/\d+/, :conditions => {:method => :put}, :format => 'xml'
    users.map 'users/:id.xml', :action => 'unsupported_api_call'
    users.map 'users.xml', :action => 'unsupported_api_call'
    users.map 'users/update_api_key/:id', :action => 'update_api_key', :id => /\d+/
  end
  map.resources :users, :only => [:create, :show, :new]

  map.with_options :controller => "daily_history_chart" do |daily_history_chart|
    daily_history_chart.daily_history_chart_for_card 'projects/:project_id/daily_history_chart/card', :action => 'card'
    daily_history_chart.daily_history_chart_for_page 'projects/:project_id/daily_history_chart/page', :action => 'page'
    daily_history_chart.daily_history_chart_for_unsupported 'projects/:project_id/daily_history_chart/unsupported', :action => 'unsupported'
  end

  map.with_options :controller => "rendering" do |rendering|
    rendering.rest_content_rendering_show 'api/:api_version/projects/:project_id/render', :action => 'render_content', :format => 'xml'
    rendering.content_rendering_show 'projects/:project_id/render', :action => 'render_content'
  end

  map.resources :projects do |projects|
    projects.resources :attachments, :only => [:show, :create]
  end

  map.with_options :controller => "attachments" do |attachments|
    attachments.attachments_get_external "projects/:project_id/attachable/get_external", :action => "retrieve_from_external", :conditions => {:method => :post}
  end

  map.resource :personal_favorites

  map.resources :programs, :only => [:index, :create, :destroy, :update], :member => { :confirm_delete => :get } do |programs|
    programs.dependencies '/dependencies', :controller => 'program_dependencies', :action => 'dependencies'
    programs.resources :program_memberships, :only => [:index, :create], :collection => { :list_users_for_add => :get , :bulk_destroy => :delete }, :as => 'team'
    programs.resources :backlog_objectives, :only => [:reorder], :collection => {:reorder => :put}
    programs.resources :backlog_objectives, :only => [:destroy, :update, :index, :create], :member => {:destroy => :post, :plan_objective => :put, :confirm_delete => :post}
    programs.resources :program_projects, :member => { :confirm_delete => :get , :property_values_and_associations => :get, :update_accepts_dependencies => :post }, :as => 'projects', :except => [:new]
    programs.resource :plan, :except => [:new, :create, :index, :destroy] do |plans|
      plans.resources :objectives, :controller => :objectives, :member => { :work_progress => :get, :popup_details => :get, :confirm_delete => :get, :work => :get, :timeline_objective => :get, :view_value_statement => :get, :restful_list => :get}, :except => [:new] do |objective|
        objective.resources :works, :only => [:index, :bulk_create, :cards], :collection => { :bulk_create => :post, :cards => [:get, :post], :bulk_delete => :post, :save => [:put, :post] }, :as => 'work'
      end
    end
    programs.resources :export, :only => [:index, :create], :member => { :download => :get }, :controller => :program_export
  end

  map.with_options :controller => "program_dependencies", :path_prefix => "/programs/:program_id" do |dependencies|
    dependencies.connect "/dependencies/toggle_resolved", :action => "toggle_resolved"
    dependencies.connect "/dependencies/popup_show", :action => "popup_show"
    dependencies.connect "/dependencies/popup_history/:id", :action => "popup_history"
    dependencies.connect "/dependencies/unlink_card_popup", :action => "unlink_card_popup"
    dependencies.connect "/dependencies/link_cards_popup", :action => "link_cards_popup"
    dependencies.connect "/dependencies/update/:id", :action => "update"
  end

  map.import_program 'admin/programs/import/new', :controller => 'program_import', :action => :new, :conditions => {:method => :get}
  map.import_program 'admin/programs/import/import', :controller => 'program_import', :action => :import, :conditions => {:method => :post}

  map.update_user_display_preference '/user_display_preference/update_user_display_preference', :controller => :user_display_preference, :action => :update_user_display_preference
  map.update_user_project_preference '/user_display_preference/update_user_project_preference', :controller => :user_display_preference, :action => :update_user_project_preference, :conditions => {:method => :put}

  map.connect 'projects/:project_id/macro_editor/render_macro', :controller => 'macro_editor', :action => 'render_macro'

  map.connect 'saas_tos', :controller => 'saas_tos', :action => 'show', :conditions => {:method => :get}
  map.connect 'saas_tos', :controller => 'saas_tos', :action => 'accept', :conditions => {:method => :post}

  map.with_options :controller => "tenants", :format => 'xml' do |tenants|
    tenants.rest_index 'api/:api_version/tenants.xml', :action => 'index', :conditions => {:method => :get}

    tenants.rest_create 'api/:api_version/tenants.xml', :action => 'create', :conditions => {:method => :post}

    tenants.rest_destroy 'api/:api_version/tenants.xml', :action => 'destroy', :conditions => {:method => :delete}

    tenants.rest_upgrade 'api/:api_version/tenants/:name/upgrade.xml', :action => 'upgrade', :conditions => {:method => :post}

    tenants.rest_upgrade_deprecated 'api/:api_version/tenants/upgrade.xml', :action => 'upgrade', :conditions => {:method => :post}

    tenants.rest_get_license 'api/:api_version/tenants/:name/license.xml', :action => 'license_registration', :conditions => {:method => :get}

    tenants.rest_update_license 'api/:api_version/tenants/:name/license.xml', :action => 'register_license', :conditions => {:method => :put}

    tenants.rest_show_tenant 'api/:api_version/tenants/show/:name.xml', :action => 'show', :conditions => {:method => :get}
    tenants.rest_stats 'api/:api_version/tenants/stats.xml', :action => 'stats', :conditions => {:method => :get}

    tenants.rest_validate 'api/:api_version/tenants/validate.xml', :action => 'validate', :conditions => {:method => :get}

    tenants.rest_derive_tenant_name 'api/:api_version/tenants/derive_tenant_name.xml', :action => 'derive_tenant_name', :conditions => {:method => :get}
  end

  map.connect 'api/:api_version/data_fixes.json', :action => :list, :controller => :data_fixes, :conditions => { :method => :get }, :format => :json

  map.connect 'api/:api_version/data_fixes/apply.json', :action => :apply, :controller => :data_fixes, :conditions => { :method => :put }, :format => :json

  map.github 'api/:api_version/projects/:project_id/github.json', :controller => 'github', :action => 'receive', :conditions => {:method => :post}, :format => :json

  #for rest api
  map.connect 'api/:api_version/projects/:project_id/:controller.xml', :action => 'index', :conditions => {:method => :get}, :format => 'xml'
  map.connect 'api/:api_version/projects/:project_id/:controller.json', :action => 'index', :conditions => {:method => :get}, :format => 'json'
  map.connect 'api/:api_version/projects/:project_id/:controller.xml', :action => 'create', :conditions => {:method => :post}, :format => 'xml'
  map.connect 'api/:api_version/projects/:project_id/:controller.xml', :action => 'update', :conditions => {:method => :put}, :format => 'xml'
  map.connect 'api/:api_version/projects/:project_id/:controller/:id.xml', :action => 'show', :id=>/\d+/, :conditions => {:method => :get}, :format => 'xml'
  map.connect 'api/:api_version/projects/:project_id/:controller/:id.json', :action => 'show', :id=>/\d+/, :conditions => {:method => :get}, :format => 'json'
  map.connect 'api/:api_version/projects/:project_id/:controller/:id.xml', :action => 'update', :id=>/\d+/, :conditions => {:method => :put}, :format => 'xml'

  map.connect 'api/:api_version/projects/:project_id/:controller/:action.xml', :format => 'xml'
  map.connect 'projects/:project_id/:controller/:action/:id'
  map.connect 'projects/:project_id/:controller/:action'
  map.connect 'api/:api_version/projects/:project_id/:controller.xml', :action => 'index', :format => 'xml'
  map.connect 'projects/:project_id/:controller', :action => 'index'

  map.rest_objective_show 'api/:api_version/programs/:program_id/plan/objectives/:id.xml', :controller => 'objectives', :action => 'restful_show', :conditions => {:method => :get}, :format => 'xml'
  map.rest_objective_update 'api/:api_version/programs/:program_id/plan/objectives/:id.xml', :controller => 'objectives', :action => 'restful_update', :conditions => {:method => :put}, :format => 'xml'
  map.rest_objective_delete 'api/:api_version/programs/:program_id/plan/objectives/:id.xml', :controller => 'objectives', :action => 'restful_delete', :conditions => {:method => :delete}, :format => 'xml'
  map.rest_work_show 'api/:api_version/projects/:project_id/cards/:number.xml', :controller => 'cards', :action => 'show', :number=>/\d+/, :conditions => {:method => :get}, :format => 'xml'

  map.connect 'api/:api_version/programs/:program_id/plan/objectives.xml', :controller => 'objectives', :action => 'restful_list', :conditions => {:method => :get}, :format => 'xml'
  map.connect 'api/:api_version/programs/:program_id/plan/objectives.xml', :controller => 'objectives', :action => 'restful_create', :conditions => {:method => :post}, :format => 'xml'

  map.connect "api/:api_version/project/:project_id/feeds/events.xml", :controller => "feeds", :action => "events", :conditions => {:method => :get}, :format => "xml"
  map.connect 'api/:api_version/programs/:program_id/plan/feeds/events.xml', :controller => 'program_feeds', :action => 'events', :conditions => {:method => :get}, :format => 'xml'
  map.connect 'api/:api_version/projects/:project_id/macro_editor/chart_edit_params.json', :controller => 'macro_editor', :action => 'chart_edit_params', :conditions => {:method => :get}, :format => 'json'
  map.with_options(:controller => 'legacy_attachments', :action => 'show', :id => /\d+/, :hash => /\w+/, :filename => /.*/) do |attachments|
    attachments.connect 'attachments/:hash/:id/:filename'
    (1..10).each { |n| attachments.connect "attachments_#{n}/:hash/:id/:filename" }
  end

  map.resources :feedback, :only => [:new, :create]
  map.resources :trial_feedback, :only => [:new, :create]
  map.resources :exports, :only => [:create, :index] do |export|
    export.download '/download', :controller => 'exports', :action => 'download'
    export.delete '/delete', :controller => 'exports', :action => 'delete', :conditions => {:method => :delete}
  end
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action.:format'
end
