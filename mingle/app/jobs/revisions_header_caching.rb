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

class RevisionsHeaderCaching

  attr_accessor :repository_configuration

  def self.run_once(options={})
    MinglePlugins::Source.find_all_marked_for_deletion.each do |deleted_config|
      begin
        project = Project.find_by_id(deleted_config.project_id)
        # it would be nice to tie up all 3 of these delete activities into a single
        # model method but i'm not sure which model legitimately owns all three
        unless project.nil?
          project.with_active_project do |active_project|
            Project.transaction do
              Revision.delete_for(active_project)
              deleted_config.destroy
              RevisionsViewCache.delete_cache_for(RepositoryConfiguration.new(deleted_config))
            end
          end
        end
      rescue Exception => e
        log_error(e, "An error occurred while cleaning up an old repository configuration #{deleted_config}.")
      end
    end

    options = { :batch_size => 100 }.merge(options)
    Project.not_hidden.not_template.having_repository.shift_each! do |project|
      begin
        project.with_active_project do |active_project|
          active_project.cache_revisions(options[:batch_size])
        end

        if project.repository_configuration && (connection = project.repository_configuration.repository)
          connection.send(:close) if connection.respond_to?(:close)
        end
      rescue Exception => e
        log_error(e, "An error occurred while caching revisions for project #{project.identifier}.")
      end
    end
  end

  def initialize(repository_configuration)
    @repository_configuration = repository_configuration
  end

  def cache_revisions(batch_size = 100)
    Kernel.logger.debug "About to cache revisions for project #{project.identifier}"
    User.with_first_admin do
      project.with_active_project do

        # check for un-initialized repos, delete *everything* if not initialized ...
        if !repository_configuration.initialized?
          Kernel.logger.debug "Revisions marked invalid for project #{project.identifier}. All revisions will be re-cached."
          Project.transaction { Revision.delete_for(project) }
        # ... now check for invalid card links (due to keyword change) and rebuild if necessary
        elsif repository_configuration.card_revision_links_invalid
          Kernel.logger.debug "Card to Revision links marked invalid for project #{project.identifier}. All links will be generated."
          Project.transaction { project.revisions.find_each(&:create_card_links) }
        end

        if repository_configuration.can_connect?
          create_next_mingle_revisions(batch_size) unless repository_configuration.reload.marked_for_deletion?
          last_revision_number = project.revisions.last.number
          Kernel.logger.debug("Revisions upto number #{last_revision_number} have been cached for project #{project.identifier}.")
        end

        # validate everything regardless of whether repository is valid... it's just a flag to delete
        # everything and we don't need to do that more than once.
        unless repository_configuration.reload.marked_for_deletion?
          Project.transaction do
            project.roll_ahead_history_subscriptions_to_youngest_revision unless repository_configuration.initialized?
            repository_configuration.mark_valid
          end
        end

      end
    end
    Kernel.logger.debug "Done caching revisions for project #{project.identifier}"
  end

  def create_next_mingle_revisions(limit)
    Kernel.logger.debug "Caching next batch of revisions for project #{project.identifier}."
    repos_revisions = repository.next_revisions(project.youngest_revision, limit)
    Project.transaction do
      repos_revisions.each do |revision|
        Revision.create_from_repository_revision(revision, project)
      end
    end
    repos_revisions ? repos_revisions.size : 0
  end

  private

  def project
    repository_configuration.project
  end

  def repository
    repository_configuration.repository
  end

end
