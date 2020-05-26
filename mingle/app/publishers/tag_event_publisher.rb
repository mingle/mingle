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

class TagEventPublisher < ActiveRecord::Observer
  CARD_EVENT_QUEUE = 'mingle.card_events'
  PAGE_EVENT_QUEUE = 'mingle.page_events'

  observe Tag

  include Messaging::Base

  def after_update(tag)
    if tag.name_changed? || tag.color_changed?
      LiveOnlyEvents::TagUpdate.create_for(tag.project, tag) do |event|
        if tag.name_changed?
          event.changes.create_change(
            "name",
            tag.changes["name"].first,
            tag.changes["name"].last
          )
        end

        if tag.color_changed?
          event.changes.create_change(
            "color",
            tag.changes["color"].first,
            tag.changes["color"].last
          )
        end
      end
    end
  end

  def after_create(tag)
    LiveOnlyEvents::TagCreate.create_for(tag.project, tag) do |event|
      event.changes.create_change(
        "name",
        nil,
        tag.name
      )

      if tag.color
        event.changes.create_change(
          "color",
          nil,
          tag.color
        )
      end
    end
  end

  def after_destroy(tag)
    LiveOnlyEvents::TagDelete.create_for(tag.project, tag)
  end

  def after_save(tag)
    tag.tagged_cards.each do |card|
      send_message(CARD_EVENT_QUEUE, [card.message])
    end
    tag.tagged_pages.each do |page|
      send_message(PAGE_EVENT_QUEUE, [page.message])
    end
  end

end

TagEventPublisher.instance
