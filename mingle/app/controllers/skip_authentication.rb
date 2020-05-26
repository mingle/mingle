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

module SkipAuthentication
  def self.included(base)
    base.skip_before_filter :authenticated?
    base.before_filter :set_current_user_as_user_from_session_or_cookie
  end
  
  #because we skip the authenticated? filter, and the Thread local
  #for the current user is not reset on all threads up on logout
  #sometimes an anonymous user might see the previous user of the
  #thread on the about page. This is the first line of the authenticated?
  #filter, put back as a before filter, specifically for this controller.
  def set_current_user_as_user_from_session_or_cookie
    User.current = load_user_from_session_or_cookie
  end  
  
end
