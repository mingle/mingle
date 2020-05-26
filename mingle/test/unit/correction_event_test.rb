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

# Tags: feeds
class CorrectionEventTest < ActiveSupport::TestCase
  def setup
    @project = project_without_cards
    @project.activate
    @member = login_as_member
  end

  def test_origin_description_for_enumeration_value_change_event
    enumeration = @project.find_enumeration_value("iteration", '2')
    enumeration.update_attribute(:value, 'two')
    correction_event = @project.events.last
    assert_equal "Property definition", correction_event.origin_description
  end

  def test_origin_description_for_property_def_deletion_event
    with_new_project do |project|
      setup_property_definitions :iteration => ['1', '2']
      iteration = project.find_property_definition("iteration")
      iteration.destroy
      correction_event = project.events.last
      assert_equal "Property definition", correction_event.origin_description
    end
  end

  def test_create_changes_for_property_def_deleteion
    with_new_project do |project|
      setup_property_definitions :iteration => ['1', '2']
      iteration = project.find_property_definition("iteration")
      iteration.destroy
      correction_event = project.events.last
      assert_equal 1, correction_event.changes.size
      assert_nil correction_event.changes.first.old_value
      assert_nil correction_event.changes.first.new_value
      assert_equal 'property-deletion', correction_event.changes.first.change_type
    end
  end

  def test_default_correction_event_source_link_should_be_nil
    card = create_card!(:name => "1")
    card.tag_with("foo").save!
    tag = @project.tags.first

    tag.update_attribute(:name, "bar")
    correction_event = @project.events.last

    assert_equal CorrectionEvent, correction_event.class
    assert_nil source_link(correction_event)
  end

  def test_should_create_on_enumeration_value_changes
    enumeration = @project.find_enumeration_value("iteration", '2')

    Clock.now_is("2010-09-22 23:59:00") do
      enumeration.update_attribute(:value, 'two')
      correction_event = @project.events.last
      assert_equal @member, correction_event.created_by
      assert_equal Clock.now, correction_event.created_at
      assert_equal enumeration.property_definition, correction_event.origin

      change = correction_event.changes.first
      assert_equal 1, correction_event.changes.size
      assert_equal '2', change.old_value
      assert_equal 'two', change.new_value
      assert_equal correction_event, change.event
      assert_equal 'PropertyDefinition', change.source_type
      assert_equal enumeration.property_definition.id, change.resource_1
    end
  end

  def test_should_not_create_unless_enumeration_value_changes
    enumeration = @project.find_enumeration_value("iteration", '2')
    assert_no_difference("CorrectionEvent.count") { enumeration.save }
  end

  def test_enumeration_value_corrention_event_source_link
    enumeration = @project.find_enumeration_value("iteration", '2')
    enumeration.update_attribute(:value, 'two')
    correction_event = @project.events.last
    assert_equal "http://example.com/api/v2/projects/project_without_cards/property_definitions/#{enumeration.property_definition.id}.xml", source_link(correction_event)
  end

  def test_should_create_on_property_rename
    property = @project.property_definitions.first
    old_name = property.name
    property.update_attribute(:name, "new name")
    correction_event = @project.events.last

    assert_equal property, correction_event.origin
    change = correction_event.changes.first
    assert_equal old_name, change.old_value
    assert_equal "new name", change.new_value
    assert_equal property.id, change.resource_1
    assert_equal 'PropertyDefinition', change.source_type
  end

  def test_should_not_create_any_event_on_aggregate_property_rename
    with_three_level_tree_project do |project|
      aggregate_prop_def = project.all_property_definitions.find_by_name('Sum of size')

      assert_no_difference "CorrectionEvent.count" do
        aggregate_prop_def.update_attribute(:name, "new aggregate prop def")
      end
    end
  end

  def test_property_rename_source_link
    property = @project.property_definitions.first
    old_name = property.name
    property.update_attribute(:name, "new name")
    correction_event = @project.events.last

    assert_equal "http://example.com/api/v2/projects/project_without_cards/property_definitions/#{property.id}.xml", source_link(correction_event)
  end

  def test_should_create_event_on_property_deletion
    with_new_project(:name => 'project_1') do |project|
      property = project.all_property_definitions.create_text_list_property_definition(:name => 'Short Lived Property')
      property.destroy
      correction_event = project.events.last

      assert_equal property.id, correction_event.origin_id
      change = correction_event.changes.first
      assert_nil change.old_value
      assert_nil change.new_value
      assert_equal property.id, change.resource_1
      assert_equal 'PropertyDefinition', change.source_type
      assert_equal "http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{property.id}.xml", source_link(correction_event)
    end
  end

  def test_should_create_tag_rename_change
    card = create_card!(:name => "1")
    card.tag_with("foo").save!
    tag = @project.tags.first
    tag.update_attribute(:name, "bar")

    correction_event = @project.events.last
    assert_equal CorrectionEvent, correction_event.class
    assert_equal tag, correction_event.origin

    change = correction_event.changes.first
    assert_equal correction_event, change.event
    assert_equal 1, correction_event.changes.size
    assert_equal "foo" , change.old_value
    assert_equal "bar" , change.new_value
    assert_nil change.resource_1
    assert_equal 'tag-rename', change.change_type
  end

  def test_should_not_create_unless_tag_name_changes
    card = create_card!(:name => "1")
    card.tag_with("foo").save!
    tag = @project.tags.first
    assert_no_difference("CorrectionEvent.count") { tag.update_attribute(:name, "foo") }
  end

  def test_should_create_card_type_rename_change
    card_type = @project.card_types.first
    original_name = card_type.name
    card_type.update_attribute(:name, "renamed")

    correction_event = @project.events.last
    assert_equal card_type, correction_event.origin
    change = correction_event.changes.first
    assert_equal 1, correction_event.changes.size
    assert_equal original_name , change.old_value
    assert_equal "renamed" , change.new_value
    assert_equal "CardType", change.source_type
    assert_equal card_type.id, change.resource_1
  end

  def test_card_type_rename_event_source_link
    card_type = @project.card_types.first
    original_name = card_type.name

    card_type.update_attribute(:name, "renamed")
    correction_event = @project.events.last

    assert_equal "http://example.com/api/v2/projects/project_without_cards/card_types/#{card_type.id}.xml", source_link(correction_event)
  end

  def test_should_not_create_unless_card_type_name_changes
    card_type = @project.card_types.first
    assert_no_difference("CorrectionEvent.count") { card_type.save }
  end

  def test_should_not_create_property_change_event_without_adding_a_change
    iteration = @project.find_property_definition("iteration")
    assert_no_difference("CorrectionEvent.count") { iteration.update_attribute(:position, 222) }
  end

  def test_should_create_property_card_type_disassoication_change_on_remove_property_from_card_type
    card_type = @project.card_types.first
    iteration = @project.find_property_definition("iteration")
    card_type.property_definitions = card_type.property_definitions - [iteration]
    card_type.save!
    correction_event = @project.events.last
    assert_not_nil correction_event
    assert_equal card_type, correction_event.origin
    assert_equal 1, correction_event.changes.size
    assert_equal 'card-type-and-property-disassociation', correction_event.changes.first.change_type
    assert_equal card_type.id, correction_event.changes.first.resource_1
    assert_equal iteration.id, correction_event.changes.first.resource_2
  end

  def test_should_create_correction_event_for_card_type_deletion
    card_type = @project.card_types.first
    card_type.destroy
    correction_event = @project.events.last
    assert_not_nil correction_event
    assert_equal card_type.class.name, correction_event.origin_type
    assert_equal card_type.id, correction_event.origin_id

    assert_equal 1, correction_event.changes.size
    assert_equal 'card-type-deletion', correction_event.changes.first.change_type
    assert_equal card_type.id, correction_event.changes.first.resource_1
  end

  def test_should_create_correction_event_for_project_card_keywords_change
    @project.update_attribute(:card_keywords, 'hellocard')
    correction_event = @project.events.last
    assert_equal @project.id, correction_event.origin_id

    change = correction_event.changes.first
    assert_equal 1, correction_event.changes.size
    assert_equal 'card-keywords-change', change.change_type
    assert_equal @project.id, change.resource_1
    assert_equal 'card, #', change.old_value
    assert_equal 'hellocard', change.new_value
  end

  def test_should_create_correction_event_for_numeric_precision_change
    old_precision = @project.precision
    new_precision = '3'
    @project.update_attribute(:precision, new_precision)
    correction_event = @project.events.last

    assert_equal @project.id, correction_event.origin_id
    change = correction_event.changes.first
    assert_equal 1, correction_event.changes.size
    assert_equal 'numeric-precision-change', change.change_type
    assert_equal @project.id, change.resource_1
    assert_equal old_precision.to_s, change.old_value
    assert_equal "3", change.new_value
  end

  def test_should_create_single_event_if_update_project_precision_and_card_keywords_at_same_time
    @project.update_attributes(:card_keywords => 'hellocard', :precision => '3')

    correction_event = @project.events.last

    assert_equal @project.id, correction_event.origin_id
    change = correction_event.changes.first
    assert_equal 2, correction_event.changes.size
    assert_equal ['card-keywords-change', 'numeric-precision-change'], correction_event.changes.collect(&:change_type).sort
  end

  def test_should_create_correction_event_for_repository_settings_change
    does_not_work_without_subversion_bindings do
      login_as_admin
      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "play #100"
      end

      config = SubversionConfiguration.create!(:project_id => @project.id, :repository_path => repos_driver.repos_dir)
      @project.reload
      RevisionsHeaderCaching.run_once

      @project.delete_repository_configuration
      RevisionsHeaderCaching.run_once

      assert_equal 1, Event.find_all_by_deliverable_id_and_type(@project.id, 'CorrectionEvent').size

      correction_event = @project.events.reload.last
      assert_equal @project, correction_event.origin
      change = correction_event.changes.first
      assert_equal 1, correction_event.changes.size
      assert_equal 'repository-settings-change', change.change_type
      assert_equal @project.id, change.resource_1
    end
  end

  def test_should_create_correction_event_for_hg_repository_settings_change_if_there_is_at_least_one_revision
    requires_jruby do
      login_as_admin
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path =>"/a_repos", :username =>'bobo', :password => "password")
      revision = Revision.create_from_repository_revision(OpenStruct.new(:number => 34, :time => Time.now), @project)
      @project.reload
      @project.delete_repository_configuration
      RevisionsHeaderCaching.run_once

      assert_equal 1, Event.find_all_by_deliverable_id_and_type(@project.id, 'CorrectionEvent').size
      correction_event = @project.events.reload.last
      assert_equal @project, correction_event.origin

      change = correction_event.changes.first
      assert_equal 1, correction_event.changes.size
      assert_equal 'repository-settings-change', change.change_type
      assert_equal @project.id, change.resource_1
    end
  end

  def test_should_assign_mingle_system_as_author_for_repository_settings_change
    does_not_work_without_subversion_bindings do
      logout_as_nil
      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "play #100"
      end

      config = SubversionConfiguration.create!(:project_id => @project.id, :repository_path => repos_driver.repos_dir)
      @project.reload
      RevisionsHeaderCaching.run_once

      @project.delete_repository_configuration
      RevisionsHeaderCaching.run_once

      correction_event = @project.events.reload.last
      assert_equal 'Mingle System', correction_event.author.name
    end
  end
  private

  def source_link(event)
    view_helper.default_url_options = {:project_id => Project.current.identifier, :host => 'example.com'}
    event.source_link.xml_href(view_helper, 'v2')
  end
end
