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

module TeamHelper
  include UsersHelper

  def team_member_link(user)
    link = if @project.admin?(User.current)
      controller = user == User.current ? 'profile' : 'users'
      link_to(h(user.name), {:project_id => nil, :controller => controller, :action => 'show', :id => user.id})
    end
    link || user.name
  end

  def remove_link
    @project.auto_enroll_enabled? ? disabled_remove_link : enabled_remove_link
  end

  def enabled_remove_link
    link_to_function('Remove', { :class => 'remove-membership link_as_button', :id => 'remove_membership' })
  end

  def disabled_remove_link
    link_to_function('Remove', { :class => 'remove-membership link_as_button disabled', :title => 'Enroll all users as team members currently is enabled. Disable this in order to remove team members.'})
  end

  def comma_separated_list(items)
    items.join(', ')
  end

  def memberships_json_for(project, users)
    users.inject({}) do |members_groups, user|
      members_groups[user.id] = project.groups_for_member(user).map(&:id)
      members_groups
    end.to_json
  end

  def tristate_checkbox(label, name, value, options = {})
    content_tag(:div, :class => 'tristate-checkbox tristate-checkbox-unchecked') do
      h(label) + hidden_field_tag(name, value, options)
    end
  end

  def can_current_user_modify_user_permissions?(target_user)
    return false unless authorized?(:controller => 'team', :action => 'set_permission') # current user must have have access to set_permission
    return false if target_user.light? # can't edit permission for a light user, they can only be realonly_member
    return false if target_user.current? && !User.current.admin? #only mingle admin can modify his/her own project permission
    return true
  end

  class UserTeamPermissionDroplist
    include DroplistJsHelper

    def initialize(project, user, url_opts)
      @project, @user, @url_opts = project, user, url_opts
    end

    def input_id
      "permission-for-#{@user.html_id}"
    end

    def js_component_id_prefix
      "select_permission_#{@user.html_id}"
    end

    def js(view_helper)
      generate_js(view_helper,
                  @user.project_role_candidates.map(&:name_id_pair),
                  @project.role_for(@user).name_id_pair,
                  @url_opts,
                  'membership[permission]')
    end
  end

  def user_permission_droplist(user)
    UserTeamPermissionDroplist.new(@project, user, {
      :action => 'set_permission',
      :user_id => user.id,
      :page => params[:page],
      :search => params[:search]
    })
  end

  def popup_content_file(name)
    "team/_#{name}.popup_content"
  end
end
