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

Change
class HistoryHelperTest < ActionController::TestCase
  include HistoryHelper, ActionView::Helpers::UrlHelper, UserAccess

  def test_history_filter_query_string_should_contain_the_correct_filter_info
    assert_equal 'involved_filter_tags=rss,security', history_filter_query_string({:involved_filter_tags => 'rss,security'})
    assert_equal 'acquired_filter_tags=security,api&involved_filter_tags=rss',
                 history_filter_query_string({:involved_filter_tags => 'rss', :acquired_filter_tags => 'security,api'})
    assert_equal_ignoring_order 'involved_filter_properties[status]=new&involved_filter_properties[type]=bug',
                 history_filter_query_string({:involved_filter_properties => {'status' => 'new', 'type' => 'bug'}})
    assert_equal_ignoring_order 'acquired_filter_properties[status]=new&acquired_filter_properties[type]=bug',
                 history_filter_query_string({:acquired_filter_properties => {'status' => 'new', 'type' => 'bug'}})
    assert_nil history_filter_query_string({:period => 'today'})
  end

  def test_should_return_all_property_definitions_when_the_card_type_is_any
    with_new_project do |project|
      @project = project
      type_story = project.card_types.create!(:name => 'story')
      type_bug = project.card_types.create!(:name => 'bug')
      setup_property_definitions(:status => ['open'], :size => [4])
      status = project.find_property_definition('status')
      size = project.find_property_definition('size')
      type_story.add_property_definition status
      type_story.add_property_definition size
      type_bug.add_property_definition status

      property_definitions_for_filter = property_definitions_for_filter(nil)

      assert_equal 3, property_definitions_for_filter.size
      assert_equal Project.card_type_definition.name, property_definitions_for_filter.first.name
    end
  end

  def test_should_not_order_card_type_specified_property_definitions_by_position
    with_new_project do |project|
      @project = project
      @type_story = project.card_types.create!(:name => 'story')
      setup_property_definitions(:status => ['open'], :size => [4], :iteration => [1, 2])
      @status = project.find_property_definition('status')
      @iteration = project.find_property_definition('iteration')
      @size = project.find_property_definition('size')

      @type_story.add_property_definition @status
      @type_story.add_property_definition @iteration
      @type_story.add_property_definition @size

      property_definitions_for_filter = property_definitions_for_filter('story')

      assert_equal 4, property_definitions_for_filter.size
      assert_equal(['Type', 'iteration', 'size', 'status'], property_definitions_for_filter.collect(&:name))
    end
  end

  def test_should_show_plain_url_to_none_member_user
    set_up_url_generation_context
    set_anonymous_access_for(@project, true)
    logout_as_nil
    assert_equal "http://example.com/projects/#{@project.identifier}/feeds.atom", history_atom_url(nil)
    login_as_longbob
    assert_equal "http://example.com/projects/#{@project.identifier}/feeds.atom", history_atom_url(nil)
  end

  def test_should_show_plain_filter_params_on_feed_url_for_none_member_user
    set_up_url_generation_context
    set_anonymous_access_for(@project, true)
    logout_as_nil
    assert_equal "http://example.com/projects/#{@project.identifier}/feeds.atom?involved_filter_properties[status]=new", history_atom_url(:involved_filter_properties => {'status' => 'new'})
  end

  def test_should_encrypte_feed_url_for_team_member_and_admin_even_project_is_anonymous_accessible
    set_up_url_generation_context
    set_anonymous_access_for(@project, true)
    login_as_admin
    assert_equal "http://example.com/projects/#{@project.identifier}/feeds/encrypted_params.atom", history_atom_url(nil)
    login_as_member
    assert_equal "http://example.com/projects/#{@project.identifier}/feeds/encrypted_params.atom", history_atom_url(nil)
  end

  def test_should_display_card_relationship_properties
    with_card_query_project do |project|
      @project = project
      assert property_definitions_for_filter.collect(&:name).include?('related card')
    end
  end

  def set_up_url_generation_context
    @controller = HistoryController.new
    def @controller.url_for(options)
      FakeViewHelper.new.url_for(options.merge({:host => "example.com"}))
    end

    @project = first_project
    @project.activate
    def @project.encrypt(params)
      'encrypted_params'
    end
  end
end
