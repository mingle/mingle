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

ActiveRecord::Schema.define(:version => 0) do
  create_table :pages, :force => true do |t|
    t.column :version, :integer
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :author_id, :integer
    t.column :revisor_id, :integer
  end

  create_table :page_versions, :force => true do |t|
    t.column :page_id, :integer
    t.column :version, :integer
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :author_id, :integer
    t.column :revisor_id, :integer
  end
  
  add_index :page_versions, [:page_id, :version], :unique => true
  
  create_table :authors, :force => true do |t|
    t.column :page_id, :integer
    t.column :name, :string
  end
  
  create_table :locked_pages, :force => true do |t|
    t.column :lock_version, :integer
    t.column :title, :string, :limit => 255
    t.column :type, :string, :limit => 255
  end

  create_table :locked_pages_revisions, :force => true do |t|
    t.column :page_id, :integer
    t.column :version, :integer
    t.column :title, :string, :limit => 255
    t.column :version_type, :string, :limit => 255
    t.column :updated_at, :datetime
  end
  
  add_index :locked_pages_revisions, [:page_id, :version], :unique => true

  create_table :widgets, :force => true do |t|
    t.column :name, :string, :limit => 50
    t.column :foo, :string
    t.column :version, :integer
    t.column :updated_at, :datetime
  end

  create_table :widget_versions, :force => true do |t|
    t.column :widget_id, :integer
    t.column :name, :string, :limit => 50
    t.column :version, :integer
    t.column :updated_at, :datetime
  end
  
  add_index :widget_versions, [:widget_id, :version], :unique => true
  
  create_table :landmarks, :force => true do |t|
    t.column :name, :string
    t.column :latitude, :float
    t.column :longitude, :float
    t.column :doesnt_trigger_version,:string
    t.column :version, :integer
  end

  create_table :landmark_versions, :force => true do |t|
    t.column :landmark_id, :integer
    t.column :name, :string
    t.column :latitude, :float
    t.column :longitude, :float
    t.column :doesnt_trigger_version,:string
    t.column :version, :integer
  end
  
  add_index :landmark_versions, [:landmark_id, :version], :unique => true
end
