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

class AddPlannerTables < ActiveRecord::Migration
    def self.up
      create_table "plans", :force => true do |t|
        t.string   "name"
        t.date     "start_at"
        t.date     "end_at"
        t.timestamps
      end

      create_table "streams", :force => true do |t|
        t.references :plan
        t.string   "name"
        t.date     "start_at"
        t.date     "end_at"
        t.integer  "vertical_position"
        t.timestamps
      end

      create_table "scheduled_works", :force => true do |t|
        t.references :plan
        t.references :stream
        t.references :project
        t.references :card
        t.boolean "pushed"
        t.string "name"
        t.timestamps
      end
      
      create_table "draft_works", :force => true do |t|
        t.references :plan
        t.references :stream
        t.references :project
        t.references :card
        t.boolean "pushed"
        t.string "name"
        t.timestamps
      end
      
      create_table "plan_projects", :force => true do |t|
        t.column "plan_id",    :integer, :null => false
        t.column "project_id", :integer, :null => false
        t.column "done_status_id", :integer
        t.column "status_property_id", :integer
      end
    end

    def self.down
      drop_table :plans
      drop_table :streams
      drop_table :scheduled_works
      drop_table :plan_projects
    end
  end
