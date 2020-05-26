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

class MarkPreDefinedTemplates < ActiveRecord::Migration
  def self.up
    pre_defined_template_identifiers.each do |identifier|
      pre_defined_template = Project.find(:first, :conditions => {:template => true, :identifier => identifier})
      if pre_defined_template
        pre_defined_template.pre_defined_template = true
        pre_defined_template.send(:update_without_callbacks)
      end
    end
  end
  
  def self.down
    pre_defined_template_identifiers.each do |identifier|
      pre_defined_template = Project.find(:first, :conditions => {:template => true, :identifier => identifier})
      if pre_defined_template
        pre_defined_template.pre_defined_template = nil
        pre_defined_template.send(:update_without_callbacks)
      end
    end
  end

  def self.pre_defined_template_identifiers
    [
      'agile_hybrid_template', 
      'extreme_programming_template', 
      'scrum_template', 

      'agile_hybrid_template_1_1', 
      'extreme_programming_template_1_1', 
      'scrum_template_1_1', 

      'agile_hybrid_template_2_0', 
      'scrum_template_2_0', 
      'xp_template_2_0',

      'agile_hybrid_template_2_0_1', 
      'scrum_template_2_0_1', 
      'xp_template_2_0_1',

      'agile_hybrid_template_2_1',
      'scrum_template_2_1',
      'xp_template_2_1',

      'agile_hybrid_template_2_2',
      'scrum_template_2_2',
      'xp_template_2_2',

      'agile_hybrid_template_2_3',
      'scrum_template_2_3',
      'story_tracker_template_2_3',
      'xp_template_2_3',

      'agile_hybrid_template_3_0',
      'scrum_template_3_0',
      'story_tracker_template_3_0',
      'xp_template_3_0',

      'agile_hybrid_template_3_1',
      'scrum_template_3_1',
      'story_tracker_template_3_1',
      'xp_template_3_1',

      'agile_hybrid_template_3_2',
      'scrum_template_3_2',
      'story_tracker_template_3_2',
      'xp_template_3_2',

      'agile_hybrid_template_3_3',
      'scrum_template_3_3',
      'story_tracker_template_3_3',
      'xp_template_3_3',

      'agile_hybrid_template_3_3_1',
      'scrum_template_3_3_1',
      'story_tracker_template_3_3_1',
      'xp_template_3_3_1',

      'agile_hybrid_template_3_4',
      'scrum_template_3_4',
      'story_tracker_template_3_4',
      'xp_template_3_4',

      'agile_hybrid_template_3_5',
      'agile_hybrid_with_tasks_3_5',
      'scrum_template_3_5',
      'simple_template_3_5',
      'xp_template_3_5',

      'agile_hybrid_template_12_1',
      'agile_hybrid_with_tasks_12_1',
      'scrum_template_12_1',
      'simple_template_12_1',
      'xp_template_12_1',
      'lean_template_12_1',

      'agile_hybrid_template_12_2',
      'agile_hybrid_with_tasks_12_2',
      'scrum_template_12_2',
      'simple_template_12_2',
      'xp_template_12_2',
      'lean_template_12_2',

      'agile_hybrid_template_12_3',
      'agile_hybrid_with_tasks_12_3',
      'scrum_template_12_3',
      'simple_template_12_3',
      'xp_template_12_3',
      'lean_template_12_3'
    ]
  end
end
