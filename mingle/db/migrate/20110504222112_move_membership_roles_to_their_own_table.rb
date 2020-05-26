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

class MoveMembershipRolesToTheirOwnTable < ActiveRecord::Migration
  def self.up
    create_table(:member_roles) do |t|
      t.integer  :project_id,  :null => false
      t.string   :member_type, :null => false
      t.integer  :member_id,   :null => false
      t.boolean  :admin
      t.boolean  :readonly_member
    end
    
    insert_with_select(
      :table => 'member_roles', 
      :insert_columns => ['project_id', 'member_type', 'member_id', 'admin', 'readonly_member'],
      :select_columns => ['project_id', "'User'"     , 'user_id'  , 'admin', 'readonly_member'],
      :from => 'projects_members'
    )
    
    insert_with_select(
      :table => 'member_roles', 
      :insert_columns => ['project_id', 'member_type', 'member_id',     'admin', 'readonly_member'],
      :select_columns => ['project_id', "'LuauGroup'", 'luau_group_id', 'admin', 'readonly_member'],
      :from => 'projects_luau_group_memberships'
    )
        
    if ActiveRecord::Base.table_name_prefix.blank?
      add_index :member_roles, [:project_id, :member_type, :member_id], :unique => true, :name => 'idx_unique_member_roles'
    end

    remove_column :projects_members,                :admin
    remove_column :projects_members,                :readonly_member
    remove_column :projects_luau_group_memberships, :admin
    remove_column :projects_luau_group_memberships, :readonly_member
  end

  def self.down
    drop_table :member_roles
    add_column :projects_members               , :admin          , :boolean
    add_column :projects_members               , :readonly_member, :boolean
    add_column :projects_luau_group_memberships, :admin          , :boolean
    add_column :projects_luau_group_memberships, :readonly_member, :boolean
  end
  
  private
  
  def self.insert_with_select(options)
    options[:insert_columns].unshift('id')
    insert_columns = options[:insert_columns].join(", ")
    
    options[:select_columns].unshift(next_id_sql(safe_table_name(options[:table])))
    select_columns = options[:select_columns].join(", ")
    
    sql = %{
      INSERT INTO #{safe_table_name(options[:table])} (#{insert_columns})
        (SELECT #{select_columns} FROM #{safe_table_name(options[:from])})
    }
    execute(sql)
  end
  
end
