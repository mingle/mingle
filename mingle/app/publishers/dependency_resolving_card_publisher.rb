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

class DependencyResolvingCardPublisher < ActiveRecord::Observer
  observe DependencyResolvingCard

  include Messaging::Base

  def after_create(drc)
    notify_dependents(drc)
  end

  def after_destroy(drc)
    notify_dependents(drc)
  end

  private

  def notify_dependents(drc)
    if drc.dependency.is_a? Dependency
      send_message(DependencyEventPublisher::QUEUE, [drc.dependency.message])
      send_message(CardEventPublisher::QUEUE, [drc.card.message])
    end
  end

end

DependencyResolvingCardPublisher.instance
