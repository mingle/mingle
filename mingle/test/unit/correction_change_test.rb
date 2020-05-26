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
class CorrectionChangeTest < ActiveSupport::TestCase

  def setup
    @project = project_without_cards
    @project.activate

    @event = CorrectionEvent.new(:deliverable => @project)
    @event.write_attribute(:mingle_timestamp, "2015-11-09") # this is an ignored column, set by the DB, so simulate with write_attribute

    @member = login_as_member
  end

  def test_to_xml_for_tag_rename
    change = CorrectionChange.new(:change_type => 'tag-rename', :old_value => "old", :new_value => "new", :event => @event)
    assert_equal 'tag-change', change.feed_category
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="tag-rename" mingle_timestamp="2015-11-09">
        <old_value>old</old_value>
        <new_value>new</new_value>
      </change>
    XML
  end

  def test_to_xml_for_enumerated_value_rename
    enumeration = @project.find_property_definition('iteration').find_enumeration_value('2')
    property_definition = @project.find_property_definition('iteration')
    change = CorrectionChange.new(:change_type => 'managed-property-value-change', :old_value => '2', :new_value => 'two', :resource_1 => property_definition.id, :event => @event)
    assert_equal 'property-change', change.feed_category
    assert_equal 'PropertyDefinition', change.source_type
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="managed-property-value-change" mingle_timestamp="2015-11-09">
        <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{property_definition.id}.xml" />
        <old_value>2</old_value>
        <new_value>two</new_value>
      </change>
    XML
  end

  def test_to_xml_for_property_definition_rename
    property_definition = @project.find_property_definition('Act')
    change = CorrectionChange.new(:change_type => 'property-rename', :old_value => "old", :new_value => "new", :resource_1 => property_definition.id, :event => @event)
    assert_equal 'property-change', change.feed_category
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="property-rename" mingle_timestamp="2015-11-09">
        <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{property_definition.id}.xml" />
        <old_value>old</old_value>
        <new_value>new</new_value>
      </change>
    XML
  end

  def test_to_xml_for_property_definition_deletion
    property_definition = @project.find_property_definition('Act')
    change = CorrectionChange.new(:change_type => 'property-deletion', :resource_1 => property_definition.id, :event => @event)
    assert_equal 'property-deletion', change.feed_category
    assert_equal 'PropertyDefinition', change.source_type
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="property-deletion" mingle_timestamp="2015-11-09">
        <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{property_definition.id}.xml" />
      </change>
    XML
  end

  def test_to_xml_for_card_type_rename
    card_type = @project.card_types.first
    change = CorrectionChange.new(:change_type => 'card-type-rename', :resource_1 => card_type.id, :old_value => "old", :new_value => "new", :event => @event)
    assert_equal 'card-type-change', change.feed_category
    assert_equal 'CardType', change.source_type
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="card-type-rename" mingle_timestamp="2015-11-09">
        <card_type url="http://example.com/api/v2/projects/project_without_cards/card_types/#{card_type.id}.xml" />
        <old_value>old</old_value>
        <new_value>new</new_value>
      </change>
    XML
  end

  def test_to_xml_for_card_type_disassociating_property_definition
    card_type = @project.card_types.first
    iteration = @project.find_property_definition('Iteration')
    change = CorrectionChange.new(:change_type => 'card-type-and-property-disassociation',:resource_1 => card_type.id, :resource_2 => iteration.id, :event => @event)
    assert_equal ['card-type-change', 'property-change'], change.feed_category
    assert_equal 'CardType', change.source_type
    assert_equal 'PropertyDefinition', change.secondary_source_type
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="card-type-and-property-disassociation" mingle_timestamp="2015-11-09">
        <card_type url="http://example.com/api/v2/projects/project_without_cards/card_types/#{card_type.id}.xml" />
        <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{iteration.id}.xml" />
      </change>
    XML
  end

  def test_to_xml_for_card_type_deletion_change
    card_type = @project.card_types.first
    change = CorrectionChange.new(:change_type => 'card-type-deletion', :resource_1 => card_type.id, :event => @event)
    assert_equal 'card-type-deletion', change.feed_category
    assert_equal 'CardType', change.source_type
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="card-type-deletion" mingle_timestamp="2015-11-09">
        <card_type url="http://example.com/api/v2/projects/project_without_cards/card_types/#{card_type.id}.xml" />
      </change>
    XML
  end

  #TODO this is now just a duplicate of test_to_xml_for_card_type_disassociating_property_definition
  def test_to_xml_for_card_type_disassociating_property_definition_but_resources_no_longer_exist
    change = CorrectionChange.new(:change_type => 'card-type-and-property-disassociation', :resource_1 => 9999, :resource_2 => 10000, :event => @event)
    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="card-type-and-property-disassociation" mingle_timestamp="2015-11-09">
        <card_type url="http://example.com/api/v2/projects/project_without_cards/card_types/9999.xml" />
        <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/10000.xml" />
      </change>
    XML
  end

  def test_to_xml_for_card_keywords_change
    card_keywords = @project.card_keywords
    new_card_keywords = CardKeywords.new(@project, 'wpc_like_panda_carrying_banana')
    change = CorrectionChange.new(:change_type => 'card-keywords-change', :old_value => card_keywords.to_s, :new_value => new_card_keywords.to_s, :resource_1 => @project.id, :event => @event)
    assert_equal 'project-change', change.feed_category
    assert_equal 'Project', change.source_type

    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="card-keywords-change" mingle_timestamp="2015-11-09">
        <project url="http://example.com/api/v2/projects/project_without_cards.xml" />
        <old_value>card,#</old_value>
        <new_value>wpc_like_panda_carrying_banana</new_value>
      </change>
    XML
  end

  def test_to_xml_for_project_precision_change
    change = CorrectionChange.new(:change_type => 'numeric-precision-change', :old_value => "0.1", :new_value => "0.01", :resource_1 => @project.id, :event => @event)
    assert_equal 'project-change', change.feed_category
    assert_equal 'Project', change.source_type

    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="numeric-precision-change" mingle_timestamp="2015-11-09">
        <project url="http://example.com/api/v2/projects/project_without_cards.xml" />
        <old_value>0.1</old_value>
        <new_value>0.01</new_value>
      </change>
    XML
  end

  def test_to_xml_for_repository_setting_change
    change = CorrectionChange.new(:change_type => 'repository-settings-change', :resource_1 => @project.id, :event => @event)
    assert_equal 'repository-settings-change', change.feed_category
    assert_equal 'Project', change.source_type

    assert_equal_ignoring_spaces <<-XML, xml_for(change)
      <change type="repository-settings-change" mingle_timestamp="2015-11-09">
        <project url="http://example.com/api/v2/projects/project_without_cards.xml" />
      </change>
    XML
  end


  protected

  def xml_for(change)
    view_helper.default_url_options = {:project_id => Project.current.identifier, :host => "example.com" }
    change.to_xml(:skip_instruct => true, :view_helper => view_helper, :api_version => 'v2')
  end

end
