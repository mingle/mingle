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
object @project

cache [CacheKey.project_structure_key(Project.current), 'chart_data_json']

attributes :name, :identifier, :date_format

node :card_types do |project|
  partial 'card_types/list.json', object: project.card_types
end

node :tags do |project|
  partial 'tags/list.json', object: project.tags
end

node :team do |project|
  partial 'team/list.json', object: project.users
end

node :colors do
 Color.defaults
end
