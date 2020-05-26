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

class MacroEditorController < ProjectApplicationController

  allow :get_access_for => [:show, :new_series_editor, :render_macro, :chart_edit_params]
  privileges UserAccess::PrivilegeLevel::READONLY_TEAM_MEMBER => ['render_macro']
  INVALID_MACRO_PARAM_ERROR = 'Invalid macro parameters'

  def show
    @macro_editor = MacroEditor.new(@project, params[:macro_type], {}, params[:content_provider])
    @renderable = existing_or_new_renderable(params[:content_provider])
    macro_editor_html = render_to_string(:partial => 'macro_editor_wysiwyg')
    render :text => macro_editor_html
  end

  def generate
    if params[:macro_format] == 'mql'
      macro_params = Renderable::MacroSubstitution.new.macro_parameters(params[:macro_editor])
      return render :text => INVALID_MACRO_PARAM_ERROR, :status => :unprocessable_entity if macro_params.nil?
      params[:macro_editor] = macro_params
    end
    return render :text => INVALID_MACRO_PARAM_ERROR, :status => :unprocessable_entity if params[:macro_editor].blank? || params[:macro_type].blank? || params[:macro_editor][params[:macro_type]].blank?
    macro_editor = MacroEditor.new(@project, params[:macro_type], params[:macro_editor][params[:macro_type]], params[:content_provider])
    @renderable = existing_or_new_renderable(params[:content_provider])
    params[:macro] = macro_editor.content_with_example
    session[:renderable_preview_content] = params[:macro] if @renderable.new_record?
    render :text => render_macro_content, :status => (@renderable.macro_execution_errors.any? ? 422 : 200)
  end

  def preview
    if params[:macro_format] == 'mql'
      macro_params = Renderable::MacroSubstitution.new.macro_parameters(params[:macro_editor])
      return render :text => INVALID_MACRO_PARAM_ERROR, :status => :unprocessable_entity if macro_params.nil?
      params[:macro_editor] = macro_params
    end
    return render :text => INVALID_MACRO_PARAM_ERROR, :status => :unprocessable_entity if params[:macro_editor].blank? || params[:macro_type].blank? || params[:macro_editor][params[:macro_type]].blank?
    @renderable = existing_or_new_renderable(params[:content_provider])
    @macro_editor = MacroEditor.new(@project, params[:macro_type], params[:macro_editor][params[:macro_type]], { :content_provider => @renderable, :content_provider_type => params[:content_provider] })
    session[:renderable_preview_content] = @macro_editor.content
    preview_html = render_to_string(:partial => 'preview')
    render :text => preview_html, :status => (@renderable.macro_execution_errors.any? ? 422 : 200)
  end

  def new_series_editor
    macro_def = MacroEditor.macro_def_for(params[:macroType])
    html = render_to_string(:partial => 'series_editor', :locals => { :series_number => params[:seriesNumber], :macro_def => macro_def })
    series_data = { :number => params[:seriesNumber], :html => html }
    render :text => series_data.to_json
  end

  def render_macro
    raise unless params[:type].present?
    @renderable = existing_or_new_renderable({:provider_type => params[:type], :id => params[:id]})
    session[:renderable_preview_content] = params[:macro]
    params[:macro_type] = Renderable::MacroSubstitution.new.macro_name(params[:macro])
    render :text => render_macro_content, :status => (@renderable.macro_execution_errors.any? ? 422 : 200)
  end

  def render_macro_content
    (render_to_string :partial => 'render_macro')[1..-1]
  end

  def chart_edit_params
    @easy_charts_macro = EasyCharts::MacroParams.extract(params[:macro])
    @content_provider = params[:content_provider]
    respond_to do |format|
      format.json do
        render layout: false
      end
    end
  rescue EasyCharts::MacroEditorNotSupported
    render :json => {supportedInEasyCharts: false}
  end

  private

  def has_error?(text)
    text.match(/class=\"error\"/)
  end

  def existing_or_new_renderable(content_provider)
    id = content_provider[:id]
    type = content_provider[:provider_type]
    association = @project.send(type.pluralize.underscore.to_sym)
    renderable = if id.present?
      association.find(id.to_i)
    else
      association.new.tap do |new_empty_renderable|
        new_empty_renderable.redcloth = false
      end
    end
    renderable
  end
end
