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

class CardActivity
  
  class ActivityDetail < Struct.new(:number, :name, :matching_state, :last_met_time, :last_out_of_met_time)
  end
  
  include PaginationSupport, SqlHelper
  PAGE_SIZE_LIMIT = 1000
  
  attr_reader :grouping_mql
  
  def initialize(project, original_card_numbers, options={})
    @project = project
    @grouping_mql = options[:grouping_conditions]
    @per_page = options[:page_size].blank? ? PAGINATION_PER_PAGE_SIZE : options[:page_size].to_i
    @page = options[:page]    
    @original_card_numbers = original_card_numbers
  end
  
  def validation_errors
    errors = []
    begin
      grouping_card_query.to_card_version_sql
    rescue CardQuery::NonConditionalPartsExists => e
      return errors << "Invalid grouping condition: use of #{e.none_conditional_parts.map(&:bold).to_sentence(:last_word_connector => ' and ')} #{"is".plural(e.none_conditional_parts.size)} invalid. Enter MQL conditions only."
    rescue StandardError => e
      return errors << "Invalid grouping condition: #{e.message}"
    end

    errors << "Invalid page size" if @per_page <= 0
    errors << "Page size cannot exceed #{PAGE_SIZE_LIMIT}" if @per_page > PAGE_SIZE_LIMIT
    errors
  end
  
  def paginator
    Paginator.create_with_current_page(card_numbers_grouping.size, :items_per_page => @per_page, :page => @page)
  end
  
  def empty?
    card_numbers_grouping.empty?
  end
  
  def details
    in_numbers = current_page_card_numbers
    rows = select_all_rows(sanitize_sql(%{
      SELECT #{quote_column_name('number')}, #{quote_column_name('name')}, MAX(matched.updated_at) AS last_met_time, MAX(out_of_matched.updated_at) AS last_out_of_met_time
      FROM #{Card.quoted_table_name} cards
      LEFT OUTER JOIN ( 
        #{entering_grouping_condition_matching_state_versions_sql(in_numbers)}
      ) matched ON cards.id = matched.card_id
      
      LEFT OUTER JOIN ( 
        #{leaving_grouping_condtion_matching_state_versions_sql(in_numbers)}
      ) out_of_matched ON cards.id = out_of_matched.card_id
      
      WHERE #{quote_column_name('number')} in (?)
      GROUP BY #{quote_column_name('number')}, #{quote_column_name('name')}
    }, in_numbers))
    
    details = rows.collect do |r|
      number = r['number'].to_i
      name = r['name']
      matching_state = card_numbers_grouping.matching_state_of(number)
      
      if has_grouping?
        match_time = cast_time(r['last_met_time'])
        out_of_match_time = cast_time(r['last_out_of_met_time']) if matching_state == :was_matched
      end
      ActivityDetail.new(number, name, matching_state, match_time, out_of_match_time) 
    end
    card_numbers_grouping.sort_activity_details(details)
  end

  def to_params
    {:grouping_conditions => @grouping_mql, :page_size => @per_page, :card_numbers => card_numbers_grouping.join(",")}
  end
  
  def has_grouping?
    !@grouping_mql.blank?
  end
  
  def this_card_condition_availability
    ThisCardConditionAvailability::Never.new(self)
  end
  
  def this_card_condition_error_message(usage)
    "use of #{usage.bold} is not supported."
  end
  
  def project_id
    @project.id
  end
  
  private
  
  def card_numbers_grouping
    @__card_numbers_grouping ||= CardNumbersGrouping.new(@original_card_numbers, grouping_card_query)
  end
  
  def grouping_card_query
    @__grouping_card_query ||= CardQuery.parse_as_condition_query(@grouping_mql, :content_provider => self)
  end
  
  def cast_time(str)
    Card.columns_hash['updated_at'].type_cast(str)
  end
  
  def entering_grouping_condition_matching_state_versions_sql(in_numbers)
    current_version_matching_query = grouping_card_query.restrict_with(CardQuery::SqlCondition.new("#{CardQuery.card_version_table_alias}.id = cv.id"))
    previous_version_matching_query = grouping_card_query.restrict_with(CardQuery::SqlCondition.new("#{CardQuery.card_version_table_alias}.id = pv.id"))
    
    sanitize_sql(%{
      SELECT cv.card_id, cv.updated_at
      FROM #{Card::Version.quoted_table_name} cv
      LEFT OUTER JOIN #{Card::Version.quoted_table_name} pv
      ON cv.card_id = pv.card_id AND cv.version = pv.version + 1
      WHERE
       cv.#{quote_column_name('number')} IN (?)
       AND EXISTS ( #{ current_version_matching_query.to_card_version_sql } )
       AND (pv.id IS NULL OR NOT EXISTS ( #{ previous_version_matching_query.to_card_version_sql } ) )
    }, in_numbers)
  end
  
  def leaving_grouping_condtion_matching_state_versions_sql(in_numbers)
    current_version_matching_query = grouping_card_query.restrict_with(CardQuery::SqlCondition.new("#{CardQuery.card_version_table_alias}.id = cv.id"))
    previous_version_matching_query = grouping_card_query.restrict_with(CardQuery::SqlCondition.new("#{CardQuery.card_version_table_alias}.id = pv.id"))
    
    sanitize_sql(%{
      SELECT cv.card_id, cv.updated_at
      FROM #{Card::Version.quoted_table_name} cv
      LEFT OUTER JOIN #{Card::Version.quoted_table_name} pv
      ON cv.card_id = pv.card_id AND cv.version = pv.version + 1
      WHERE
       cv.#{quote_column_name('number')} IN (?)
       AND EXISTS ( #{ previous_version_matching_query.to_card_version_sql } )
       AND NOT EXISTS ( #{ current_version_matching_query.to_card_version_sql } )
    }, in_numbers)
  end
  
  def current_page_card_numbers
    limit = paginator.limit_and_offset[:limit]
    offset = paginator.limit_and_offset[:offset] 
    card_numbers_grouping.slice(offset, limit)
  end
end
