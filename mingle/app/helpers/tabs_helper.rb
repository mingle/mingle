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

module TabsHelper
  include UserAccess

  def can_reorder_tabs?
    authorized?(:controller => "tabs", :action => "reorder")
  end

  def can_rename_tabs?
    authorized?(:controller => "tabs", :action => "rename")
  end

  class Tabs
    SIDEBAR_TOP_LEVEL_CONTAINER_CLASS = "sidebar-top-level-container"

    include Enumerable

    def initialize(tabs, view_helper, top_level_container_class, prefix)
      all_tab_titles = tabs.collect{ |tab_params| tab_params[:title] }
      @tabs = tabs.collect{ |tab_params| Tab.new(tab_params[:title], view_helper, tab_params[:params], all_tab_titles.without(tab_params[:title]), top_level_container_class, prefix) }
    end

    def each
      @tabs.each{ |tab| yield tab }
    end

    def first
      @tabs.first
    end

    def initial_tabs
      shown, hidden = @tabs.partition(&:initially_shown?)
      shown.collect(&:active_tab) + hidden.collect(&:inactive_tab)
    end

  end

  class Tab
    attr_reader :name, :container_classes, :params

    def initialize(name, view_helper, tab_params, other_tabs, top_level_container_class, prefix)
      @name, @params, @other_tabs = name, tab_params, other_tabs
      @view_helper = view_helper
      @initially_shown = @params.delete(:initially_shown)
      @container_classes = ["#{prefix}-tabs-content"] + (@params.delete(:container_class) || [])
      @top_level_container_class = top_level_container_class
    end

    def hide_elements
      [inactive_tab, *other_containers] + other_active_tabs
    end

    def show_elements
      return container, active_tab, *other_inactive_tabs
    end

    def initially_shown?
      @initially_shown
    end

    def switching_tab_link(helper)
      tab = self
      top_level_container_class = @top_level_container_class
      helper.link_to_function(@name, nil, :id =>"#{@name.downcase.dashed}-link") do |page|
        page << "var container = $(this).up('.#{top_level_container_class}');"
        page << "#{tab.show_elements.to_json}.each(Element.showIn.curry(container));"
        page << "#{tab.hide_elements.to_json}.each(Element.hideIn.curry(container));"
      end
    end

    def inactive_tab
      "#{@name.downcase.dashed}-inactive-tab"
    end

    def active_tab
      "#{@name.downcase.dashed}-active-tab"
    end

    def container
      content_container_id(@name)
    end

    private
    def other_containers
      @other_tabs.collect { |t| content_container_id(t)}
    end

    def content_container_id(tab_name)
      "#{tab_name.downcase.dashed}-container"
    end


    def other_active_tabs
      @other_tabs.collect {|t| "#{t.downcase.dashed}-active-tab"}
    end

    def other_inactive_tabs
      @other_tabs.collect {|t| "#{t.downcase.dashed}-inactive-tab"}
    end

  end

end
