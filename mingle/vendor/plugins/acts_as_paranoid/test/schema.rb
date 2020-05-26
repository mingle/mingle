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

ActiveRecord::Schema.define(:version => 1) do

  create_table :widgets, :force => true do |t|
    t.column :title, :string, :limit => 50
    t.column :category_id, :integer
    t.column :deleted_at, :timestamp
  end

  create_table :categories, :force => true do |t|
    t.column :widget_id, :integer
    t.column :title, :string, :limit => 50
    t.column :deleted_at, :timestamp
  end

  create_table :categories_widgets, :force => true, :id => false do |t|
    t.column :category_id, :integer
    t.column :widget_id, :integer
  end

end
