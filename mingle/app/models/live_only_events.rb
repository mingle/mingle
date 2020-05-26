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

module LiveOnlyEvents

  class Base < Event
    include Messaging::MessageProvider
    include PushableNotificationEmitter
  end

  class CardRank < Base
    def self.create_for(project, card)
      card_version = card.latest_version_object
      with_project_scope(project.id, Clock.now.utc, User.current.id) do
        event = create!(current_scoped_methods[:create].merge(:origin => card_version))
        event.changes.create_change(
          "rank",
          card.changes["project_card_rank"].first,
          card.changes["project_card_rank"].last
        )
      end
    end

    def origin_description
      [source_type, action_description].join(" ")
    end

    def source_type
      "card"
    end

    def action_description
      "ranked"
    end

    def creation?
      false
    end

    def do_generate_changes
    end

    def source_link
      origin.card_resource_link
    end

    def snapshot
      {
        :Number => origin.number,
        :"&rank" => origin.card.rank.to_s("F")
      }
    end

  end


  class BaseTagEvent < Base

    def self.create_for(project, tag, &block)
      with_project_scope(project.id, Clock.now.utc, User.current.id) do
        event = create!(current_scoped_methods[:create].merge(:origin => tag))
        yield(event) if block_given?
      end
    end

    def origin_description
      [source_type, action_description].join(" ")
    end

    def source_type
      "tag"
    end

    def creation?
      false
    end

    def do_generate_changes
    end

    def source_link
      project.resource_link
    end

    def snapshot
      tag = origin

      if ("deleted" == action_description)
        return {
          :id => tag.id,
          :name => tag.name
        }
      end

      {
        :id => tag.id,
        :name => tag.name,
        :color => tag.color,
        :cards => tag.tagged_cards.map(&:number)
      }
    end

  end

  class TagCreate < BaseTagEvent
    def creation?
      true
    end
  end

  class TagUpdate < BaseTagEvent; end

  class TagDelete < BaseTagEvent
    def action_description
      "deleted"
    end
  end

end
