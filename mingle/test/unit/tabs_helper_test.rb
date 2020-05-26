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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class TabsHelperTest < ActiveSupport::TestCase

  include TabsHelper

  def setup
    @helper = Object.new
    def @helper.render(*args);end
    @default_container_class = TabsHelper::Tabs::SIDEBAR_TOP_LEVEL_CONTAINER_CLASS
    @default_prefix = 'sidebar'
    @tabs = TabsHelper::Tabs.new(
      [
        {:title => 'Tab1', :params => {:partial => 'tab1', :initially_shown => true}},
        {:title => 'Tab2', :params => {:partial => 'tab2'}}
      ], @helper, @default_container_class, @default_prefix
    )
  end

  def test_should_know_active_menu_link
    assert_equal ['tab1-container', 'tab1-active-tab', 'tab2-inactive-tab'], @tabs.first.show_elements
    assert_equal ['tab1-inactive-tab', 'tab2-container', 'tab2-active-tab'], @tabs.first.hide_elements
  end

  def test_should_know_initial_shown_links
    assert_equal ['tab1-active-tab', 'tab2-inactive-tab'], @tabs.initial_tabs
  end

  def test_should_be_able_to_specify_container_class
    tab = TabsHelper::Tabs.new([{ :title => 'Tab1', :params => {:partial => 'partial1'} }], @helper, @default_container_class, @default_prefix).first
    assert_include 'sidebar-tabs-content', tab.container_classes

    tab = TabsHelper::Tabs.new([{ :title => 'Tab1', :params => {:partial => 'partial1', :container_class => ['custom-class'] } }], @helper, @default_container_class, @default_prefix).first
    ['sidebar-tabs-content', 'custom-class'].each { |css_class| assert_include css_class, tab.container_classes }
  end

  def test_can_reorder_tabs_is_only_true_for_proj_admins
    perform_as('member') do
      assert_false can_reorder_tabs?
    end
    perform_as('proj_admin') do
      assert can_reorder_tabs?
    end
    perform_as('admin') do
      assert can_reorder_tabs?
    end
  end

  def test_can_rename_tabs_is_only_true_for_proj_admins
    perform_as('member') do
      assert_false can_rename_tabs?
    end
    perform_as('proj_admin') do
      assert can_rename_tabs?
    end
    perform_as('admin') do
      assert can_rename_tabs?
    end
  end
end
