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

class HistoryFilters
  include SqlHelper

  attr_accessor :project, :filters, :period, :filter_types

  class InvalidError < StandardError; end

  def initialize(project, filters={})
    self.project = project
    filter_period = filters.delete(:period)
    self.period = if filter_period.nil?
      History::NAMED_PERIODS[:all_history]
    elsif filter_period.respond_to?(:boundaries)
      filter_period
    else
      History::NAMED_PERIODS[filter_period.to_sym]
    end
    self.filter_types = filters.delete(:filter_types)
    self.filters = filters
  end

  def valid?
    valid_tag_critetria?(filters[:involved_filter_tags]) and valid_tag_critetria?(filters[:acquired_filter_tags])
  end

  def to_params
    filters.merge(:filter_types => filter_types)
  end

  def to_sql(page_options = {})
    sql = base_sql
    sql = "SELECT * FROM (#{sql}) filtered_events WHERE 1=1"
    sql = add_filter_types_to(sql)
    sql = add_period_conditions_to(sql)
    add_limit_offset_conditions(sql, page_options)
  end

  def add_filter_types_to(sql)
    return sql if !filter_types || filter_types.empty?
    types = filter_types.values.include?("Card::Version") ? filter_types.values + ["CardCopyEvent::From", "CardCopyEvent::To"] : filter_types.values
    sql + sanitize_sql(" AND version_type IN (?)", types)
  end

  def add_period_conditions_to(sql)
    return sql unless period
    start_time, end_time = period.boundaries
    period_conditions = "".tap do |conditions|
      conditions << " AND filtered_events.updated_at >= ? " if start_time
      conditions << " AND filtered_events.updated_at <= ? " if end_time
    end
    sql + sanitize_sql(" #{period_conditions}", *period.boundaries.compact.collect(&:utc))
  end

  def add_freshness_conditions_to(sql, last_max_ids)
    conditions = []
    condition = "(filtered_events.version_id > ? AND filtered_events.version_type = ?)"
    conditions << sanitize_sql(condition, last_max_ids[:card_version] || -1, 'Card::Version')
    conditions << sanitize_sql(condition, last_max_ids[:card_version] || -1, 'CardCopyEvent::To')
    conditions << sanitize_sql(condition, last_max_ids[:card_version] || -1, 'CardCopyEvent::From')
    conditions << sanitize_sql(condition, last_max_ids[:page_version] || -1, 'Page::Version')
    conditions << sanitize_sql(condition, last_max_ids[:revision] || -1, 'Revision')
    "#{sql} AND (#{conditions.join(' OR ')})"
  end

  def add_already_generated_condition_to(sql)
    sql + sanitize_sql(" AND filtered_events.history_generated = ?", true)
  end

  def add_limit_offset_conditions(sql, page_options={})
    return sql if page_options.empty?
    ActiveRecord::Base.connection.add_limit_offset!(sql, page_options)
    sql
  end

  def events(page_options = {})
    return [] unless valid?
    load_history_events(self.to_sql(page_options))
  end

  def event_count
    return 0 unless valid?
    count_sql = base_sql
    count_sql = "SELECT * FROM (#{count_sql}) filtered_events WHERE 1=1"
    count_sql = add_filter_types_to(count_sql)
    count_sql = add_period_conditions_to(count_sql)
    ActiveRecord::Base.connection.select_value("SELECT count(*) FROM (#{count_sql}) filtered_events").to_i
  end

  def fresh_events(last_max_ids)
    sql = base_sql
    sql = "SELECT * FROM (#{sql}) filtered_events WHERE 1=1"
    sql = add_filter_types_to(sql)
    sql = add_freshness_conditions_to(sql, last_max_ids)
    sql = add_already_generated_condition_to(sql)
    load_history_events(sql).reverse
  end

  def load_history_events(sql)
    rs = ActiveRecord::Base.connection.select_all(sql)
    events = rs.collect{|r|r['version_type']}.uniq.collect do |version_type|
      ids = rs.select{|r| r['version_type'] == version_type }.collect{|r| r['version_id']}
      version_type.strip.constantize.load_history_event(project, ids)
    end
    events.flatten.sort{|event1, event2| event2.updated_at <=> event1.updated_at}
  end

  def base_sql
    if filters.empty? || filters.values.all?(&:nil?)
      events_by_user_sql
    else
      result_sql = events_by_user_sql do
        any_change_parameters, acquired_parameters = acquired_values.partition { |property_value| property_value.db_identifier == '(any change)' }
        filters = [InvolvedPropertiesFilter.new(self.project, acquired_values, current_values),
        AcquiredPropertiesFilter.new(self.project, acquired_parameters, current_values),
        InvolvedTagsFilter.new(self.project, current_tags.compact),
        AcquiredTagsFilter.new(self.project, acquired_tags.compact)]
        filters + any_change_parameters.collect{ |property_value| AnyChangePropertyFilter.new(self.project, property_value, current_values) }
      end
      result_sql
    end
  end

  def join(subqueries)
    join_clauses = []
    subqueries.collect(&:to_sql).compact.each_with_index do |join, index|
      join_clauses << %{
        JOIN (#{join}) join_#{index} ON (events.origin_type = join_#{index}.version_type AND events.origin_id = join_#{index}.version_id)
      }
    end
    join_clauses.join
  end

  private

  #todo remove the not_deleted join when we play story that show history for deleted cards
  def events_by_user_sql(&filter_block)
    filter_user = user_id.kind_of?(User) ? user_id.id : user_id
    user_condition = filter_user ? "AND created_by_user_id = #{filter_user}" : ""
    %{
        SELECT origin_type AS version_type, origin_id AS version_id, created_at AS updated_at, history_generated
        FROM events

        JOIN (
          SELECT #{as_char(connection.quote('Card::Version'))} AS version_type, #{Card::Version.quoted_table_name}.id AS version_id, #{Card::Version.quoted_table_name}.updated_at AS updated_at
          FROM #{Card::Version.quoted_table_name}, #{Card.quoted_table_name}
          WHERE #{Card::Version.quoted_table_name}.card_id = #{Card.quoted_table_name}.id
            AND #{Card::Version.quoted_table_name}.project_id = #{@project.id}
            AND #{Card.quoted_table_name}.project_id = #{@project.id}

          UNION ALL

          SELECT #{as_char(connection.quote('Page::Version'))} AS version_type, #{Page::Version.quoted_table_name}.id AS version_id, #{Page::Version.quoted_table_name}.updated_at AS updated_at
          FROM #{Page::Version.quoted_table_name}, #{Page.quoted_table_name}
          WHERE #{Page::Version.quoted_table_name}.project_id = #{@project.id}
            AND #{Page::Version.quoted_table_name}.page_id = #{Page.quoted_table_name}.id
            AND #{Page.quoted_table_name}.project_id = #{@project.id}

          UNION ALL

          SELECT #{as_char(connection.quote('Revision'))} AS version_type, #{Revision.quoted_table_name}.id AS version_id, #{Revision.quoted_table_name}.commit_time AS updated_at
          FROM #{Revision.quoted_table_name}
          WHERE #{Revision.quoted_table_name}.project_id = #{@project.id}

          UNION ALL

          SELECT #{as_char(connection.quote('Dependency::Version'))} AS version_type, #{Dependency::Version.quoted_table_name}.id AS version_id, #{Dependency::Version.quoted_table_name}.updated_at AS updated_at
          FROM #{Dependency::Version.quoted_table_name}, #{Dependency.quoted_table_name}
          WHERE (#{Dependency::Version.quoted_table_name}.raising_project_id = #{@project.id} or #{Dependency::Version.quoted_table_name}.resolving_project_id = #{@project.id})
            AND #{Dependency::Version.quoted_table_name}.dependency_id = #{Dependency.quoted_table_name}.id
            AND (#{Dependency.quoted_table_name}.raising_project_id = #{@project.id} or #{Dependency.quoted_table_name}.resolving_project_id = #{@project.id})
        ) not_deleted ON (events.origin_type = not_deleted.version_type AND events.origin_id = not_deleted.version_id)

        #{join(yield) if block_given?}
        WHERE deliverable_id = #{@project.id}
          #{user_condition}

        UNION ALL

        SELECT type AS version_type, id AS version_id, created_at AS updated_at, history_generated
        FROM events
        WHERE deliverable_id = 6
          AND type in ('CardCopyEvent::From', 'CardCopyEvent::To')
          #{user_condition}

        ORDER BY updated_at DESC
      }
  end

  def empty?
    filters.empty?
  end

  def user_id
    filters[:filter_user]
  end

  def current_tags
    to_tags(filters[:involved_filter_tags] || [])
  end

  def current_values
    to_not_nil_properties(filters[:involved_filter_properties] || {})
  end

  def acquired_tags
    to_tags(filters[:acquired_filter_tags] || [])
  end

  def acquired_values
    to_not_nil_properties(filters[:acquired_filter_properties] || {})
  end

  def to_tags(tag_names)
    tag_names.collect{|tag_name| project.tag_named(tag_name) }
  end

  def to_not_nil_properties(values)
    values.inject([]) do |result, pair|
      prop_def = project.find_property_definition_including_card_type_def(pair.first, :with_hidden => true)
      raise InvalidError, "Property #{pair.first.bold} does not exist." unless prop_def
      property_value = prop_def.property_value_from_db(pair.last)
      result << property_value unless property_value.ignored?
      result
    end
  end

  def valid_tag_critetria?(tags)
    Tag.parse(tags).all? { |tag| project.valid_tag?(tag) }
  end
end

class InvolvedPropertiesFilter
  include SqlHelper

  def initialize(project, acquired_parameters, involved_parameters)
    @project = project

    @involved_parameters = involved_parameters.reject do |to_be_handled_by_acquired_filter|
      acquired_parameters.any?{|acquired| acquired.property_definition == to_be_handled_by_acquired_filter.property_definition}
    end + acquired_parameters.reject { |property_value| property_value.db_identifier == '(any change)'}
  end

  def to_sql
    return nil if @involved_parameters.empty?
    %{
      SELECT #{as_char(connection.quote('Card::Version'))} AS version_type, #{Card::Version.quoted_table_name}.id AS version_id, #{Card::Version.quoted_table_name}.updated_at AS updated_at
      FROM #{Card::Version.quoted_table_name}
      WHERE #{where_clause}
      AND #{Card::Version.quoted_table_name}.project_id = #{@project.id}
    }
  end

  def where_clause
    conditions = []
    @involved_parameters.collect do |involved|
      column = Card::Version.columns_hash[involved.property_definition.column_name]
      if involved.not_set?
        conditions << "#{Card::Version.quoted_table_name}.#{involved.property_definition.column_name} IS NULL"
      else
        conditions << "#{Card::Version.quoted_table_name}.#{involved.property_definition.column_name} = #{@project.connection.quote(involved.db_identifier, column)}"
      end
    end
    conditions.join(' AND ')
  end
end

class AcquiredPropertiesFilter
  include SqlHelper

  def initialize(project, acquired_parameters, involved_parameters)
    @project = project
    @acquired_parameters = acquired_parameters
    @involved_parameters = involved_parameters
  end

  def to_sql
    return nil if @acquired_parameters.empty?
    where_condition_clause = self.where_clause
    return nil if where_condition_clause.blank?
    %{
      SELECT version_type, version_id, updated_at
      FROM
      (SELECT events.origin_type AS version_type, events.origin_id AS version_id, events.created_at AS updated_at
      FROM events
      JOIN changes ON (events.id = changes.event\_id)
      WHERE #{where_condition_clause}
      AND events.deliverable_id = #{@project.id}
      AND events.origin_type = 'Card::Version') acquisitions
    }
  end

  def where_clause
    conditions = []
    field_col = Change.columns_hash["field"]
    new_col = Change.columns_hash["new_value"]
    old_col = Change.columns_hash["old_value"]
    @acquired_parameters.each do |acquired|
      lost = @involved_parameters.detect{|involved| involved.property_definition == acquired.property_definition}
      # ignore condition that field is type and old value equals new value.
      # see bug 8354 for reason
      if lost && acquired.property_definition.name.downcase == 'type' && acquired.db_identifier == lost.db_identifier
        next
      end
      result = "changes.field = #{@project.connection.quote(acquired.property_definition.name, field_col)}"
      unless acquired.db_identifier == '(any change)'
        if acquired.not_set?
          result << " AND changes.new_value IS NULL"
        else
          result << " AND changes.new_value = #{@project.connection.quote(acquired.db_identifier, new_col)}"
        end
      end
      if lost
        if lost.not_set?
          result << " AND changes.old_value IS NULL"
        else
          result << " AND changes.old_value = #{@project.connection.quote(lost.db_identifier, old_col)}"
        end
      end
      conditions << result
    end
    conditions.join(' OR ')
  end
end

class AnyChangePropertyFilter
  include SqlHelper

  def initialize(project, any_change_property, involved_parameters)
    @project = project
    @any_change_property = any_change_property
    @old_property = involved_parameters.select{ |property_value| property_value.property_definition == @any_change_property.property_definition }.first
  end

  def to_sql
    return nil unless @any_change_property
    field_col = Change.columns_hash["field"]
    new_col = Change.columns_hash["new_value"]

    %{
      SELECT version_type, version_id, updated_at
      FROM
      (SELECT events.origin_type AS version_type, events.origin_id AS version_id, events.created_at AS updated_at
      FROM events
      JOIN changes ON (events.id = changes.event\_id)
      WHERE changes.field = #{@project.connection.quote(@any_change_property.property_definition.name, field_col)}
      #{lost_value_clause}
      AND events.deliverable_id = #{@project.id}
      And events.origin_type = 'Card::Version') acquisitions
    }
  end

  def lost_value_clause
    return unless @old_property
    if @old_property.not_set?
      "AND changes.old_value IS NULL"
    else
      old_col = Change.columns_hash["old_value"]
      "AND changes.old_value = #{@project.connection.quote(@old_property.db_identifier, old_col)}"
    end
  end
end

class InvolvedTagsFilter
  include SqlHelper

  def initialize(project, tags)
    @project = project
    @tags = tags
  end

  def to_sql
    return nil if @tags.empty?
    sanitize_sql %{
      SELECT DISTINCT #{Tagging.table_name}.taggable_type AS version_type, #{Tagging.table_name}.taggable_id AS version_id, #{Card::Version.quoted_table_name}.updated_at AS updated_at
      FROM #{Card::Version.quoted_table_name}
      JOIN #{Tagging.table_name} ON (#{Tagging.table_name}.taggable_id = #{Card::Version.quoted_table_name}.id AND #{Tagging.table_name}.taggable_type = '#{Card::Version.name}')
      JOIN #{Tag.table_name} ON (#{Tag.table_name}.id = #{Tagging.table_name}.tag_id)
      WHERE UPPER(#{Tag.table_name}.name) IN (?)
      AND #{Card::Version.quoted_table_name}.project_id = #{@project.id}
      UNION
      SELECT DISTINCT #{Tagging.table_name}.taggable_type AS version_type, #{Tagging.table_name}.taggable_id AS version_id, #{Page::Version.table_name}.updated_at AS updated_at
      FROM #{Page::Version.table_name}
      JOIN #{Tagging.table_name} ON (#{Tagging.table_name}.taggable_id = #{Page::Version.table_name}.id AND #{Tagging.table_name}.taggable_type = '#{Page::Version.name}')
      JOIN #{Tag.table_name} ON (#{Tag.table_name}.id = #{Tagging.table_name}.tag_id)
      WHERE UPPER(#{Tag.table_name}.name) IN (?)
      AND #{Page::Version.table_name}.project_id = #{@project.id}
    }, *[@tags.collect(&:name).collect(&:upcase), @tags.collect(&:name).collect(&:upcase)]
  end
end

class AcquiredTagsFilter
  include SqlHelper

  def initialize(project, tags)
    @project = project
    @tags = tags
  end

  def to_sql
    return nil if @tags.empty?
    sql = %{
      SELECT version_type, version_id, updated_at
      FROM
      (SELECT events.origin_type AS version_type, events.origin_id AS version_id, events.created_at AS updated_at, count(*) AS number_of_acquired_tags
      FROM events
      JOIN changes ON (events.id = changes.event_id)
      WHERE UPPER(field) IN ('TAGS') AND UPPER(new_value) IN (?)
      AND deliverable_id = #{@project.id}
      GROUP BY events.origin_type, events.origin_id, events.created_at) acquisitions
      WHERE number_of_acquired_tags = ?
    }
    sanitize_sql sql, *[@tags.collect(&:name).collect(&:upcase), @tags.size]
  end
end
