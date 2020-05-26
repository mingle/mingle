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

class RevisionsViewCache
  include ActionController::Caching::Fragments
  
  class << self
    def delete_cache_for(repos_config)
      SwapDir::RevisionCache.project_cache_dir(repos_config.project).delete
    end

    def benchmark(message, &block)
      yield if block_given?
    end
  end
  
  def initialize(project)
    @project = project
  end
  
  def cache_store
    @cache_store ||= ActiveSupport::Cache.lookup_store([:file_store, SwapDir::RevisionCache.pathname])
  end
  
  def cache_configured?
    true
  end
  
  def perform_caching
    true
  end
  
  def error_caching_fragment?(revision_number)    
   SwapDir::RevisionCache.error_file(@project, revision_number).exists?
  end
  
  def remove_error_file(revision_number)
    SwapDir::RevisionCache.error_file(@project, revision_number).delete
  end
  
  def fragment_cache_key(revision_number) 
    File.join(project_cache_dir, revision_number.to_s)
  end
    
  def cache_content_for(revision_number)
    return unless @project.can_connect_to_source_repository?
    begin
      view = ActionView::Base.new(File.join(Rails.root, "app", "views"), {})
      view.extend(ApplicationHelper, RoutingUrlHelper)
      controller = ActionController::Base.new
      controller.response = ActionController::Response.new
      view.instance_variable_set(:@controller, controller)
      view.instance_variable_set(:@project, @project)
      view.template_format = :html
      view.render(:partial => 'revisions/show', :locals => {:project => @project, 
        :revision => @project.repository_revision(revision_number),
        :mingle_revision => @project.revisions.find_by_number(revision_number),
        :view_cache => self, :background => true, :view_helper => view})
      remove_error_file(revision_number)
    ensure
      SwapDir::RevisionCache.error_file(@project, revision_number).touch unless fragment_exist?(revision_number)
    end
  end
  
  def size
    SwapDir::RevisionCache.project_cache_dir(@project).entries.size
  end
  
  def cache(view_helper, revision_number, options = {}, &block)
    buffer = view_helper.output_buffer
    fragment_for(buffer, revision_number, options, &block)
  rescue
    log_error($!, "Unexpected error when caching revision #{revision_number} with path '#{fragment_cache_key(revision_number)}'.")
  end

  private
    
  def project_cache_dir
    File.join(@project.id.to_s, @project.repository_configuration.plugin_db_id.to_s)
  end  
  
end

