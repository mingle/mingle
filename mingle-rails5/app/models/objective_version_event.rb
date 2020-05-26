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

class ObjectiveVersionEvent  < Event
  #TODO need to uncomment once this is implemented
  # include Messaging::Program::MessageProvider

  def do_generate_changes(options = {})
    changes.destroy_all
    objective_version = origin
    prev = objective_version.first? ? Objective::Version::NULL.extend(ActiveRecord::Acts::Attachable::InstanceMethods) : objective_version.previous
    changes.create_name_change(prev.name, objective_version.name) if prev.name != objective_version.name
    if prev.start_at != objective_version.start_at
      changes.create_change('start_at', (prev.start_at && prev.start_at.strftime('%Y-%m-%d')), objective_version.start_at.strftime('%Y-%m-%d'))
    end
    if prev.end_at != objective_version.end_at
      changes.create_change('end_at', (prev.end_at && prev.end_at.strftime('%Y-%m-%d')), objective_version.end_at.strftime('%Y-%m-%d'))
    end
  end

  def source_type
    'objective'
  end

  def origin_description
    "Feature"
  end

  def action_description
    origin.first? ? 'planned' : 'updated'
  end

  def source_link
    origin.objective_resource_link
  end

  def version_link
    origin.resource_link
  end

  def creation_category
    'planned'
  end
end
