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

class CacheKey < ActiveRecord::Base
  belongs_to :deliverable, :foreign_type => 'deliverable_type'

  class << self
    def project_structure_key(project)
      project.cache_key.structure_key
    end

    def touch(key_name, project)
      project.cache_key.send("touch_#{key_name}")
    end
  end

  class ProjectObserver <  ActiveRecord::Observer
    observe Project

    on_callback(:after_update) do |project|
      CacheKey.touch(:structure_key, project)
      if project.identifier_changed?
        CacheKey.touch(:feed_key, project)
      end
    end
  end

  class CorrectionEventObserver < ActiveRecord::Observer
    observe CorrectionEvent

    on_callback(:after_create) do |event|
      CacheKey.touch(:feed_key, ThreadLocalCache.get_assn(event, :project))
    end
  end

  class UserObserver < ActiveRecord::Observer
    observe User
    on_callback(:after_update) do |user|
      if user.name_changed? || user.email_changed? || user.version_control_user_name_changed? || user.icon_changed?
        Project.find_each do |project|
          CacheKey.touch(:feed_key, project)
        end
      end
    end
  end

  class ProjectStructureObserver < ActiveRecord::Observer
    observe PropertyDefinition, CardType, PropertyTypeMapping, TreeConfiguration, EnumerationValue, Transition, TransitionPrerequisite, ProjectVariable, VariableBinding, CardDefaults

    on_callback(:after_create, :after_update, :after_destroy) do |model|
      CacheKey.touch(:structure_key, ThreadLocalCache.get_assn(model, :project))
    end
  end

  class ProjectStructureObserverForMember < ActiveRecord::Observer
    observe Group, MemberRole, UserMembership

    on_callback(:after_create, :after_update, :after_destroy) do |model|
      deliverable = ThreadLocalCache.get_assn(model, :deliverable)
      CacheKey.touch(:structure_key, deliverable) if deliverable.respond_to?(:cache_key)
    end
  end

  class TagObserver <  ActiveRecord::Observer
    observe Tag
    on_callback(:after_update, :after_destroy) do |model|
      CacheKey.touch(:structure_key, ThreadLocalCache.get_assn(model, :project))
    end
  end

  class BulkDestroyObserver < ActiveRecord::Observer
    observe Bulk::BulkDestroy

    def update(project, card_id_criteria)
      CacheKey.touch(:card_key, project)
    end
  end

  class CardObserver < ActiveRecord::Observer
    observe Card
    on_callback(:after_destroy) do |card|
      CacheKey.touch(:card_key, card.project)
    end
  end

  def touch_structure_key
    update_attribute_using_prepared_statement(:structure_key, deliverable.identifier.uniquify)
    ProjectCacheFacade.instance.clear_cache(deliverable.identifier)
  end

  def touch_feed_key
    update_attribute_using_prepared_statement :feed_key, 'feed_key'.uniquify
    FeedsCachePopulatingProcessor.new.send_message(FeedsCachePopulatingProcessor::QUEUE,
        [Messaging::SendingMessage.new({:project_id => deliverable_id})])
  end

  def touch_card_key
    update_attribute_using_prepared_statement :card_key, 'card_key'.uniquify
  end

  private

  def update_attribute_using_prepared_statement(attribute, value)
    begin
      conn = self.class.connection
      sql = "UPDATE #{conn.safe_table_name('cache_keys')} SET #{attribute} = ?, updated_at = ? WHERE id = ?"
      statement = conn.jdbc_connection.prepareStatement(sql)
      now = Clock.now.utc
      statement.setString(1, value)
      statement.setDate(2, now.to_java(java::sql::Date))
      statement.setInt(3, self.id)

      statement.execute
      logger.debug { "  SQL with prepareStatement (#{ (Clock.now.utc - now) * 1000 }ms): SQL: #{sql} BINDING: #{[value, now, id].inspect} " }
      write_attribute_without_dirty(attribute, value)
      write_attribute_without_dirty(:updated_at, now)

    ensure
      statement.close if statement
    end
  end
end
