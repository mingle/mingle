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

module UsersHelper
  module ProjectAssignment
    def add_to_projects_link(user)
      not_member_projects = User.current.admin_project_ids - user.member_roles.map(&:deliverable_id)
      if not_member_projects.any?
        link_to_remote 'Add to Projects',
                       { :url => { :controller => :users, :action => 'select_project_assignments', :id => user.id },
                         :method => 'get',
                         :before => 'InputingContexts.push(new LightboxInputingContext());'
                        },
                        {
                          :id => 'add_projects',
                          :class => "primary link_as_button",
                          :accessing => 'users:select_project_assignments'
                        }
      else
        link_to_function 'Add to Projects', 'javascript:void(0)', :class => 'primary link_as_button disabled', :id => 'add_projects', :accessing => 'users:select_project_assignments'
      end
    end
  end

  module LoginAccess
    def time_since_last_login(user)
      last_login_at = user.login_access.last_login_at
      #todo: write test around edge cases
      if last_login_at
        raw(%{<abbr class="timeago" title="#{last_login_at.xmlschema}">#{last_login_at.strftime('%a %b %d %H:%M:%S %Z %Y')}</abbr>})
      end
    end
  end

  include ProjectAssignment
  include LoginAccess

  def cancel_edit_url
    url_for(:action => 'show', :id => @user)
  end

  def user_link(user, options={})
    controller = (user == User.current) ? 'profile' : 'users'
    link_to(h(user.name), {:project_id => nil, :controller => controller, :action => 'show', :id => user.id}, options) || user.name
  end

  def list_action_params
    { :page => params[:page], :search => params[:search] }
  end

  def paginator_info(users)
    search_params = params[:search] || {}
    search_params[:query].blank? ? pagination_info(users, 'user') : pagination_info(users, 'result')
  end


  def add_title_if_is_light_user(user)
    %{title="This user is a light user. Light users have restricted project permissions."} if user.light?
  end

  def row_class(user)
    [].tap do |classes|
      classes << 'highlight' if user == User.current
      if @project
        classes << 'direct_member'
      end
      classes << user.activation_state
    end.join(' ')
  end

  def sort_direction(column, params)
    "#{params['direction'].downcase}" if params['order_by'] == column
  end

  def sortable_user_attribute_th(id, name)
    raw <<-TH
    <th><div class="sortable_wrapper"><span class="sortable_column #{h(sort_direction(id, params[:search]))}" id="#{id}">#{name}</span></div></th>
    TH
  end

  def users_search_form(url, &block)
    form_for(:search, @search, :url => url, :html => { :method => 'get', :id => 'user-search', :onsubmit => 'this.submit()' }, &block)
  end

  def valid_oauth_tokens(user)
    tokens = Oauth2::Provider::OauthToken.find_all_with(:user_id, user.id)
    tokens.reject(&:expired?).smart_sort_by { |token| token.oauth_client.name }
  end

  def token_revoke_url_options(token)
    redirect_url = url_for(:action => 'show', :tab => 'OAuth Access Tokens', :only_path => false, :escape => false)
    revoke_action = User.current.admin? ? 'revoke_by_admin' : 'revoke'
    { :controller => 'oauth_user_tokens', :action => revoke_action, :token_id => token.id, :redirect_url => redirect_url  }
  end

  def can_create_user?
    authorized?(:controller => 'users', :action => 'new')
  end

  def can_update_password?
    authorized?(:controller => 'users', :action => 'update_password')
  end

  def can_activate_user?(user)
    return false if user == User.current
    if user.light?
      !(@max_active_light_users_reached && !user.activated?)
    else
      !(@max_active_full_users_reached && !user.activated?)
    end
  end

  def allow_change_to_light?(user)
    return false if user == User.current
    return false if !user.activated?
    !@max_active_full_users_reached || @full_users_used_as_light || !user.light?
  end

  def allow_change_to_admin?(user)
    return false if user == User.current
    return false if !user.activated?
    return false if !authorized?("users:toggle_admin")
    (@max_active_full_users_reached && !user.light?) || @full_users_used_as_light || !@max_active_full_users_reached
  end

  def saas_tos_required?
    MingleConfiguration.need_to_accept_saas_tos? && !SaasTos.accepted?
  end
end
