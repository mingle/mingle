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

class DisplayTabs

  include Enumerable

  def initialize(project, controller)
    @project = project
    @controller = controller
  end

  def each(&block)
    all_tabs.each(&block)
  end

  def sortable_tabs
    all_tabs.select(&:sortable?)
  end

  def unsortable_tabs
    all_tabs.reject(&:sortable?)
  end

  def reorder!(ordered_tab_identifiers)
    @project.ordered_tab_identifiers = ordered_tab_identifiers
    @project.save
  end

  def length
    all_tabs.length
  end

  def find_by_identifier(identifier)
    detect { |tab| tab.identifier == identifier.to_s }
  end

  def find_by_name(name)
    detect { |tab| tab.name.downcase == name.downcase }
  end

  def current
    detect { |tab| tab.current? }
  end

  def reload
    clear_cached_results_for :collect_tabs
    self
  end

  def null_tab
    NullTab.new
  end

  def source_tab
    return unless @project.has_source_repository?
    SourceTab.new(@project)
  end

  def history_tab
    HistoryTab.new(@project)
  end

  def all_tab
    AllTab.new(@project, @controller.card_context)
  end

  def dependencies_tab
    DependenciesTab.new(@project, @controller)
  end

  def overview_tab
    OverviewTab.new(@project)
  end

  private

  def ordered_tab_identifiers
    @project.ordered_tab_identifiers ||= collect_tabs.collect(&:identifier)
  end

  def all_tabs
    current_tab = @controller.current_tab

    collect_tabs.each { |tab| tab.current = false }
    current_tab = collect_tabs.detect do |disp_tab|
      disp_tab.name == current_tab[:name] && disp_tab[:type] == current_tab[:type]
    end
    current_tab.current = true if current_tab

    display_tabs = collect_tabs.dup

    sortable_tabs, unsortable_tabs = display_tabs.partition(&:sortable?)
    order = ordered_tab_identifiers
    Rails.logger.debug { "ordered_tab_identifiers: #{order.inspect}" }
    sortable_tabs = sortable_tabs.sort_by do |tab|
      Rails.logger.debug { "tab_identifier: #{tab.identifier}" }
      order.index(tab.identifier) || sortable_tabs.length + 1
    end

    sortable_tabs + unsortable_tabs
  end

  def collect_tabs
    standard_tabs = [all_tab, history_tab, source_tab]
    standard_tabs.unshift(dependencies_tab) if CurrentLicense.status.enterprise?
    ([overview_tab] + saved_view_tabs + standard_tabs).compact
  end
  memoize :collect_tabs

  def saved_view_tabs
    @project.user_defined_tab_favorites.collect do |favorite|
      if favorite.favorited.is_a?(Page)
        WikiTab.new(@project, favorite)
      else
        CardListViewTab.new(@project, favorite, @controller.card_context)
      end
    end
  end

end
