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

class MessageGroup
  class Keys
    def self.sent_message_count(group_id)
      "message group:#{group_id}:sent message count".gsub(' ', '_')
    end

    def self.processed_message_count(group_id)
      "message group:#{group_id}:processed message count".gsub(' ', '_')
    end

    def self.action(project_id, action)
      "message group:#{project_id}:#{action}".gsub(' ', '_')
    end

    def self.action_key(group_id)
      "message group:#{group_id}:map to action key".gsub(' ', '_')
    end
  end

  def self.create!(properties)
    group_id = properties[:action].uniquify

    action_key = Keys.action(properties[:project_id], properties[:action])
    Cache.add(action_key, group_id)
    Cache.add(Keys.action_key(group_id), action_key)

    Cache.incr(Keys.sent_message_count(group_id))
    Cache.incr(Keys.processed_message_count(group_id))
    MessageGroup.new(group_id)
  end

  def self.find_by_action(project_id, action)
    if group_id = Cache.get(Keys.action(project_id, action))
      find_by_group_id(group_id)
    end
  end

  def self.find_by_receiving_message(message)
    find_by_group_id(message.property('message_group_id'))
  end

  def self.find_by_group_id(group_id)
    if group_id && Cache.get(Keys.action_key(group_id))
      MessageGroup.new(group_id)
    end
  end
  def self.processing(received_message)
    group = MessageGroup.find_by_receiving_message(received_message)
    r = received_message
    if group
      group.activate do
        r = yield(received_message) if block_given?
        group.processed_a_message
      end
    else
      r = yield(received_message) if block_given?
    end
    r
  end

  def self.active_group
    Thread.current["active_message_group"]
  end
  def self.active_group=(group)
    Thread.current["active_message_group"] = group
  end

  attr_reader :group_id

  def initialize(group_id)
    @group_id = group_id
  end

  def activate(&block)
    MessageGroup.active_group = self
    yield if block_given?
    self.destroy if self.done?
    self
  ensure
    MessageGroup.active_group = nil
  end

  def done?
    processed_message_count == sent_message_count
  end

  def destroy
    if action_key = Cache.get(Keys.action_key(@group_id))
      Cache.delete(action_key)
    end
    Cache.delete(Keys.action_key(@group_id))
  end

  def mark(message)
    message.properties.merge!(message_properties)
    increase_sent_message_count
  end

  def processed_a_message
    increase_processed_message_count
  end

  def ==(another)
    another.group_id == @group_id
  end

  private
  def message_properties
    {'message_group_id' => @group_id}
  end

  def increase_processed_message_count
    Cache.incr Keys.processed_message_count(@group_id)
  end

  def increase_sent_message_count
    Cache.incr Keys.sent_message_count(@group_id)
  end

  def sent_message_count
    Cache.incr(Keys.sent_message_count(@group_id), 0).to_i
  end

  def processed_message_count
    Cache.incr(Keys.processed_message_count(@group_id), 0).to_i
  end
end
