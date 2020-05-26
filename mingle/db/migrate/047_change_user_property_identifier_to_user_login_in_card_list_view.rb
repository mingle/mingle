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

class M47Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'M47PropertyDefinition', :foreign_key => 'project_id'
  has_many :card_list_views, :class_name => 'M47CardListView', :foreign_key => 'project_id'
  has_many :users, :through => :projects_members, :class_name => 'M47User'
  has_many :projects_members, :class_name => 'M47ProjectsMembers', :foreign_key => 'project_id'
end

class M47CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  
  belongs_to :project, :foreign_key => 'project_id', :class_name => 'M47Project'
  serialize :params
end

class M47PropertyDefinition < ActiveRecord::Base
  set_table_name 'property_definitions'
  self.inheritance_column = 'm47_type' #disable single table inheretance
  belongs_to :project, :class_name => 'M47Project', :foreign_key => 'project_id'
end

class M47User < ActiveRecord::Base
  set_table_name 'users'
end

class M47ProjectsMembers < ActiveRecord::Base
  set_table_name 'projects_members'
  belongs_to :project, :class_name => 'M47ProjectsMembers', :foreign_key => 'project_id'
  belongs_to :user, :class_name => 'M47User', :foreign_key => 'user_id'
end

class ChangeUserPropertyIdentifierToUserLoginInCardListView < ActiveRecord::Migration
  
  class CardListViewReviser
    def initialize(project, card_list_view)
      @project = project
      @card_list_view = card_list_view
    end
  
    def revise
      @params = @card_list_view.params
      revise_filters
      revise_lanes
      @card_list_view.params = @params
      @card_list_view.save_with_validation(false)
    end
  
    private
  
    def revise_filters
      filters = @params[:filter_properties] || {} 
      filters.each do |key, value|
        next unless user_property?(key)
        next if value.blank?
        if user = @project.users.find_by_id(value.to_i)
          filters[key] = user.login
        else
          filters.delete(key)
        end
      end
      @params.delete(:filter_properties) if filters.empty?
    end
  
    def revise_lanes
      return if @params[:group_by].blank? || @params[:lanes].blank?
      return unless user_property?(@params[:group_by])
      lanes = @params[:lanes].split(',').collect do |id|
        if id.blank?
          id
        elsif user = @project.users.find_by_id(id.to_i)
          user.login
        end
      end
      lanes.compact!
      if lanes.empty?
        @params.delete(:lanes) 
      else
        @params[:lanes] = lanes.join(',')
      end
    end
  
    def user_property_definitions
      @project.property_definitions.find_all_by_type('UserPropertyDefinition')
    end
  
    def user_property?(name)
      user_property_definitions.any?{|pd| pd.name.downcase == name.downcase}
    end
  end
  
  def self.up
    M47Project.find(:all).each do |project|
      project.card_list_views.each do |card_list_view|
        CardListViewReviser.new(project, card_list_view).revise
      end
    end
  rescue Exception => e
    begin
      M47CardListView.logger.error("Unexpected error happens when trying to migrate saved views. Going to delete all saved views to maintain data integrity.")
      M47CardListView.logger.error(e)
      M47CardListView.delete_all 
    rescue Exception
      #do nothing
    end
  end
  
  def self.down
    M47CardListView.delete_all
  end
end
