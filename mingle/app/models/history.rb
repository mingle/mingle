# encoding: UTF-8

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


require 'date'

class CustomDateTimeRange
  def initialize(start_date_time, end_date_time)
    @start = start_date_time
    @end = end_date_time
  end
  
  def boundaries
    return @start, @end
  end

  def description
    "between #{@start.to_formatted_s(:short)} and #{@end.to_formatted_s(:short)}"
  end
end

class Today
  def boundaries
    return Clock.now - 24.hours, Clock.now
  end
  
  def description
    "today"
  end
  
  def comment
    "(last 24 hrs)"
  end
end

class Yesterday
  def boundaries
    return Clock.now - 48.hours, Clock.now - 24.hours
  end
  
  def description
    "yesterday"
  end
  
  def comment
    "(last 24 – 48hrs)"
  end
end

class Last7Days
  def boundaries
    return Clock.now - 168.hours, Clock.now
  end
  
  def description
    "last 7 days"
  end
  
  def comment
  end
end

class Last30Days
  def boundaries
    return Clock.now - 720.hours, Clock.now
  end
  
  def description
    "last 30 days"
  end
  
  def comment
  end
end

class AllHistory
  def boundaries
    return nil, Clock.now + 1.second #now inlcudes this very second
  end
  
  def description
    "in all history"
  end
  
  def comment
  end
end

class History
  include PaginationSupport
  NAMED_PERIODS = {
    :today => Today.new,
    :yesterday => Yesterday.new,
    :last_7_days => Last7Days.new,
    :last_30_days => Last30Days.new,
    :all_history => AllHistory.new
  }

  class << self
    def for_period(project, filters = {}, paging_options = {:page => 1})
      hf = HistoryFilters.new(project, filters)
      History.new(project, hf, paging_options.merge(:paged_results => true))
    end

    def for_versioned(project, object)
      hf = HistoryFilters.new(project)
      History.new(object, hf, :paged_results => false)
    end

  end
 
  attr_reader :paginator
  def initialize(object, filters, paging_options)
    @object, @filters = object, filters
    if paging_options[:paged_results]
      @paginator = Paginator.create_with_current_page(@filters.event_count, :items_per_page => paging_options[:page_size] , :page => paging_options[:page])
    end  
  end

  def description
    @object.name + ' history'
  end  

  def period
    @filters.period
  end
      
  def events
    @events ||= find_events
  end
 
  def limit_offset_options
    defined?(@paginator) ? @paginator.limit_and_offset : {}
  end  
 
  def describe_current_page
    "Viewing #{@paginator.current_page_first_item} to #{@paginator.current_page_last_item} of #{size} #{"event".plural(size)}"
  end  

  def to_params
    Hash.new.tap do |params|
      params.merge!(@filters.to_params)
      params[:page] = 1
      params[:period] = NAMED_PERIODS.invert[period]
    end  
  end
  
  def last_update_time
    events.empty? ? "" : events.first.updated_at.to_s(:atom_time)
  end

  def last(limit)
    return events[0..limit-1]
  end

  def fresh_events(last_max_ids)
    if @object.respond_to?(:versions)
      return [] if @object.new_record?
      @object.find_events_since(last_max_ids).select { |version| version.event.history_generated? }.sort{|e1, e2| e2.updated_at <=> e1.updated_at }
    else
      @filters.fresh_events(last_max_ids)
    end
  end  

  def size
    return 0 if @object.new_record?
    return @object.history_events_in(period).size if @object.respond_to?(:versions)  
    @filters.event_count
  end  
  
  def empty?
    @empty ||= (size == 0)
  end  
  
  private
  
  def find_events
    return load_versioned_object_history if @object.respond_to?(:versions)
    load_filtered_global_history
  end
  
  def load_versioned_object_history
    @object.reload unless @object.new_record?
    @object.history_events
  end

  def load_filtered_global_history
    @filters.events(limit_offset_options)
  end
end
