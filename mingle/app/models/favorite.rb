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

class Favorite < ActiveRecord::Base

  belongs_to :project
  belongs_to :favorited, :polymorphic => true

  named_scope :of_pages, :conditions => { :favorited_type => 'Page' }
  named_scope :of_card_list_views, :conditions => { :favorited_type => 'CardListView' }
  named_scope :of_team, :conditions => { :user_id => nil }
  named_scope :personal, lambda { |user|
    user.anonymous? ? {:conditions => ['1 != 1']} : {:conditions => { :user_id => user.id }}
  }
  named_scope :include_favorited, :include => [:favorited]

  after_destroy :destroy_card_list_view

  use_database_limits_for_all_attributes

  v1_serializes_as :id, :name, :project_id, :favorited_type, :tab_view
  v2_serializes_as :id, :name, :project, :favorited_type, :tab_view

  compact_at_level 0

  class << self
    def find_or_construct_page_favorite(project, page)
      project.favorites_and_tabs.of_pages.of_team.find_by_favorited_id(page.id) || Favorite.new(:project_id => project.id, :favorited => page)
    end

    def using(model)
      if model.is_a?(CardType)
        include_favorited.select {|fav| fav.favorited.uses_card_type?(model) }
      else
        include_favorited.select {|fav| fav.favorited.uses?(model) }
      end
    end
  end

  def favorite?
    !self.tab_view?
  end

  def name
    favorited.name
  end

  def html_id
    "tab_#{name.downcase.gsub(/\s/, '_')}"
  end

  def personal?
    !user_id.nil?
  end

  def adjust(options)
    unless (options[:favorite] || options[:tab])
      self.destroy
      return
    end

    if options[:favorite]
      remove_from_tabs
    elsif options[:tab]
      make_tab
    end
  end

  def to_params
    result = if favorited.is_a?(CardListView) && !personal? && !tab_view?
      {:controller => 'cards', :action => 'index', :view => name}
    else
      favorited.link_params
    end
    result.merge(:favorite_id => id)
  end

  def destroy_card_list_view
    project.with_active_project do
      favorited.destroy if favorited.is_a?(CardListView)
    end
  end

  private

  def remove_from_tabs
    if (User.current.admin? || project.admin?(User.current) || !self.tab_view)
      self.tab_view = false
      save
    end
  end

  def make_tab
    self.tab_view = true
    save
  end
end
