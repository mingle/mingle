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

module FullTextSearch

  def run_once(options={})
    IndexingSiteProcessor.run_once(options)
    IndexingUsersProcessor.run_once(options)
    IndexingProjectsProcessor.run_once(options)
    IndexingBulkCardsProcessor.run_once(options)
    IndexingCardsProcessor.run_once(options)
    IndexingPagesProcessor.run_once(options)
    IndexingBulkMurmursProcessor.run_once(options)
    IndexingMurmursProcessor.run_once(options)
    IndexingDependenciesProcessor.run_once(options)
    DeindexingSearchablesProcessor.run_once(options)
  end

  def rebuild_index_if_missing
    if MingleConfiguration.installer? && (ElasticSearch.index_missing? || ElasticSearch.index_has_no_documents?)
      rebuild_index
      return true
    end
    false
  end

  def rebuild_index
    Kernel.logger.info "Reindexing #{Project.not_hidden.count} projects"
    Project.not_hidden.find_each(:select => 'id') do |project|
      project.update_full_text_index
    end
  end

  def index_cards(project)
    card_ids = Project.connection.select_values("SELECT id FROM #{Card.quoted_table_name}")
    index_card_selection(project, card_ids)
  end

  def index_card_selection(project, card_ids)
    return if card_ids.blank?
    message = {:project_id => project.id}
    message.merge!(:ids => card_ids.uniq.compact.join(','))
    IndexingBulkCardsProcessor.new.send_message(IndexingBulkCardsProcessor::QUEUE, [Messaging::SendingMessage.new(message)])
  end

  def index_bulk_murmurs(project, murmur_ids)
    return if murmur_ids.blank?
    message = { :project_id => project.id }
    message.merge!(:ids => murmur_ids.uniq.compact.join(','))
    IndexingBulkMurmursProcessor.new.send_message(IndexingBulkMurmursProcessor::QUEUE, [Messaging::SendingMessage.new(message)])
  end

  module_function :run_once, :index_bulk_murmurs, :index_cards, :index_card_selection, :rebuild_index_if_missing, :rebuild_index

  class IndexingSiteProcessor < Messaging::Processor
    QUEUE = "mingle.indexing.site"

    def self.enqueue
      self.new.send_message QUEUE, [Messaging::SendingMessage.new({})]
    end

    def on_message(message)
      FullTextSearch.rebuild_index
    end
  end

  class IndexingUsersProcessor < Messaging::Processor
    QUEUE = "mingle.indexing.users"
    PROJECT_INDEXING_TERMS = %w{login name email version_control_user_name}
    route :from => UserEventPublisher::QUEUE, :to => QUEUE

    def on_message(message)
      message[:changed_columns] && (PROJECT_INDEXING_TERMS & message[:changed_columns].keys).size > 0
      if user = User.find_by_id(message[:id])
        user.with_current do |user|
          only = ['name', 'email', 'login', 'version_control_user_name']
          user.attributes.reject{|key, value| !only.include?(key)}
          projects_to_index(user).each do |project|
            project.with_active_project do |project|
              reindex_cards(user, project)
              reindex_pages(user, project)
              reindex_murmurs(user, project)
            end
          end
          end
      end
    rescue => e
      puts e.message
      puts e.backtrace.join("\n")
      raise e
    end

    def reindex_cards(user, project)
      ids = select_ids(Card, "created_by_user_id = ? OR modified_by_user_id = ?", user.id, user.id)
      IndexingCardsProcessor.request_indexing_for(project, ids) if ids.any?
    end

    def reindex_pages(user, project)
      ids = select_ids(Page, "project_id = ? AND (created_by_user_id = ? OR modified_by_user_id = ?)", project.id, user.id, user.id)
      IndexingPagesProcessor.request_indexing_for(project, ids) if ids.any?
    end

    def reindex_murmurs(user, project)
      ids = select_ids(Murmur, "project_id = ? AND author_id = ?", project.id, user.id)
      IndexingMurmursProcessor.request_indexing_for(project, ids) if ids.any?
    end

    def select_ids(model, condition, *condition_values)
      sql = SqlHelper.sanitize_sql("SELECT ID FROM #{model.table_name} WHERE #{condition}", *condition_values)
      ActiveRecord::Base.connection.select_values(sql)
    end

    def projects_to_index(user)
      user.admin? ? Project.find(:all) : user.projects
    end
  end

  class IndexingProjectsProcessor < Messaging::Processor
    QUEUE = "mingle.indexing.projects"

    def self.request_indexing(messagables=[])
      self.new.send_message QUEUE, messagables.collect(&:message)
    end

    def on_message(message)
      if project = Project.find_by_id(message[:id])
        IndexingCardsProcessor.request_indexing_all(project)
        IndexingPagesProcessor.request_indexing_all(project)
        IndexingMurmursProcessor.request_indexing_all(project)
        IndexingDependenciesProcessor.request_indexing_all(project)
      end
    end

  end

  class DeindexingSearchablesProcessor < Messaging::Processor
    QUEUE = ElasticSearchDeindexPublisher::QUEUE

    def on_message(message)
      Project.with_active_project(message[:project_id]) do |project|
        with_transaction do
          begin
            ElasticSearch.deindex(message[:id], message[:index_name], message[:type])
          rescue ElasticSearch::NetworkError
            raise
          rescue StandardError => e
            Kernel.log_error(e, "\nUnable to deindex #{message[:id]} in #{message[:index_name]} for project #{project.identifier}.", :force_full_trace => true)
          end
        end
      end
    end

    def with_transaction
      Project.transaction { yield }
    end

  end

  class IndexingSearchablesProcessor < Messaging::Processor

    def self.select_column_name
      "project_id"
    end

    def self.request_indexing_for(project, ids)
      project.with_active_project do |project|
        table_name = self::TARGET_TYPE.constantize.quoted_table_name
        messages = ids.map{|id| Messaging::SendingMessage.new({:id => id.to_i, :project_id => project.id})}
        messagables = messages.collect { |message| OpenStruct.new(:message => message) }
        request_indexing(messagables)
      end
    end

    def self.request_indexing_all(project)
      project.with_active_project do |project|
        table_name = self::TARGET_TYPE.constantize.quoted_table_name
        sql = "SELECT id FROM #{table_name} WHERE #{select_column_name} = #{project.id} ORDER BY id DESC"
        messages = project.connection.select_values(sql).collect{|id| Messaging::SendingMessage.new({:id => id.to_i, :project_id => project.id})}
        messagables = messages.collect { |message| OpenStruct.new(:message => message) }
        request_indexing(messagables)
      end
    end

    def self.request_indexing(messagables=[])
      self.new.send_message(self::QUEUE, messagables.collect(&:message))
    end

    def on_message(message)
      Project.with_active_project(message[:project_id]) do |project|
        with_transaction do
          begin
            if searchable = self.class::TARGET_TYPE.constantize.find_by_id(message[:id])
              if searchable.respond_to?(:reindex)
                MingleConfiguration.indexing_log { "reindex #{searchable.inspect}" }
                searchable.reindex
              else
                MingleConfiguration.indexing_log { "searchable does not respond_to reindex #{searchable.inspect}" }
              end
            else
              MingleConfiguration.indexing_log { "could not find #{self.class::TARGET_TYPE} by id #{message[:id]}, ignore it" }
            end
          rescue ElasticSearch::NetworkError
            raise
          rescue StandardError => e
            Kernel.log_error(e, "\nUnable to update search index for #{searchable} in project #{project.identifier}. This request to index #{searchable} will be deleted. This might be OK, but you may need to regenerate the full text search index for your project (via the 'Advanced Admin' page) if you notice that the search feature is not returning expected results.", :force_full_trace => true)
          end
        end
      end
    end

    def with_transaction
      Project.transaction { yield }
    end
  end

  class IndexingCardsProcessor < IndexingSearchablesProcessor
    QUEUE = "mingle.indexing.cards"
    TARGET_TYPE = 'Card'
    route :from => CardEventPublisher::QUEUE, :to => QUEUE
  end

  class IndexingPagesProcessor < IndexingSearchablesProcessor
    QUEUE = "mingle.indexing.pages"
    TARGET_TYPE = 'Page'
    route :from => PageEventPublisher::QUEUE, :to => QUEUE
  end

  class IndexingMurmursProcessor < IndexingSearchablesProcessor
    QUEUE = "mingle.indexing.murmurs"
    TARGET_TYPE = 'Murmur'
    route :from => MurmursPublisher::QUEUE, :to => QUEUE
  end

  class IndexingDependenciesProcessor < IndexingSearchablesProcessor
    QUEUE = "mingle.indexing.dependencies"
    TARGET_TYPE = 'Dependency'
    route :from => DependencyEventPublisher::QUEUE, :to => QUEUE

    def self.select_column_name
      "raising_project_id"
    end
  end

  class IndexingBulkCardsProcessor < Messaging::Processor
    QUEUE = "mingle.indexing.bulk_cards"
    def on_message(message)
      return unless message_ids = message[:ids]
      project_id = message[:project_id]
      messages = message_ids.split(',').collect{|id| Messaging::SendingMessage.new(:id => id.to_i, :project_id => project_id)}
      send_message(IndexingCardsProcessor::QUEUE, messages)
    end
  end

  class IndexingBulkMurmursProcessor < Messaging::Processor
    QUEUE = "mingle.indexing.bulk_murmurs"
    def on_message(message)
      return unless message_ids = message[:ids]
      project_id = message[:project_id]
      messages = message_ids.split(',').map { |id| Messaging::SendingMessage.new(:id => id.to_i, :project_id => project_id) }
      send_message(IndexingMurmursProcessor::QUEUE, messages)
    end
  end

end
