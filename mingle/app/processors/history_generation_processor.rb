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

module HistoryGeneration

  def run_once(options={})
    UserVersionControlNameChangeProcessor.run_once(options)
    ProjectChangesGenerationProcessor.run_once(options)
    BulkCardChangesGenerationProcessor.run_once(options)
    CardChangesGenerationProcessor.run_once(options)
    PageChangesGenerationProcessor.run_once(options)
    RevisionChangesGenerationProcessor.run_once(options)
    DependencyChangesGenerationProcessor.run_once(options)
  end

  def generate_changes(project)
    ProjectChangesGenerationProcessor.new.send_message(ProjectChangesGenerationProcessor::QUEUE, [Messaging::SendingMessage.new(:id => project.id)])
  end

  def generate_changes_for_card_selection(project, updater_id)
    # compared to previous impl with explicit join, this is O(n) v O(n^2) by avoiding
    # nested loops and utilizing as much index as available.
    # checking for deliverable_type is unnecessary as deliverables.id
    # is a PK (unique)

    most_recent_created_card_version_event_id_sql = %Q{
      SELECT e.id
        FROM events e
       WHERE EXISTS (SELECT 1 FROM #{Card::Version.quoted_table_name} v WHERE e.origin_id = v.id AND v.updater_id = ?)
         AND e.origin_type = 'Card::Version'
         AND e.deliverable_id = ?
    }

    ids = project.connection.select_values(SqlHelper.sanitize_sql(most_recent_created_card_version_event_id_sql, updater_id, project.id)).join(',')

    return if ids.blank?

    BulkCardChangesGenerationProcessor.new.send_message(BulkCardChangesGenerationProcessor::QUEUE, [Messaging::SendingMessage.new(:project_id => project.id, :ids => ids)])
  end

  module_function :run_once, :generate_changes, :generate_changes_for_card_selection

  class ProjectChangesGenerationProcessor < Messaging::Processor
    QUEUE = 'mingle.history_changes_generation.project_change_event'
    def on_message(message)
      Project.with_active_project(message[:id]) do |project|
        project.events_without_eager_loading.update_all(:history_generated => false)
        CardChangesGenerationProcessor.request_generating_for_project(project)
        PageChangesGenerationProcessor.request_generating_for_project(project)
        RevisionChangesGenerationProcessor.request_generating_for_project(project)
        DependencyChangesGenerationProcessor.request_generating_for_project(project)
      end
    end
  end

  class ChangesGenerationProcessor < Messaging::Processor
    def self.request_generating_for_project(project)
      self::TARGET_TYPE.find_in_batches(:conditions => {:deliverable_id => project.id}) do |batch|
        self.new.send_message(self::QUEUE, batch.collect(&:message))
      end
    end

    def on_message(message)
      Project.with_active_project(message[:project_id]) do |project|
        begin
          Event.lock_and_generate_changes!(message[:id])
        rescue StandardError => e
          base_msg = "\nUnable to do history generation for #{self.class::TARGET_TYPE.name}(id:#{message[:id]}) in project #{project.identifier}."
          if e.lock_wait_timeout?
            send_message(self.class::QUEUE, [Messaging::SendingMessage.new(message.body_hash)])
            Kernel.log_error(e, "#{base_msg} This request to generate history will be republished and satisfied at a later time.", :force_full_trace => true)
          else
            Kernel.log_error(e, "#{base_msg} This request to generate history will be deleted. This might be OK, but you may need to regenerate history for your project (via the 'Advanced Admin' page) if you notice that the history feature is not returning expected results.", :force_full_trace => true)
          end
        end
      end
    end
  end

  class CardChangesGenerationProcessor < ChangesGenerationProcessor
    QUEUE = 'mingle.history_changes_generation.cards'
    TARGET_TYPE = CardVersionEvent
    route :from => MingleEventPublisher::CARD_VERSION_QUEUE, :to => QUEUE
  end

  class DependencyChangesGenerationProcessor < ChangesGenerationProcessor
    QUEUE = 'mingle.history_changes_generation.dependency'
    TARGET_TYPE = DependencyVersionEvent
    route :from => MingleEventPublisher::DEPENDENCY_VERSION_QUEUE, :to => QUEUE
  end

  class PageChangesGenerationProcessor < ChangesGenerationProcessor
    QUEUE = 'mingle.history_changes_generation.pages'
    TARGET_TYPE = PageVersionEvent
    route :from => MingleEventPublisher::PAGE_VERSION_QUEUE, :to => QUEUE
  end

  class RevisionChangesGenerationProcessor < ChangesGenerationProcessor
    QUEUE = 'mingle.history_changes_generation.revisions'
    TARGET_TYPE = RevisionEvent
    route :from => MingleEventPublisher::REVISION_QUEUE, :to => QUEUE
  end

  class BulkCardChangesGenerationProcessor < Messaging::Processor
    QUEUE = 'mingle.history_changes_generation.bulk_cards'
    def on_message(message)
      message_ids = message[:ids]
      project_id = message[:project_id]
      messages = message_ids.split(',').collect{|id| Messaging::SendingMessage.new(:id => id.to_i, :project_id => project_id)}
      send_message(MingleEventPublisher::CARD_VERSION_QUEUE, messages)
    end
  end

  class UserVersionControlNameChangeProcessor < Messaging::Processor
    QUEUE = 'mingle.history_generation.user_version_control_name_change_events'
    route :from => UserEventPublisher::QUEUE, :to => QUEUE

    def on_message(message)
      next unless message && message[:changed_columns]
      if vcnames = message[:changed_columns]['version_control_user_name']

        [vcnames['old'], vcnames['new']].compact.each do |vc_name|
          Revision.find_in_batches(:conditions => ['commit_user = ?', vc_name], :include => :project) do |revisions|
            revisions.each do |rev|
              Project.with_active_project(rev.project_id) do
                rev.update_created_by
              end
            end
            FullTextSearch::IndexingRevisionsProcessor.request_indexing(revisions)
          end
        end
      end
    end
  end
end
