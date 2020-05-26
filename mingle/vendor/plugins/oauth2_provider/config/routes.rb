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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the MIT License (http://www.opensource.org/licenses/mit-license.php)

ActionController::Routing::Routes.draw do |map|

  admin_prefix= ENV['ADMIN_OAUTH_URL_PREFIX']
  user_prefix= ENV['USER_OAUTH_URL_PREFIX']

  admin_prefix = "" if admin_prefix.blank?
  user_prefix = "" if user_prefix.blank?

  admin_prefix = admin_prefix.gsub(%r{^/}, '').gsub(%r{/$}, '')
  user_prefix = user_prefix.gsub(%r{^/}, '').gsub(%r{/$}, '')

  map.resources :oauth_clients, :controller => 'oauth_clients', :as => admin_prefix + (admin_prefix.blank? ? "" : "/") + "oauth/clients"

  map.connect "#{admin_prefix}/oauth/user_tokens/revoke_by_admin", :controller => 'oauth_user_tokens', :action => :revoke_by_admin, :conditions => {:method => :delete}

  map.connect "#{user_prefix}/oauth/authorize", :controller => 'oauth_authorize', :action => :authorize, :conditions => {:method => :post}
  map.connect "#{user_prefix}/oauth/authorize", :controller => 'oauth_authorize', :action => :index, :conditions => {:method => :get}
  map.connect "#{user_prefix}/oauth/token", :controller => 'oauth_token', :action => :get_token, :conditions => {:method => :post}
  map.connect "#{user_prefix}/oauth/user_tokens/revoke/:token_id", :controller => 'oauth_user_tokens', :action => :revoke, :conditions => {:method => :delete}
  map.connect "#{user_prefix}/oauth/user_tokens", :controller => 'oauth_user_tokens', :action => :index, :conditions => {:method => :get}

end
