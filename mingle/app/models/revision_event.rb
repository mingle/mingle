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

class RevisionEvent < Event

  include Messaging::MessageProvider

  def do_generate_changes(options = {})
    changes.destroy_all
    changes.create_revision_change
  end  
  
  def description
    "#{origin.description} at #{created_at}. #{origin.commit_message_not_longer_than_255}"
  end
  
  def origin_description
    "Revision #{origin.short_identifier}"
  end
  
  def action_description
    "committed"
  end
  
  def source_type
    'revision'
  end
  
  def source_link
    origin.resource_link
  end
  
  def author
    created_by || NonMingleAuthor.new(origin.user)
  end
end
