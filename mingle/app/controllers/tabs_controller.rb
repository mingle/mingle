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

class TabsController < ProjectApplicationController
  allow :put_access_for => [:reorder, :rename]
  privileges UserAccess::PrivilegeLevel::PROJECT_ADMIN => ["reorder", "rename"]


  def reorder
    display_tabs.reorder!(params[:new_order])
    head :ok
  end

  def rename
    tab = display_tabs.find_by_identifier(params[:tab][:identifier])
    return render(:json => { :message => "Could not find tab." }.to_json, :status => :not_found) unless tab

    new_name = params[:tab][:new_name].trim

    if display_tabs.find_by_name(new_name)
      tab.errors.add(:name, 'is already in use')
    else
      @project.save(false) if @project.ordered_tab_identifiers_changed? # save tab order if not already set
      tab.rename(new_name)
    end

    if tab.errors.blank?
      render :json => {:name => tab.name, :link => url_for(tab.params) }.to_json
    else
      render :json => { :message => tab.errors.full_messages.join("\n") }.to_json, :status => :unprocessable_entity
    end
  end

end
