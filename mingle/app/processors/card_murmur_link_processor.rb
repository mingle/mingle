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

module CardMurmurLinkProcessor
  def run_once(options={})
    ProjectCardMurmurLinksProcessor.run_once(options)
    CardMurmurLinkProcessor.run_once(options)
  end
  
  module_function :run_once
  
  class CardMurmurLinkProcessor < Messaging::Processor
    QUEUE = 'mingle.murmur.card_linking'
    route :from => MurmursPublisher::QUEUE, :to => QUEUE
    def on_message(message)
      project = Project.find_by_id(message.property('projectId'))
      murmur = Murmur.find_by_id(message.property('murmurId'))
      return unless project && murmur
      card_numbers = project.card_keywords.card_numbers_in(murmur.murmur)
      if card_numbers.any?
        card_ids = Card.connection.select_values("SELECT id from #{project.cards_table} WHERE #{Card.connection.quote_column_name('number')} IN (#{card_numbers.join(',')})")
        card_ids = card_ids.reject { |id| id.to_i == murmur.origin_id }
        card_ids.each do |card_id|
          CardMurmurLink.create(:project_id => project.id, :card_id => card_id, :murmur_id => murmur.id)
          self.class.new.send_message(FullTextSearch::IndexingCardsProcessor::QUEUE, [Messaging::SendingMessage.new({:project_id => project.id, :id => card_id})])
        end
      end
    end
  end

  class ProjectCardMurmurLinksProcessor < Messaging::Processor
    QUEUE = 'mingle.murmur.project_card_links'
  
    def self.request_rebuild_links(project)
      self.new.send_message(self::QUEUE, [Messaging::SendingMessage.new({}, :projectId => project.id)])
    end
  
    def on_message(message)
      project = Project.find_by_id(message.property('projectId'))
      return unless project
      
      murmur_ids = Project.connection.select_values("SELECT id FROM #{Murmur.table_name} WHERE #{Project.connection.quote_column_name('project_id')} = #{project.id}")
      murmur_ids.each do |murmur_id|
        message = Messaging::SendingMessage.new({}, :projectId  => project.id, :murmurId => murmur_id)
        send_message(CardMurmurLinkProcessor::QUEUE, [message])
      end
    end
  end
end
