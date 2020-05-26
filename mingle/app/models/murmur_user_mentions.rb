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

class MurmurUserMentions
  SEARCH_USER_REGEX = /(^|\W)@([.+@_\w-]+)/
  TEAM_ID = 'team'

  def self.detect(project, login, &block)
    if login == TEAM_ID
      yield(:team, project.users)
    elsif group = project.groups.detect {|g| g.name.ignore_case_equal?(login)}
      yield(:group, group)
    elsif project.users_map.has_key? login.downcase
      yield(:user, project.users_map[login.downcase])
    end
  end

  def initialize(project, text)
    @project, @text = project, text
  end

  def users
    debug("mentioned logins: #{mentions.inspect}")
    mentions.map do |id|
      self.class.detect(@project, id.downcase) do |t, obj|
        t == :group ? obj.users : obj
      end
    end.flatten.compact.uniq.reject(&:deactivated?)
  end
  memoize :users

  def mentions
    @text.to_s.scan(SEARCH_USER_REGEX).map do |m|
      login = m[1]
      login =~ /\.$/ && login.size > 1 ? [login[0..-2], login] : login
    end.flatten
  end
  memoize :mentions

  private
  def debug(msg)
    Rails.logger.debug { msg }
  end

end
