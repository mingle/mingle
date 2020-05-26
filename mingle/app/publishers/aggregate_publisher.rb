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

class AggregatePublisher
  CARD_QUEUE = 'mingle.compute_aggregates.cards'
  PROJECT_QUEUE = 'mingle.compute_aggregates.projects'

  include Messaging::Base

  def initialize(aggregate_property_definition, user)
    @aggregate_property_definition = aggregate_property_definition
    @project = aggregate_property_definition.project
    @user = user
  end

  def publish_card_message(card_or_card_id)
    card_id = card_or_card_id.is_a?(Card) ? card_or_card_id.id : card_or_card_id
    publish_card_messages(SqlHelper.sanitize_sql("id = ?", card_id))
  end

  def publish_card_messages(card_ids_condition_sql)
    make_stale(card_ids_condition_sql) do
      messages = Card.connection.select_values("SELECT id FROM #{Card.connection.safe_table_name(Card.table_name)} WHERE #{card_ids_condition_sql}").collect { |card_id| create_card_message(card_id.to_i) }
      logging_message = "[AggregatePublisher]: #{messages.size} aggregates published by property definition '#{@aggregate_property_definition.name}' in project '#{@aggregate_property_definition.project.identifier}' for cards where: #{card_ids_condition_sql}."
      if messages.size > 500
        Project.logger.info(logging_message)
      else
        Project.logger.debug(logging_message)
      end
      send_message(CARD_QUEUE, messages)
    end
  end

  def publish_project_message
    condition_sql = @aggregate_property_definition.card_ids_for_card_type_condition_sql
    make_stale(condition_sql) do
      send_message(PROJECT_QUEUE, [create_project_message])
    end
  end

  private
  def create_project_message
    Messaging::SendingMessage.new(:aggregate_property_definition_id => @aggregate_property_definition.id, :project_id => @project.id, :user_id => @user.id)
  end

  def create_card_message(card_id)
    create_project_message.merge(:card_id => card_id, :user_id => @user.id)
  end

  def make_stale(card_ids_condition_sql, &block)
    return if Card.count(:conditions => card_ids_condition_sql) == 0
    StalePropertyDefinition.make_stale(@project.id, @aggregate_property_definition.id, card_ids_condition_sql)
    yield
  end
end
