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

class DeletedCard < Card
  def self.new_from_last_version(card_id)
    last_version = Card::Version.find(:first, :conditions => {:card_id => card_id}, :order => 'version DESC')
    return nil unless last_version
    attributes = last_version.attributes
    attributes.delete("card_id")
    attributes.delete("updater_id")

    deleted = self.new(attributes)
    deleted.id = last_version.card_id
    deleted
  end

  def self.element_name(options)
    'card'
  end

  def resource_link
    Card.resource_link(type_and_number, :number => number, :project_id => project.identifier)
  end

  def card_type
    super || DeletedCardType.new(self.card_type_name)
  end

  def save
    raise 'cannot save a deleted card'
  end
end
