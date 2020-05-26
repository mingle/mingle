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

class RenderingController < ProjectApplicationController
  helper :url_rewriter_with_full_path
  allow :get_access_for => [:render_content, :chart]
  
  class GenericRenderable
    include Renderable
    attr_accessor :project, :has_macros, :content
    
    def initialize(project)
      @project = project
    end
    
    def id
      nil
    end
    
    def redcloth
      false
    end

    def content_changed?
      true
    end
    
    def chart_executing_option
      {:controller => 'rendering', :action => 'chart'}
    end
  end
  
  
  def render_content
    @renderable = parse_content_provider
    return render(:text =>  'Content provider cannot be found', :status => :not_found) unless @renderable
    @renderable.content = params[:content] if params[:content]    
    session[:renderable_chart_content] = @renderable.content if params[:embed_chart] == 'false'
    render :render_content, :layout => false
  end
  
  def chart
    content_provider = GenericRenderable.new(@project)
    content_provider.content = session[:renderable_chart_content]
    generated_chart = Chart.extract_and_generate(content_provider.content, params[:type], params[:position].to_i, :content_provider => content_provider)
    send_data(generated_chart, :type => "image/png", :disposition => "inline")
  end

  private
  def parse_content_provider
    content_provider = params[:content_provider]
    return GenericRenderable.new(@project) if !content_provider
    Renderable::RenderedDescriptionAnchor.find_renderable(content_provider[:type], content_provider[:id])
  end
end
