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

class ActiveRecord::Base
  class << self
    def all_columns_except(*excluded_columns)
      (self.columns.collect(&:name) - excluded_columns.collect(&:to_s)).collect{|c| "#{quoted_table_name}.#{self.connection.quote_column_name(c)}"}
    end

    def select_for_template_sql
      ignores = []
      ignores += self.trace_columns if self.respond_to?(:trace_columns)
      ignores += [self.version_column] if self.respond_to?(:version_column)
      "SELECT #{self.all_columns_except(*ignores).join(',')} FROM #{self.quoted_table_name} WHERE #{self.quoted_table_name}.project_id = ?"
    end

    def select_by_project_sql
      "SELECT #{self.all_columns_except.join(',')} FROM #{self.quoted_table_name} WHERE project_id = ?"
    end

    def columns_hash_to_import
      columns_hash
    end

    def sequence_name_for_project_import
      sequence_name
    end
  end
end

Transition # force loading the class from the normal "models" directory
TransitionAction
class TransitionAction < ActiveRecord::Base
  def self.order_by_id_sql
    "id"
  end

  def self.select_by_project_sql
    all_columns_except_id = self.all_columns_except("id")
    %{
      SELECT #{all_columns_except_id.join(', ')}, #{quoted_table_name}.id, #{Transition.quoted_table_name}.project_id AS project_id
      FROM #{quoted_table_name}
      JOIN #{Transition.quoted_table_name} ON #{Transition.quoted_table_name}.id = #{quoted_table_name}.executor_id AND #{quoted_table_name}.executor_type = '#{Transition.name}'
      WHERE #{Transition.quoted_table_name}.project_id = ?
      UNION
      SELECT #{all_columns_except_id.join(', ')}, #{quoted_table_name}.id, #{CardDefaults.quoted_table_name}.project_id AS project_id
      FROM #{quoted_table_name}
      JOIN #{CardDefaults.quoted_table_name} ON #{CardDefaults.quoted_table_name}.id = #{quoted_table_name}.executor_id AND #{quoted_table_name}.executor_type = '#{CardDefaults.name}'
      WHERE #{CardDefaults.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{quoted_table_name}
      JOIN #{Transition.quoted_table_name} ON #{Transition.quoted_table_name}.id = #{quoted_table_name}.executor_id AND #{quoted_table_name}.executor_type = '#{Transition.name}'
      WHERE #{Transition.quoted_table_name}.project_id = ?
      UNION
      SELECT #{self.all_columns_except().join(',')}
      FROM #{quoted_table_name}
      JOIN #{CardDefaults.quoted_table_name} ON #{CardDefaults.quoted_table_name}.id = #{quoted_table_name}.executor_id AND #{quoted_table_name}.executor_type = '#{CardDefaults.name}'
      WHERE #{CardDefaults.quoted_table_name}.project_id = ?
    }
  end


end

class TransitionPrerequisite < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{Transition.quoted_table_name} ON #{Transition.quoted_table_name}.id = #{quoted_table_name}.transition_id
      WHERE #{Transition.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{quoted_table_name}
      JOIN #{Transition.quoted_table_name} ON #{Transition.quoted_table_name}.id = #{quoted_table_name}.transition_id
      WHERE #{Transition.quoted_table_name}.project_id = ?
      AND #{quoted_table_name}.user_id IS NULL
    }
  end
end

EnumerationValue
class EnumerationValue < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{PropertyDefinition.quoted_table_name} ON #{PropertyDefinition.quoted_table_name}.id = #{quoted_table_name}.property_definition_id
      WHERE #{PropertyDefinition.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{quoted_table_name}
      JOIN #{PropertyDefinition.quoted_table_name} ON #{PropertyDefinition.quoted_table_name}.id = #{quoted_table_name}.property_definition_id
      WHERE #{PropertyDefinition.quoted_table_name}.project_id = ?
    }
  end
end

User # force loading the class from the normal "models" directory
class User < ActiveRecord::Base
  def self.select_by_project_sql
    union_parts = []
    [Card, Card::Version, Page, Page::Version].each do |traceable|
      union_parts << "SELECT DISTINCT(created_by_user_id) AS user_id FROM #{traceable.quoted_table_name} WHERE project_id = #{Project.current.id}"
      union_parts << "SELECT DISTINCT(modified_by_user_id) FROM #{traceable.quoted_table_name} WHERE project_id = #{Project.current.id}"
    end

    connection = ActiveRecord::Base.connection
    [Card.quoted_table_name, Card::Version.quoted_table_name].each do |prop_value_table|
      Project.current.user_property_definitions_with_hidden.each do |property_definition|
        union_parts << "SELECT DISTINCT(#{connection.cast_as_integer(property_definition.quoted_column_name)}) FROM #{prop_value_table}"
      end
    end

    union_parts << UserMembership.user_ids_sql(:conditions => {:group_id => Project.current.team.id})
    union_parts << "SELECT DISTINCT(author_id) FROM #{Murmur.quoted_table_name} WHERE project_id = #{Project.current.id}"
    union_parts << "SELECT DISTINCT(user_id) FROM #{HistorySubscription.quoted_table_name} WHERE project_id = #{Project.current.id}"

    <<-SQL
      SELECT ID, EMAIL, ADMIN, VERSION_CONTROL_USER_NAME, LOGIN, NAME, ACTIVATED, LIGHT, ICON, JABBER_USER_NAME, SYSTEM, READ_NOTIFICATION_DIGEST
        FROM (#{union_parts.join(' UNION ')}) t
        INNER JOIN #{quoted_table_name} ON t.user_id = #{quoted_table_name}.id
    SQL
  end
end

Tagging # force loading the class from the normal "models" directory
class Tagging < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{Tag.quoted_table_name} ON #{Tag.quoted_table_name}.id = #{quoted_table_name}.tag_id
      WHERE #{Tag.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    <<-SQL
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{Tag.quoted_table_name} ON #{Tag.quoted_table_name}.id = #{quoted_table_name}.tag_id
      JOIN (
        SELECT pv_1.id AS taggable_id, #{connection.as_char("'Page::Version'", 32)} AS taggable_type, pv_1.version AS version, pv_1.project_id as project_id
        FROM #{Page::Version.quoted_table_name} pv_1
        INNER JOIN (SELECT page_id, MAX(version) AS version, project_id as project_id
                   FROM #{Page::Version.quoted_table_name}
                   GROUP BY page_id, project_id ) pv_2
        ON pv_1.page_id = pv_2.page_id
        AND pv_1.version = pv_2.version
        UNION
        SELECT cv_1.id as taggable_id, #{connection.as_char("'Card::Version'", 32)} AS taggable_type, cv_1.version AS version, project_id
        FROM #{Card::Version.quoted_table_name} cv_1
        INNER JOIN (SELECT card_id, MAX(version) AS version
                   FROM #{Card::Version.quoted_table_name}
                   GROUP BY card_id, project_id ) cv_2
        ON cv_1.card_id = cv_2.card_id
        AND cv_1.version = cv_2.version
        UNION
        SELECT id as taggable_id, #{connection.as_char("'Card'", 32)} AS taggable_type, version, project_id
        FROM #{Card.quoted_table_name}
        UNION
        SELECT id as taggable_id, #{connection.as_char("'Page'", 32)} AS taggable_type, version, project_id as project_id
        FROM #{Page.quoted_table_name}
      ) latest_taggables ON (latest_taggables.taggable_id = #{quoted_table_name}.taggable_id AND latest_taggables.taggable_type = #{quoted_table_name}.taggable_type AND latest_taggables.project_id = #{Tag.quoted_table_name}.project_id)
      WHERE #{Tag.quoted_table_name}.project_id = ?
    SQL
  end
end

Attaching # force loading the class from the normal "models" directory
class Attaching < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{Attaching.quoted_table_name}.*
      FROM #{Attaching.quoted_table_name}
      JOIN #{Attachment.quoted_table_name} ON #{Attachment.quoted_table_name}.id = #{Attaching.quoted_table_name}.attachment_id
      WHERE #{Attachment.quoted_table_name}.project_id = ?
      AND #{Attaching.quoted_table_name}.attachable_type != 'Dependency'
      AND #{Attaching.quoted_table_name}.attachable_type != 'Dependency::Version'
    }
  end

  def self.select_for_template_sql
    <<-SQL
      SELECT #{Attaching.quoted_table_name}.*
      FROM #{Attaching.quoted_table_name}
      JOIN #{Attachment.quoted_table_name} ON #{Attachment.quoted_table_name}.id = #{Attaching.quoted_table_name}.attachment_id
      JOIN (
        SELECT pv_1.id AS attachable_id, #{connection.as_char("'Page::Version'", 32)} AS attachable_type, pv_1.version AS version, pv_1.project_id as project_id
        FROM #{Page::Version.quoted_table_name} pv_1
        INNER JOIN (SELECT page_id, MAX(version) AS version, project_id as project_id
                    FROM #{Page::Version.quoted_table_name}
                    GROUP BY page_id, project_id ) pv_2
        ON pv_1.page_id = pv_2.page_id
        AND pv_1.version = pv_2.version
        UNION
        SELECT cv_1.id as attachable_id, #{connection.as_char("'Card::Version'", 32)} AS attachable_type, cv_1.version AS version, project_id
        FROM #{Card::Version.quoted_table_name} cv_1
        INNER JOIN (SELECT card_id, MAX(version) AS version
                    FROM #{Card::Version.quoted_table_name}
                    GROUP BY card_id, project_id ) cv_2
        ON cv_1.card_id = cv_2.card_id
        AND cv_1.version = cv_2.version
        UNION
        SELECT id as attachable_id, #{connection.as_char("'Card'", 32)} AS attachable_type, version, project_id
        FROM #{Card.quoted_table_name}
        UNION
        SELECT id as attachable_id, #{connection.as_char("'Page'", 32)} AS attachable_type, version, project_id as project_id
        FROM #{Page.quoted_table_name}
        ) latest_attachables ON (latest_attachables.attachable_id = #{Attaching.quoted_table_name}.attachable_id AND latest_attachables.attachable_type = #{Attaching.quoted_table_name}.attachable_type AND latest_attachables.project_id = #{Attachment.quoted_table_name}.project_id)
      WHERE #{Attachment.quoted_table_name}.project_id = ?
    SQL
  end
end

Attachment
class Attachment < ActiveRecord::Base
  def self.select_for_template_sql
    %{
      SELECT #{Attachment.quoted_table_name}.*
      FROM #{Attachment.quoted_table_name}
      WHERE 0 < (SELECT COUNT(*)
                 FROM #{Attaching.quoted_table_name}
                 WHERE (#{Attaching.quoted_table_name}.attachable_type = 'Card' OR
                       #{Attaching.quoted_table_name}.attachable_type = 'Page') AND
                       #{Attaching.quoted_table_name}.attachment_id = #{Attachment.quoted_table_name}.id
                ) AND
            #{Attachment.quoted_table_name}.project_id = ?
    }
  end
end

Page
class Page
  def self.select_for_template_sql
    new_select_for_template_sql
  end

  def self.new_select_for_template_sql
    id = Project.current.overview_page.try(:id) || -1
     %{
       SELECT #{all_columns_except(version_column, *trace_columns).join(',')}, 1 as version
       FROM #{quoted_table_name}
       WHERE #{Page.quoted_table_name}.project_id = ?
      AND #{Page.quoted_table_name}.id = #{id}
     }
   end

  def self.select_by_project_sql
    "SELECT #{self.all_columns_except.join(',')} FROM #{self.quoted_table_name} WHERE project_id = ?"
  end
end

class Page::Version
  def self.select_for_template_sql
    new_select_for_template_sql
  end


  def self.new_select_for_template_sql
    id = Project.current.overview_page ? Project.current.overview_page.latest_version.id : -1
    columns = all_columns_except(:version, *Page.trace_columns) + ['1 as version']
     %{
      SELECT #{columns.join(',')}
       FROM #{quoted_table_name}
       WHERE #{quoted_table_name}.project_id = ?
        AND #{quoted_table_name}.id = #{id}
     }
  end

  def self.latest_versions_sql(*select_columns)
    %{
      SELECT #{select_columns.join(',')}
      FROM #{quoted_table_name}
      JOIN (
        SELECT page_id, max(version) AS version
        FROM #{quoted_table_name}
        GROUP BY page_id) latest_versions ON (#{quoted_table_name}.page_id = latest_versions.page_id AND #{quoted_table_name}.version = latest_versions.version)
      WHERE #{quoted_table_name}.project_id = ?
    }
  end

  def self.select_by_project_sql
    "SELECT #{self.all_columns_except.join(',')} FROM #{self.quoted_table_name} WHERE project_id = ?"
  end

end

Card
class Card
  def self.select_for_template_sql
    user_property_columns = Project.current.user_property_definitions_with_hidden.collect(&:column_name)
    ignore_columns = user_property_columns + [version_column] + trace_columns
    all_columns_except_ignore_columns = all_columns_except(*ignore_columns)
    %{
      SELECT #{all_columns_except_ignore_columns.join(',')}, 1 as version
      FROM #{Card.quoted_table_name}
      WHERE #{Card.quoted_table_name}.project_id = ?
    }
  end

  def self.sequence_name_for_project_import
    "card_id_sequence"
  end
end

class Card::Version
  def self.select_for_template_sql
    user_property_columns = Project.current.user_property_definitions_with_hidden.collect(&:column_name)
    ignore_columns = user_property_columns + [Card.version_column] + Card.trace_columns
    latest_versions_sql(all_columns_except(*ignore_columns) + ['1 as version'])
  end

  def self.latest_versions_sql(*select_columns)
    %{
      SELECT #{select_columns.join(',')}
      FROM #{Card::Version.quoted_table_name}
      JOIN (
        SELECT card_id, max(version) AS version
        FROM #{Card::Version.quoted_table_name}
        GROUP BY card_id) latest_versions ON (#{Card::Version.quoted_table_name}.card_id = latest_versions.card_id AND #{Card::Version.quoted_table_name}.version = latest_versions.version)
      }
  end

  def self.sequence_name_for_project_import
    "card_version_id_sequence"
  end
end


CorrectionChange
class CorrectionChange
  def self.select_by_project_sql
    %{
      SELECT #{quoted_table_name}.*
      FROM #{quoted_table_name}
      JOIN #{Event.quoted_table_name} ON (#{Event.quoted_table_name}.id = #{quoted_table_name}.event_id)
      WHERE #{Event.quoted_table_name}.deliverable_id = ?
    }
  end

  def self.select_for_template_sql
    self.select_by_project_sql
  end
end


Project # force loading the class from the normal "models" directory
class Project < Deliverable

  def self.select_by_project_sql
    "SELECT * FROM #{quoted_table_name} WHERE id = ?"
  end

  def self.select_for_template_sql
    "SELECT #{self.all_columns_except(:template, *(self.unexported_columns_for_template + trace_columns)).join(',')}, CAST(#{connection.quote(true)} AS CHAR(1)) AS template FROM #{self.quoted_table_name} WHERE id = ?"
  end

  private

  def self.unexported_columns_for_template
    [:secret_key, :membership_requestable]
  end

end

PropertyTypeMapping
class PropertyTypeMapping < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{self.quoted_table_name}
      JOIN #{CardType.quoted_table_name} ON (#{CardType.quoted_table_name}.id = #{self.quoted_table_name}.card_type_id)
      WHERE #{CardType.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    select_by_project_sql
  end
end

ProjectVariable
class ProjectVariable < ActiveRecord::Base

  def self.order_by_id_sql
    "id"
  end

  def self.select_for_template_sql
    %{
      SELECT #{self.quoted_table_name}.id as id, #{self.all_columns_except('value', 'id').join(',')}, NULL AS value
      FROM #{self.quoted_table_name}
      WHERE #{self.quoted_table_name}.data_type = 'UserType' AND #{self.quoted_table_name}.project_id = ?
      UNION
      SELECT #{self.quoted_table_name}.id as id, #{self.all_columns_except('value', 'id').join(',')}, #{ProjectVariable.quoted_table_name}.value
      FROM #{self.quoted_table_name}
      WHERE #{self.quoted_table_name}.data_type != 'UserType' AND #{self.quoted_table_name}.project_id = ?
    }
  end
end

class ProjectVariablesPropertyDefinition < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{self.all_columns_except().join(',')}, NULL as id
      FROM #{self.quoted_table_name}
      JOIN #{ProjectVariable.quoted_table_name} ON (#{ProjectVariable.quoted_table_name}.id = #{self.quoted_table_name}.project_variable_id)
      WHERE #{ProjectVariable.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    %{
      SELECT #{self.all_columns_except().join(',')}, NULL as id
      FROM #{self.quoted_table_name}
      JOIN #{ProjectVariable.quoted_table_name} ON (#{ProjectVariable.quoted_table_name}.id = #{self.quoted_table_name}.project_variable_id)
      WHERE #{ProjectVariable.quoted_table_name}.project_id = ?
    }
  end
end

VariableBinding
class VariableBinding < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{self.quoted_table_name}
      JOIN #{ProjectVariable.quoted_table_name} ON (#{ProjectVariable.quoted_table_name}.id = #{self.quoted_table_name}.project_variable_id)
      WHERE #{ProjectVariable.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{self.quoted_table_name}
      JOIN #{ProjectVariable.quoted_table_name} ON (#{ProjectVariable.quoted_table_name}.id = #{self.quoted_table_name}.project_variable_id)
      WHERE #{ProjectVariable.quoted_table_name}.project_id = ?
    }
  end
end

TreeBelonging
class TreeBelonging < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{self.all_columns_except().join(',')}
      FROM #{self.quoted_table_name}
      JOIN #{TreeConfiguration.quoted_table_name} ON (#{TreeConfiguration.quoted_table_name}.id = #{self.quoted_table_name}.tree_configuration_id)
      WHERE #{TreeConfiguration.quoted_table_name}.project_id = ?
    }
  end

  def self.select_for_template_sql
    select_by_project_sql
  end
end

CardListView
class CardListView < ActiveRecord::Base
  def self.select_for_template_sql
    fav = Favorite.quoted_table_name
    view = self.quoted_table_name
    %{
      SELECT #{view}.*
        FROM #{view}
        JOIN #{fav} ON #{fav}.favorited_id = #{view}.id
             AND #{fav}.favorited_type = 'CardListView'
       WHERE #{fav}.user_id IS NULL
             AND #{view}.project_id = ?
    }
  end
end

Favorite
class Favorite < ActiveRecord::Base
  def self.select_for_template_sql
    fav = self.quoted_table_name
    %{
      SELECT *
        FROM #{fav}
       WHERE user_id IS NULL
         AND project_id = ?
    }
  end
end

Group
class Group < ActiveRecord::Base
  class << self
    def select_by_project_sql
      %{
        SELECT *
          FROM #{self.quoted_table_name}
         WHERE deliverable_id = ?
      }
    end

    alias :select_for_template_sql :select_by_project_sql
  end
end

UserMembership
class UserMembership < ActiveRecord::Base
  class << self
    def select_by_project_sql
      user_membership = self.quoted_table_name
      users = User.quoted_table_name
      %{
        SELECT #{user_membership}.*
          FROM #{user_membership}
          JOIN #{users} ON (#{users}.id = #{user_membership}.user_id)
          JOIN #{Group.quoted_table_name} g ON g.id = #{user_membership}.group_id
          WHERE g.deliverable_id = ?
      }
    end

    alias :select_for_template_sql :select_by_project_sql
  end
end

MemberRole
class MemberRole < ActiveRecord::Base
  class << self
    def select_by_project_sql
      <<-SQL
        SELECT #{self.all_columns_except.join(',')}
        FROM #{self.quoted_table_name}
        WHERE (deliverable_id = ?)
      SQL
    end

    alias :select_for_template_sql :select_by_project_sql
  end
end

Event
class Event < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{export_columns.join(',')}
      FROM #{self.quoted_table_name}
      WHERE #{export_general_conditions}
    }
  end

  def self.select_for_template_sql
    new_select_for_template_sql
  end

  def self.new_select_for_template_sql
    id = Project.current.overview_page ? Project.current.overview_page.latest_version.id : -1
    %{
       SELECT #{export_columns.join(',')}
       FROM #{self.quoted_table_name}
       WHERE
        deliverable_id = ? AND
        origin_type = 'Page::Version' AND
        origin_id = #{id}
    }
  end

  def self.columns_hash_to_import
    @columns_hash_to_import ||= columns_hash.merge({'mingle_timestamp' => mingle_timestamp_column })
  end

  private

  def self.mingle_timestamp_column
    connection.columns(table_name, "#{name} Columns").detect {|c| c.name == 'mingle_timestamp' }
  end

  def self.export_columns
    all_columns_except('history_generated') + [ "#{connection.quote(false)} as history_generated", 'mingle_timestamp']
  end

  def self.export_general_conditions
    "origin_type != 'Revision' AND origin_type != 'Dependency::Version' AND deliverable_id = ?"
  end
end

DependencyView
class DependencyView < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT #{DependencyView.quoted_table_name}.*
        FROM #{DependencyView.quoted_table_name}
  INNER JOIN #{Group.quoted_table_name} gr
          ON gr.deliverable_id = #{DependencyView.quoted_table_name}.project_id
  INNER JOIN #{UserMembership.quoted_table_name} um
          ON #{DependencyView.quoted_table_name}.user_id = um.user_id
       WHERE #{DependencyView.quoted_table_name}.project_id = ?
         AND um.group_id = gr.id
         AND gr.internal = #{SqlHelper.sanitize_sql("?", true)}
         AND lower(gr.name) = 'team'
    }
  end
end

ChecklistItem
class ChecklistItem < ActiveRecord::Base
  def self.select_by_project_sql
    %{
      SELECT *
        FROM #{ChecklistItem.quoted_table_name}
       WHERE #{ChecklistItem.quoted_table_name}.project_id = ?
    }
  end
end
