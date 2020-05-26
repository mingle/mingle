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

class RevisionsContentCaching

  def self.run_once(max_cached_per_project = 5, re_raise_on_error = false)
    User.with_first_admin do
      Project.not_hidden.not_template.having_repository.shift_each! do |project|
        project.with_active_project do |active_project|
          if active_project.can_connect_to_source_repository? && active_project.source_repository_initialized?
            cache_project_revision_content(active_project, max_cached_per_project, re_raise_on_error)
          end
        end

        if project.repository_configuration && (connection = project.repository_configuration.repository)
          connection.send(:close) if connection.respond_to?(:close)
        end
      end
    end
  end

  def self.cache_project_revision_content(project, max_cached, re_raise_on_error)
    project.with_active_project do |proj|

      view_cache = RevisionsViewCache.new(proj)
      next if view_cache.size == project.revisions.count

      numbers_select = "SELECT #{Project.connection.quote_column_name('number')} FROM revisions WHERE project_id = #{proj.id} ORDER BY #{Project.connection.quote_column_name('number')} DESC"
      revision_numbers = Project.connection.select_values(numbers_select)
      cached_for_project = 0
      revision_numbers.each do |rev|
        break if project.repository_configuration.reload.marked_for_deletion?
        break if cached_for_project == max_cached
        unless view_cache.fragment_exist?(rev) || view_cache.error_caching_fragment?(rev)
          begin
            Project.logger.info("Caching content for revision #{rev} in project #{proj.identifier}.")
            view_cache.cache_content_for(rev)
          rescue Exception => e
            log_error(e, "Unable to cache revision #{rev} for project #{proj.identifier}.")
            raise e if re_raise_on_error
          ensure
            cached_for_project += 1
          end
        end
      end
    end
  end

end
