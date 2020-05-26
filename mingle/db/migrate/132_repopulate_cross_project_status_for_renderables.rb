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

class M132RenderableVersionRenderedProject  < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}renderable_version_rendered_projects"
end
  
class M132Project < ActiveRecord::Base
  include MigrationHelper
  
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :renderable_version_rendered_projects, :class_name => 'M132RenderableVersionRenderedProject', :foreign_key => 'rendered_project_id'
  
  def card_table_name
    safe_table_name(self.identifier + '_cards')
  end
  
  def card_version_table_name
    safe_table_name(self.identifier + '_card_versions')
  end
end


class RepopulateCrossProjectStatusForRenderables < ActiveRecord::Migration
  def self.up
    M132Project.find(:all).each do |project|
      next unless ActiveRecord::Base.connection.table_exists?("#{ActiveRecord::Base.table_name_prefix}#{project.identifier}_cards")
      
      card_version_rps = project.renderable_version_rendered_projects.select do |rp|
        rp.renderable_version_type == 'Card::Version'
      end
      cross_project_card_versions_ids = card_version_rps.collect(&:renderable_version_id)
      next if cross_project_card_versions_ids.empty?
      execute("UPDATE #{project.card_version_table_name} SET has_cross_project_macro = true where id in (#{cross_project_card_versions_ids.join(',')})")
    end
    page_version_rps = M132RenderableVersionRenderedProject.find_all_by_renderable_version_type('Page::Version')
    cross_project_page_versions_ids = page_version_rps.collect(&:renderable_version_id)
    return if cross_project_page_versions_ids.empty?
    execute("UPDATE #{safe_table_name('page_versions')} SET has_cross_project_macro = true where id in (#{cross_project_page_versions_ids.join(',')})")
  end

  def self.down
    M132Project.find(:all).each do |project|
      execute("update #{project.card_version_table_name} set has_cross_project_macro = false")
    end
    execute("update #{safe_table_name('page_versions')} set has_cross_project_macro = false")
  end
end
