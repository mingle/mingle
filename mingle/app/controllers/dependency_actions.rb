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

module DependencyActions

  include DependencyAccess
  def update
    @dependency = Dependency.find(params[:id])
    @dependency.editor_content_processing = true
    return render(:json => { :message => "Could not find dependency" }.to_json, :status => :not_found) unless @dependency
    if params[:desired_end_date]
      return render(:json => {:message => "Not authorized"}.to_json, :status => 401) if !allowed_to_edit(@dependency.raising_project)
      @dependency.desired_end_date = params[:desired_end_date]
    end

    if params[:dependency]
      @dependency.name = params[:dependency][:name]
      @dependency.description = params[:dependency][:description]
    end

    if @dependency.save
      data = @dependency.to_json_with_formatted_date(date_format_context)
      data = data.stringify_keys
      render :json => data.merge("description" => render_to_string(:partial => 'dependencies/content')), :status => :ok
    else
      set_rollback_only
      respond_to do |format|
        format.json do
          render :json => @dependency.errors.full_messages.to_json,  :status => 422
        end
      end
    end
  end

  def popup_show
    @dependency = Dependency.find_by_number(params[:number])

    displaying_latest_version = params[:version].blank? || params[:version].to_i == @dependency.version || @dependency.find_version(params[:version].to_i).nil?
    if !displaying_latest_version
      version = params[:version].to_i
      @dependency = @dependency.find_version(version)
      return render_in_lightbox('dependencies/dependency_lightbox_version_show',
                          :locals => { :dependency => @dependency, :date_format_context => date_format_context },
                          :lightbox_opts => {:close_on_blur => true, :lightbox_css_class => "view-mode", :after_update => "MingleUI.lightbox.dependencies", :ensure_singleton_with_id => "dep-#{@dependency.prefixed_number}:#{version}" })
    else
      return render_in_lightbox('dependencies/dependency_lightbox_show',
                          :locals => { :dependency => @dependency, :date_format_context => date_format_context, :allowed_to_edit_raising => allowed_to_edit(@dependency.raising_project), :allowed_to_edit_resolving => allowed_to_edit(@dependency.resolving_project) },
                          :lightbox_opts => {:close_on_blur => true, :lightbox_css_class => "view-mode", :after_update => "MingleUI.lightbox.dependencies", :ensure_singleton_with_id => "dep-#{@dependency.prefixed_number}" })
    end
  end

  def remove_attachment
    file_name = params[:file_name]
    if @dependency.remove_attachment(file_name) && @dependency.save
      respond_to do |format|
        format.json { render :json => {:file => params[:file_name]}.to_json }
        format.xml { render :nothing => true, :status => :accepted }
      end
    else
      set_rollback_only
      respond_to do |format|
        format.json { render :json => {:error => "not found", :file => params[:file_name]}.to_json, :status => :not_found }
        format.xml do
          render :nothing => true, :status => :not_found
        end
      end
    end
  end

  def valid_date_format?(date)
    begin
      Date.parse(date) unless date.nil?
    rescue ArgumentError
      return false
    end
    return true
  end
end
