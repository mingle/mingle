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

class Feeds
  include PaginationSupport

  attr_reader :deliverable, :page
  def initialize(deliverable, page=nil)
    @deliverable = deliverable
    @page = page && page.to_i
  end

  def paginator
    @paginator ||= Paginator.create_with_current_page(logical_count, :page => @page || last_page)
  end

  def title
    @deliverable.feed_title
  end

  def updated
    entries.empty? ? deliverable.created_at : entries.first.updated
  end

  def entries
    return @__entries if @__entries

    @__entries = @deliverable.events.find(:all, paginator.limit_and_offset).collect(&:id).inject([]) do |result, event_id|
      Event.lock_and_generate_changes!(event_id)
      event = Event.find_by_id(event_id)
      result << Entry.new(event) unless event.is_a?(LiveOnlyEvents::Base)
      result
    end.reverse

    eager_loading_related_cards_for(@__entries) if @deliverable.type == Deliverable::DELIVERABLE_TYPE_PROJECT
    @__entries
  end

  def logical_count
    @__events_count ||= @deliverable.events_without_eager_loading.count
  end

  def current_page
    last_page == super ? nil : super
  end

  def last_page?
    @page.nil? || (@page >= last_page)
  end
  private

  def last_page
    logical_count / PAGINATION_PER_PAGE_SIZE + 1
  end

  def eager_loading_related_cards_for(entries)
    all_related_numbers = entries.collect(&:related_card_numbers).flatten
    all_related_cards = @deliverable.cards.find_by_numbers(all_related_numbers)
    entries.each do |entry|
      entry.related_cards = all_related_cards.select { |card| entry.related_card_numbers.include?(card.number) }.sort_by(&:number)
    end
  end

end
