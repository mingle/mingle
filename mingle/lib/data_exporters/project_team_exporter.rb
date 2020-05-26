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

class ProjectTeamExporter < BaseDataExporter

  def name
    'Team'
  end

  def export(sheet)
    sheet.add_headings(sheet_headings)
    project.team_members_with_role_and_group_info.each_with_index do |user, index|
      sheet.insert_row(index.next, [user['Name'], user['Sign-in name'], user['Email'], MembershipRole[user['Permissions'].to_s], user_defined_groups(user['User groups']) ] )
    end
    Rails.logger.info("Exported project team to sheet")
  end

  def exportable?
    project.users.count > 0
  end

  private
  def project
    Project.current
  end

  def user_defined_groups(groups)
    (groups || '').gsub(/,\s*Team\b/i,'')
  end

  def headings
    ['Name', 'Sign-in name', 'Email', 'Permissions', 'User groups']
  end
end
