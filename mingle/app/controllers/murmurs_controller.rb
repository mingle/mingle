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

class MurmursController < ProjectApplicationController
  allow :get_access_for => [:index, :show, :at_user_suggestion, :conversation]
  privileges UserAccess::PrivilegeLevel::FULL_TEAM_MEMBER => ['create', 'github']

  def index
    respond_to do |format|
      format.xml do
        render_model_xml @project.murmurs.query(params), :root => "murmurs", :truncate => true
      end
      format.json do
        json = @project.murmurs.query(params).map do |m|
          render_to_string(:partial => 'murmur_chat', :locals => {:murmur => m})
        end
        render :json => json, :status => :ok
      end
    end
  end

  def at_user_suggestion
    key = Keys::AtUserSuggestion.new.path_for(@project)
    json = Cache.get(key) do
        @groups = autocomplete_format(@project.groups)
        matching_users = filter_and_sort(@project.users)
        @users = autocomplete_format(matching_users)
        (@groups + @users).to_json
    end
    render :json => json
  end

  def filter_and_sort(users)
    project_users = users.reject(&:deactivated?)
    project_users.sort_by { |user| user.murmur_author_name }
  end

  def create
    add_monitoring_event('create_global_murmur_in_app', {'project_name' => @project.name})
    attributes = params[:murmur].merge(:author => User.current)

    @murmur = @project.murmurs.create(attributes)
    respond_to do |format|
      format.xml do
        render_model_xml @murmur
      end
      format.json do
        render :json => { :conversation_id => @murmur.conversation_id,
          :murmur_ids => @murmur.conversation_id && @murmur.conversation.murmur_ids }
      end
    end
  end

  def show
    @murmur = @project.murmurs.find(params[:id])
    murmur = @murmur
    respond_to do |format|
      format.xml do
        render_model_xml @murmur
      end
      format.js do
        render(:update) do |page|
          page.replace_html "murmur_content_#{murmur.id}", :partial => 'expanded_murmur_content', :locals => { :murmur => murmur, :page_source => params[:page_source] }
        end
      end
    end
  end

  def conversation
    conversation = @project.conversations.find(params[:conversation_id])
    respond_to do |format|
      format.json do
        json = conversation.murmurs.map do |m|
          render_to_string(:partial => 'murmur_chat', :locals => {:murmur => m})
        end
        render :json => json, :status => :ok
      end
    end
  end

  private

  def autocomplete_format(array)
    array.map do |o|
      case o
      when User
        icon_url = o.icon_url(:view_helper => @template)
        {
          :label => o.murmur_author_name,
          :value => "@#{o.login}",
          :icon => icon_url,
          :icon_options => o.icon_image_options(icon_url),
        }
      else
        {:label => "@#{o.name}", :value => "@#{o.name.downcase}", :icon => 'fa-users'}
      end
    end
  end
end
