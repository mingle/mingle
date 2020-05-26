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

class CardListViewTabNameHelperTest < ActionView::TestCase
  include CardListViewTabNameHelper

  class TestTab
    attr_accessor :dirty, :current
    attr_reader :name

    def initialize(project, name)
      @project = project
      @name = name
    end

    def current?
      @current
    end

    def html_id
      "html".uniquify
    end

    def counter
    end

    def dirty?
      @dirty
    end
  end

  class ControllerStub
    attr_accessor :tab_update_action

    def tab_update_action?
      @tab_update_action
    end
  end

  def setup
    @project = first_project
    @project.activate
    @view = create_tabbed_view('Stories', @project, :columns => 'type,status,priority')
    @controller = ControllerStub.new
    @controller.tab_update_action = true
  end

  def test_mark_tab_with_star_if_not_current_tab
    tab = TestTab.new(@project, 'foo')
    tab.current = false

    assert_equal 'foo',  tab_name(tab)
    tab.dirty = true
    assert_equal 'foo*',  tab_name(tab)
  end

  def test_current_tab_should_include_reset_and_save_link
    tab = TestTab.new(@project, "Stories")
    tab.current = true
    assert_equal 'Stories',  tab_name(tab)

    tab.dirty = true
    assert_match(/^Stories.*Reset.*Save/, tab_name(tab))
  end

  def test_should_only_render_reset_for_dirty_all_tab
    tab = TestTab.new(@project, "All")
    tab.current = true
    assert_equal 'All',  tab_name(tab)

    tab.dirty = true
    assert(/^All.*Reset.*Save/ !~ tab_name(tab))
    assert_match(/^All.*Reset/, tab_name(tab))
  end

  def test_should_only_show_star_for_a_current_tab_that_is_not_rendered_by_tab_update_action
    tab = TestTab.new(@project, 'Stories')
    tab.current = true
    tab.dirty = true
    @controller.tab_update_action = false
    assert_equal 'Stories*',  tab_name(tab)
  end

  def test_should_escape_tab_name
    assert_equal '&lt;script&gt;',tab_name(TestTab.new(@project, "<script>"))
  end

  def url_for(*args)
    "http://generated"
  end

  def card_list_view_link_to(*args)
    link_to(*args)
  end


end
