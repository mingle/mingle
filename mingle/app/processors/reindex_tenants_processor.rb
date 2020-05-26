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

class ReindexAllTenantsProcessor < Messaging::Processor
  def self.reindex_all_tenants
    return if !MingleConfiguration.reindex_all_tenants? || MingleConfiguration.aws_es_cluster.blank? || MingleConfiguration.reindex_triggered?
    Rails.logger.info 'Reindexing all tenant data'
    Multitenancy.randomized_tenants.each do |tenant_name|
      tenant = Multitenancy.find_tenant(tenant_name)
      unless tenant
        Rails.logger.error "Failed to find tenant with name #{tenant_name}. Skipping reindex"
        next
      end
      tenant.activate do
        ReindexingSiteProcessor.enqueue
      end
    end
    # Trigger just once for an environment
    MingleConfiguration.global_config_merge('reindex_triggered' => true)
  end
end

class ReindexingSiteProcessor < Messaging::Processor
  QUEUE = 'mingle.reindexing.site.aws.es'

  def self.enqueue
    self.new.send_message QUEUE, [Messaging::SendingMessage.new({})]
  end

  def on_message(message)
    return if MingleConfiguration.aws_es_cluster.blank?

    Rails.logger.info 'Reindexing site data'
    Project.not_hidden.find_each(:select => 'id') do |project|
      project.with_active_project do |p|
        ReIndexingProjectsProcessor.request_indexing([p])
      end
    end
    Rails.logger.info 'Successfully triggered reindexing for all projects'
  rescue Exception => e
    Rails.logger.error "Failed to reindex for tenant #{MingleConfiguration.app_namespace}. Error: #{e.message}"
  end
end

class ReIndexingCardsProcessor < FullTextSearch::IndexingCardsProcessor
  QUEUE = 'mingle.reindexing.cards'
end

class ReIndexingPagesProcessor < FullTextSearch::IndexingPagesProcessor
  QUEUE = 'mingle.reindexing.pages'
end

class ReIndexingMurmursProcessor < FullTextSearch::IndexingMurmursProcessor
  QUEUE = 'mingle.reindexing.murmurs'
end

class ReIndexingDependenciesProcessor < FullTextSearch::IndexingDependenciesProcessor
  QUEUE = 'mingle.reindexing.dependencies'
end

class ReIndexingProjectsProcessor < FullTextSearch::IndexingProjectsProcessor
  QUEUE = 'mingle.reindexing.projects'

  def self.request_indexing(messagables=[])
    self.new.send_message QUEUE, messagables.collect(&:message)
  end

  def on_message(message)
    if project = Project.find_by_id(message[:id])
      ReIndexingCardsProcessor.request_indexing_all(project)
      ReIndexingPagesProcessor.request_indexing_all(project)
      ReIndexingMurmursProcessor.request_indexing_all(project)
      ReIndexingDependenciesProcessor.request_indexing_all(project)
    end
  end

end
