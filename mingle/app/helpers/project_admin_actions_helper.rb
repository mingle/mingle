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

module ProjectAdminActionsHelper

  CODE_INTEGRATION_ACTION_NAME = 'Code Integration'
  INTEGRATIONS_ACTION_NAME = 'Integrations'

  PROJECT_ADMIN_ACTIONS = ['Project', [
      {:title => 'Project settings', :controller => 'projects', :action => 'edit'},
      {:title => 'Project repository settings', :controller => 'repository', :action => 'index'},
      {:title => 'Project variables', :controller => 'project_variables', :action => 'list'},
      {:title => 'Export project', :controller => 'project_exports', :action => 'confirm_as_project'},
      {:title => 'Export project as template', :controller => 'project_exports', :action => 'confirm_as_template'},
      {:title => 'Advanced project admin', :controller => 'projects', :action => 'advanced'}
  ]]

  CARDS_ADMIN_OPTIONS = ['Cards', [
      {:title => 'Card types', :controller => 'card_types', :action => 'list'},
      {:title => 'Card properties', :controller => 'property_definitions', :action => 'index'},
      {:title => 'Card transitions', :controller => 'transitions', :action => 'list'},
      {:title => 'Card trees', :controller => 'card_trees', :action => 'list'},
      {:title => 'Card keywords', :controller => 'projects', :action => 'keywords'}
  ]]

  INTEGRATIONS_ADMIN_ACTIONS = [INTEGRATIONS_ACTION_NAME, [
      {:title => 'GitHub', :controller => 'github', :action => 'new'},
      {:title => 'Slack', :controller => 'slack', :action => 'index'}
  ]]

  CODE_INTEGRATION_ADMIN_ACTIONS = [CODE_INTEGRATION_ACTION_NAME, [
      {:title => 'GitHub', :controller => 'github', :action => 'new'},
  ]]

  VIEWS_CONTENT_ADMIN_ACTIONS = ['Views / content', [
      {:title => 'Team favorites & tabs', :controller => 'favorites', :action => 'list'},
      {:title => 'Tags', :controller => 'tags', :action => 'list'},
      {:title => 'Pages', :controller => 'pages', :action => 'list'}
  ]]

  USERS_ADMIN_ACTIONS = ['Users', [
      {:title => 'Team members', :controller => 'team', :action => 'list'},
      {:title => 'Groups', :controller => 'groups', :action => 'index'}
  ]]

  def build_admin_options
    admin_options = [
        PROJECT_ADMIN_ACTIONS,
        CARDS_ADMIN_OPTIONS,
        CODE_INTEGRATION_ADMIN_ACTIONS,
        VIEWS_CONTENT_ADMIN_ACTIONS,
        USERS_ADMIN_ACTIONS
    ]

    admin_options[2] = INTEGRATIONS_ADMIN_ACTIONS if MingleConfiguration.saas?
    admin_options
  end

  def project_admin_page?
    (params[:controller] == 'projects' && ['edit', 'advanced', 'keywords'].include?(params[:action])) || @controller.is_a?(ProjectAdminController)
  end

  def admin_actions_links(current_selection)
    content_tag(:ul, :id => 'admin-nav') do
      build_admin_options.map do |section|
        group_name = section.first
        actions = section.last
        actions_for_section = actions.map do |params|
          opts = admin_html_options(current_selection, params[:controller], params[:action])
          content_tag(:li, opts) do
            link_to(params[:title], as_url_params(params))
          end
        end
        heading = content_tag(:li, group_name, :class => 'heading')
        [heading] + actions_for_section
      end.flatten.compact.join("\n").html_safe
    end
  end

  def admin_html_options(params, controller_name, action_name)
    if params[:controller] == controller_name && params[:action] == action_name
      return {:class => 'current-selection'}
    end
    {}
  end

  def as_url_params(params)
    params.reject { |k,v| k == :title }
  end

end
