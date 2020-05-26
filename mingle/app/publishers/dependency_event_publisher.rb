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

class DependencyEventPublisher < ActiveRecord::Observer
  QUEUE = "mingle.dependency_events"

  observe Dependency

  include Messaging::Base

  def after_save(dependency)
    card_messages = [dependency.raising_card.message]
    unless dependency.resolving_project.blank?
      dependency.resolving_project.with_active_project do |project|
        dependency.dependency_resolving_cards.each {|drc| card_messages << project.cards.find_by_number(drc.card_number).message}
      end
    end

    card_messages.uniq! {|m| "#{m[:project_id]}/#{m[:id]}"}

    send_message(QUEUE, [dependency.message])
    send_message(CardEventPublisher::QUEUE, card_messages)
  end

end

DependencyEventPublisher.instance
