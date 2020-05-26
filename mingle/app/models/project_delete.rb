#encoding: UTF-8

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


class ProjectDelete

  attr_accessor :project

  def initialize(project)
    self.project = project
  end

  def execute
    return if project.id.blank?
    #do this twice? - trying to acquire an exclusive lock and delete a second time
    #so that any background processing threads can finish their work and we can cleanup anything they do too.?
    project.lock!

    dependencies_murmur_resolving_projects()
    delete_all(dependency_views)
    delete_all(raised_dependencies)
    delete_all(resolving_dependencies)
    delete_all(async_requests)
    delete_all(attachments)
    delete_all(tags)
    delete_all(revisions)
    delete_all(events)
    project.delete_search_index
    # delete_all(cards) # let drop_card_schema do it
    project.send(:delete_card_number_sequence)
    delete_all(pages)
    delete_all(user_filter_usages)
    delete_all(saved_views)
    delete_all(favorites)
    delete_all(history_subscriptions)
    delete_all(transitions)
    delete_all(properties)
    delete_all(card_defaults)
    delete_all(card_types)
    delete_all(tree_configurations)
    delete_all(stale_property_definitions)
    delete_all(project_variables_and_their_associations)
    MinglePlugins::Source.delete_all_for(project)
    Project.invalidate_renderable_content_cache('project delete')
    project.clean_memberships
    delete_all(murmurs)
    delete_all(conversations)
    delete_all(cache_keys)
    delete_project_and_icon
    project.drop_card_schema
  end

  private
  def delete_all(sqls)
    return unless sqls
    sqls.each { |sql| exec(sql) }
  end

  def async_requests
    #we should not clear project import table,
    #because when importing project, we need importing progress message even project imported failed
    [["DELETE FROM #{AsynchRequest.table_name} where deliverable_identifier = ? and type != 'ProjectImportAsynchRequest'", project.identifier]]
  end

  def attachments
    attachment_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT attachments.id
      FROM attachments
      WHERE project_id = ?
    SQL

    attachings = [<<-SQL]
      DELETE FROM attachings
      WHERE attachment_id IN (#{attachment_scope_sql})
    SQL
    attachments = [<<-SQL, project.id]
      DELETE FROM attachments
      WHERE attachments.project_id = ?
    SQL
    attachments_dirs = project.attachments.collect(&:full_directory_path).uniq
    begin
      FileUtils.rm_rf(attachments_dirs)
    rescue ::Exception
      #ignore if the files cannot be deleted
    end
    return attachings, attachments
  end

  def tags
    tag_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT tags.id
      FROM tags
      WHERE project_id = ?
    SQL

    taggings = [<<-SQL]
      DELETE FROM taggings
      WHERE tag_id IN (#{tag_scope_sql})
    SQL
    tags = [<<-SQL, project.id]
      DELETE FROM tags
      WHERE tags.project_id = ?
    SQL
    return taggings, tags
  end

  def revisions
    card_links = [<<-SQL, project.id]
      DELETE FROM card_revision_links
      WHERE project_id = ?
    SQL
    revisions = [<<-SQL, project.id]
      DELETE FROM revisions
      WHERE project_id = ?
    SQL
    return card_links, revisions
  end

  def events
    events = [<<-SQL, project.id]
      DELETE FROM events
      WHERE deliverable_id = ?
    SQL

    changes = [<<-SQL, project.id]
      delete from changes where exists (select 1 from events where changes.event_id = events.id and events.deliverable_id = ?)
    SQL

    return changes, events
  end

  def cards
    card_versions = [<<-SQL, project.id]
      DELETE FROM #{Card::Version.quoted_table_name}
      WHERE project_id = ?
    SQL
    cards = [<<-SQL, project.id]
      DELETE FROM #{Card.quoted_table_name}
      WHERE project_id = ?
    SQL
    return card_versions, cards
  end

  def pages
    page_versions = [<<-SQL, project.id]
      DELETE FROM #{Page::Version.table_name}
      WHERE project_id = ?
    SQL
    pages = [<<-SQL, project.id]
      DELETE FROM #{Page.table_name}
      WHERE project_id = ?
    SQL
    return page_versions, pages
  end

  def user_filter_usages
    card_list_view_usages = [<<-SQL, project.id]
    DELETE FROM user_filter_usages ufu
    WHERE ufu.filterable_type = 'CardListView'
    AND ufu.filterable_id IN
      (
        SELECT id FROM card_list_views clv
        WHERE clv.project_id = ?
      )
    SQL
    history_subscription_usages = [<<-SQL, project.id]
    DELETE FROM user_filter_usages ufu
    WHERE ufu.filterable_type = 'HistorySubscription'
    AND ufu.filterable_id IN
      (
        SELECT id FROM #{HistorySubscription.table_name} hs
        WHERE hs.project_id = ?
      )
    SQL
    return card_list_view_usages, history_subscription_usages
  end

  def saved_views
    return [[<<-SQL, project.id]]
      DELETE FROM card_list_views
      WHERE project_id = ?
    SQL
  end

  def favorites
    return [[<<-SQL, project.id]]
      DELETE FROM favorites
      WHERE project_id = ?
    SQL

  end

  def history_subscriptions
    return [[<<-SQL, project.id]]
      DELETE FROM history_subscriptions
      WHERE project_id = ?
    SQL
  end

  def transitions
    transition_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT transitions.id
      FROM
      transitions
      WHERE project_id = ?
    SQL

    prerequisites = [<<-SQL]
      DELETE FROM transition_prerequisites
      WHERE transition_id IN (#{transition_scope_sql})
    SQL
    actions = [<<-SQL]
      DELETE FROM transition_actions
      WHERE executor_id IN (#{transition_scope_sql})
      AND executor_type = 'Transition'
    SQL
    transitions = [<<-SQL, project.id]
      DELETE FROM transitions
      WHERE project_id = ?
    SQL

    return prerequisites, actions, transitions
  end

  def properties
    property_definition_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT id
      FROM property_definitions
      WHERE project_id = ?
    SQL

    enum_values = [<<-SQL]
      DELETE FROM enumeration_values
      WHERE property_definition_id IN (#{property_definition_scope_sql})
    SQL

    property_definitions = [<<-SQL, project.id]
      DELETE FROM property_definitions
      WHERE project_id = ?
    SQL

    return enum_values, property_definitions
  end

  def card_types
    card_type_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT id
      FROM card_types
      WHERE project_id = ?
    SQL


    card_types_table = [<<-SQL, project.id]
      DELETE FROM card_types
      WHERE project_id = ?
    SQL

    property_type_mappings_table = [<<-SQL]
      DELETE FROM property_type_mappings
      WHERE card_type_id IN (#{card_type_scope_sql})
    SQL

    return property_type_mappings_table, card_types_table
  end

  def card_defaults
    card_defaults_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT card_defaults.id
      FROM
      card_defaults
      WHERE project_id = ?
    SQL

    actions = [<<-SQL]
      DELETE FROM transition_actions
      WHERE executor_id IN (#{card_defaults_scope_sql})
      AND executor_type = 'CardDefaults'
    SQL

    defaults = [<<-SQL, project.id]
      DELETE FROM card_defaults
      WHERE project_id = ?
    SQL

    return actions, defaults
  end

  def tree_configurations
    tree_configuration_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT id
      FROM tree_configurations
      WHERE project_id = ?
    SQL

    tree_configurations_table = [<<-SQL, project.id]
      DELETE FROM tree_configurations
      WHERE project_id = ?
    SQL

    tree_belongings_table = [<<-SQL]
      DELETE FROM tree_belongings
      WHERE tree_configuration_id IN (#{tree_configuration_scope_sql})
    SQL
    return tree_belongings_table, tree_configurations_table
  end

  def project_variables_and_their_associations
    project_variable_scope_sql = sanitize_sql([<<-SQL, project.id])
      SELECT id
      FROM project_variables
      WHERE project_id = ?
    SQL

    project_variables_table = [<<-SQL, project.id]
      DELETE FROM project_variables
      WHERE project_id = ?
    SQL

    variable_bindings_table = [<<-SQL]
      DELETE FROM variable_bindings
      WHERE project_variable_id IN (#{project_variable_scope_sql})
    SQL

    return variable_bindings_table, project_variables_table
  end

  def raised_dependencies
    raised_dependencies_select_sql = sanitize_sql([<<-SQL, project.id])
      SELECT id
        FROM dependencies
       WHERE raising_project_id = ?
    SQL

    raised_dependency_versions_select_sql = sanitize_sql([<<-SQL, project.id])
      SELECT id
        FROM dependency_versions
       WHERE raising_project_id = ?
    SQL

    resolving_cards_delete_sql = [<<-SQL, project.id]
      DELETE FROM dependency_resolving_cards
       WHERE project_id = ?
    SQL

    version_resolving_cards_delete_sql = [<<-SQL, project.id]
      DELETE FROM dependency_resolving_cards
       WHERE project_id = ?
    SQL

    raised_dependencies_delete_sql = [<<-SQL, project.id]
      DELETE FROM dependencies
      WHERE raising_project_id = ?
    SQL

    raised_dependency_versions_delete_sql = [<<-SQL, project.id]
      DELETE FROM dependency_versions
      WHERE raising_project_id = ?
    SQL

    raised_dependency_events_delete_sql = [<<-SQL]
      DELETE FROM events
       WHERE origin_type = 'Dependency::Version'
         AND origin_id IN (#{raised_dependency_versions_select_sql})
    SQL

    return resolving_cards_delete_sql, version_resolving_cards_delete_sql, raised_dependency_events_delete_sql, raised_dependency_versions_delete_sql, raised_dependencies_delete_sql
  end

  def resolving_dependencies
    resolving_cards_delete_sql = [<<-SQL, project.id]
      DELETE FROM dependency_resolving_cards
      WHERE project_id = ?
    SQL

    update_dependency_status_sql = [<<-SQL, project.id]
      UPDATE dependencies
      SET status = '#{Dependency::NEW}'
      WHERE resolving_project_id = ? AND status = '#{Dependency::ACCEPTED}'
    SQL

    resolving_dependencies_unlink_sql = [<<-SQL, project.id]
      UPDATE dependencies
      SET resolving_project_id = NULL
      WHERE resolving_project_id = ?
    SQL

    resolving_dependencies_versions_unlink_sql = [<<-SQL, project.id]
      UPDATE dependency_versions
      SET resolving_project_id = NULL
      WHERE resolving_project_id = ?
    SQL

    return resolving_cards_delete_sql, update_dependency_status_sql, resolving_dependencies_unlink_sql, resolving_dependencies_versions_unlink_sql
  end

  def dependencies_murmur_resolving_projects
    resolving_projects_and_cards = resolving_project_ids_and_card_numbers

    resolving_projects_and_cards.each do |project_id, card_numbers|
      user = User.create_or_update_system_user(dependencies_system_user)
      Project.find(project_id).with_active_project do |proj|
        proj.murmurs.create!(:body => resolving_project_murmur_message(card_numbers),
                             :author => user)
      end
    end
  end

  def resolving_project_murmur_message(card_numbers)
    murmur = "The project \"#{self.project.name}\" and its dependencies were deleted."
    if card_numbers.length > 2
      last_card_number = card_numbers.pop
      murmur += " The resolving cards — #{card_numbers.join(', ')}, and #{last_card_number} — have been unlinked."
    elsif card_numbers.length == 2
      murmur += " The resolving cards, #{card_numbers.join(' and ')}, have been unlinked."
    elsif card_numbers.length == 1
      murmur += " The resolving card, #{card_numbers[0]}, has been unlinked."
    end
    murmur
  end

  # Output looks like:
  # {
  #   :project_id => [ card_number, card_number ],
  #   ...
  # }
  #
  # Example:
  # {
  #   :7 => [ '#1', '#22', '#666' ],
  #   :13 => [ '#6', '#66' ]
  # }
  def resolving_project_ids_and_card_numbers
    self.project.raised_dependencies.inject({}) do |results, dep|
      resolving_project_id = dep.resolving_project_id
      return results if resolving_project_id.nil? || resolving_project_id == self.project.id

      results[resolving_project_id] ||= []
      results[resolving_project_id].concat(dep.resolving_card_numbers).uniq!
      results
    end
  end

  def dependencies_system_user
    {
      :login => "dependencies_#{self.project.identifier}",
      :name => self.project.name,
      :email => "mingle.saas+dependencies+#{self.project.identifier}@thoughtworks.com",
      :admin => true,
      :activated => true
    }
  end

  def stale_property_definitions
    [[<<-SQL, project.id]]
      DELETE FROM #{StalePropertyDefinition.table_name}
      WHERE project_id = ?
    SQL
  end

  def murmurs
    [[<<-SQL, project.id]]
      DELETE FROM murmurs
      WHERE project_id = ?
    SQL
  end

  def conversations
    [[<<-SQL, project.id]]
      DELETE FROM conversations
      WHERE project_id = ?
    SQL
  end

  def cache_keys
    [[<<-SQL, project.id]]
      DELETE FROM cache_keys
      WHERE deliverable_id = ?
    SQL
  end

  def dependency_views
    [[<<-SQL, project.id]]
      DELETE FROM dependency_views
      WHERE project_id = ?
    SQL
  end

  def delete_project_and_icon
    begin
      File.delete(project.icon) unless project.icon.blank?
    rescue Exception
      #ignore if you can't delete the icon
    end
    exec(["DELETE FROM #{Project.table_name} WHERE id = ?", project.id])
    project.freeze
  end

  def select_values(sql_and_parameters)
    project.connection.select_values(sanitize_sql(sql_and_parameters))
  end

  def sanitize_sql(sql_and_parameters)
    SqlHelper.sanitize_sql(*sql_and_parameters)
  end

  def exec(sql_and_parameters)
    project.connection.execute(sanitize_sql(sql_and_parameters))
  end

end
