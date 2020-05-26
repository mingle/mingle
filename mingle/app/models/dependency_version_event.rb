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

class DependencyVersionEvent < Event

  include Messaging::MessageProvider
  include AttachmentChangesGenerator

  def do_generate_changes
    changes.destroy_all
    dependency_version = origin
    prev = dependency_version.first? ? Dependency::Version::NULL.extend(ActiveRecord::Acts::Attachable::InstanceMethods) : dependency_version.previous
    changes.create_dependency_resolving_project_change('Resolving project', prev.resolving_project_id, dependency_version.resolving_project_id) if prev.resolving_project_id != dependency_version.resolving_project_id
    changes.create_name_change(prev.name, dependency_version.name) if prev.name != dependency_version.name
    changes.create_raising_card_change(dependency_version.raising_card) if prev.raising_card != dependency_version.raising_card
    changes.create_description_change if prev.description != dependency_version.description
    changes.create_dependency_property_change('Desired end date', prev.formatted_desired_end_date, dependency_version.formatted_desired_end_date) if prev.desired_end_date != dependency_version.desired_end_date
    changes.create_dependency_new_cards_linked_change(cards_linked(prev.resolving_cards, origin.resolving_cards)) if newCardslinked?(prev.resolving_cards, origin.resolving_cards)
    changes.create_dependency_cards_unlinked_change(cards_unlinked(prev.resolving_cards, origin.resolving_cards)) if cardsUnlinked?(prev.resolving_cards, origin.resolving_cards)
    changes.create_dependency_property_change('Status', prev.status, dependency_version.status) if prev.status != dependency_version.status
    generate_changes_for_attachments(dependency_version, prev)
  end

  def cards_linked(prev_cards, orig_cards)
    prev_cards = prev_cards ? prev_cards : []
    orig_cards = orig_cards ? orig_cards : []
    orig_cards - prev_cards
  end

  def cards_unlinked(prev_cards, orig_cards)
    prev_cards = prev_cards ? prev_cards : []
    orig_cards = orig_cards ? orig_cards : []
    prev_cards - orig_cards
  end

  def source_type
    'dependency'
  end

  def origin_description
    (origin && origin.dependency) ? origin.dependency.short_description : "Deleted dependency"
  end

  def action_description
    'Dependency modified'
  end

  def snapshot
    if ("deleted" == action_description)
      return {
        :Number => origin.number
      }
    end

    origin.dependency_snapshot
  end

  def source_link
    nil
  end

  private
  def newCardslinked?(prev_cards, orig_cards)
    cards_linked(prev_cards, orig_cards).size > 0
  end

  def cardsUnlinked?(prev_cards, orig_cards)
    cards_unlinked(prev_cards, orig_cards).size > 0
  end

end
