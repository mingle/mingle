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
class FeedsTest < ActiveSupport::TestCase
  def setup
    @project = project_without_cards
    @project.activate
    @member = login_as_member
    view_helper.default_url_options = { :host => 'example.com', :project_id => Project.current.identifier}
  end

  def test_title
    assert_equal "Mingle Events for Project: #{@project.name}", feeds.title
  end

  def test_updated_should_be_when_last_event_happened
    with_first_project do |project|
      assert_equal project.events.last.created_at.to_i, feeds(project).updated.to_i
    end
  end

  def test_updated_is_project_created_time_when_there_are_no_entries
    with_project_without_cards do |project|
      assert_equal project.created_at.to_i, feeds(project).updated.to_i
    end
  end

  def test_entries_should_be_same_count_of_all_events
    with_first_project do |project|
      assert_equal project.events_without_eager_loading.count, feeds(project).logical_count
    end
  end

  def test_entries_should_be_latest_first_order
    with_first_project do |project|
      create_card!(:name => 'hello')
      assert feeds(project).entries.first.updated > feeds(project, 1).entries.last.updated
    end
  end

  def test_entries_updated_time_should_be_when_the_event_happend
    event = create_card!(:name => 'hello').versions.last.event
    assert_equal event.created_at.to_i, feeds.entries.first.updated.to_i
  end

  def test_entry_title_for_card_creation
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'hello')

      assert_equal "Card ##{card.number} hello created", feeds.entries.first.title
      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
<changes xmlns="#{Mingle::API.ns}">
  <change type=\"card-creation\"/>
  <change type=\"card-type-change\" mingle_timestamp=\"2015-11-09\">
    <old_value nil=\"true\"></old_value>
    <new_value>
      <card_type url=\"http://example.com/api/v2/projects/project_without_cards/card_types/#{card.card_type.id}.xml\">
        <name>Card</name>
      </card_type>
    </new_value>
  </change>
  <change type=\"name-change\" mingle_timestamp=\"2015-11-09\">
    <old_value nil=\"true\"></old_value>
    <new_value>hello</new_value>
  </change>
</changes>
XML
    end
  end

  def test_entry_title_for_page_creation
    @project.pages.create(:name => 'new page')
    assert_equal "Page new page created", feeds.entries.first.title
  end

  def test_entry_title_for_page_update
    page = @project.pages.create(:name => 'new page')
    page.update_attribute(:content, 'du da')
    assert_equal "Page new page changed", feeds.entries.first.title
  end

  def test_entry_title_for_page_delete
    login_as_admin
    page = @project.pages.create(:name => 'new page')
    page.destroy
    assert_equal "Page new page deleted", feeds.entries.first.title
  end

  def test_entry_title_for_revision
    @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'xxx'})
    assert_equal 'xxx', feeds.entries.first.author.name
    assert_equal nil, feeds.entries.first.author.email
    assert_equal nil, feeds.entries.first.author.resource_link
    assert_equal "Revision revision_id committed", feeds.entries.first.title
  end

  def test_entry_title_for_revision_when_there_is_mingle_user_associated_with_it
    @member.update_attribute(:version_control_user_name, 'xxx')
    @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'xxx'})
    assert_equal @member, feeds.entries.first.author
    assert_equal "Revision revision_id committed", feeds.entries.first.title
  end

  def test_entry_author_should_be_who_created_event
    create_card!(:name => 'hello')
    assert_equal @member, feeds.entries.first.author
  end

  def test_current_page_should_point_to_tip_when_page_specified_is_bigger_than_actual_page_count
    assert_equal nil, feeds(@project, 11111).current_page
  end

  def test_pagination
    with_page_size(3) do
      7.times { create_card!(:name => 'hello') }

      last_page = feeds


      assert_equal 1, last_page.entries.size
      assert_equal nil, last_page.current_page
      assert_equal 2, last_page.previous_page
      assert_equal nil, last_page.next_page

      second_page = feeds(@project, '2')
      assert_equal 3, second_page.entries.size
      assert_equal 2, second_page.current_page
      assert_equal 1, second_page.previous_page
      assert_equal 3, second_page.next_page

      first_page = feeds(@project, '1')
      assert_equal 3, first_page.entries.size
      assert_equal 1, first_page.current_page
      assert_equal nil, first_page.previous_page
      assert_equal 2, first_page.next_page
    end
  end


  def test_entry_content_for_card_name_change
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'old name')
      card.update_attribute(:name, 'new name')

      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
       <changes xmlns="#{Mingle::API.ns}">
        <change type="name-change" mingle_timestamp="2015-11-09">
          <old_value>old name</old_value>
          <new_value>new name</new_value>
        </change>
      </changes>
      XML
    end
  end

  def test_entry_content_for_page_creation
    Timecop.freeze(2015, 11, 9) do
      @project.pages.create(:name => 'new page', :content => 'new desc')
      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="page-creation"/>
          <change type="description-change" mingle_timestamp="2015-11-09"></change>
          <change type="name-change" mingle_timestamp="2015-11-09">
            <old_value nil="true"></old_value>
            <new_value>new page</new_value>
          </change>
        </changes>
      XML
    end
  end

  def test_entry_content_for_page_deletion
    Timecop.freeze(2015, 11, 9) do
      login_as_admin
      page = @project.pages.create(:name => 'new page', :content => 'new desc')
      page.destroy
      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="page-deletion" mingle_timestamp="2015-11-09"> </change>
        </changes>
      XML
    end
  end


  def test_entry_content_for_revision
    Timecop.freeze(2015, 11, 9) do
      commit_time = Time.now.utc
      @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => commit_time, :commit_user => 'xxx'})
      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="revision-commit" mingle_timestamp="2015-11-09">
            <changeset>
              <user>xxx</user>
              <check_in_time type="datetime"> #{commit_time.xmlschema} </check_in_time>
              <revision> revision_id </revision>
              <message> fix a bug </message>
            </changeset>
          </change>
        </changes>
      XML
    end
  end

  def test_entry_categroies_should_include_source_type_and_all_change_types
    create_card!(:name => 'hello', :status => 'new', :iteration => '2', :description => 'new description')
    assert_equal ["card",
     "card-creation",
     "card-type-change",
     "description-change",
     "name-change",
     "property-change"], feeds.entries.first.categories
  end

  def test_source_link_for_card_entry
    card = create_card!(:name => 'hello')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml", feeds.entries.first.source_link.xml_href(view_helper, 'v2')
  end

  def test_source_link_for_deleted_card_entry
    card = create_card!(:name => 'hello')
    card.destroy
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml", feeds.entries.first.source_link.xml_href(view_helper, 'v2')
  end

  def test_source_link_for_page_entry
    page = @project.pages.create!(:name => 'hello')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/wiki/#{page.identifier}.xml", feeds.entries.first.source_link.xml_href(view_helper, 'v2')
  end

  def test_source_link_for_revision_entry
    @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'xxx'})
    assert_equal "http://example.com/projects/#{@project.identifier}/revisions/revision_id", feeds.entries.first.source_link.html_href(view_helper)
    assert_nil feeds.entries.first.source_link.xml_href(view_helper, 'v2')
  end

  def test_version_link_for_card_entry
    card = create_card!(:name => 'hello')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml?version=1", feeds.entries.first.version_link.xml_href(view_helper, 'v2')
  end

  def test_version_link_for_deleted_card_entry
    card = create_card!(:name => 'hello')
    card.destroy
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml?version=2", feeds.entries.first.version_link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml?version=1", feeds.entries.second.version_link.xml_href(view_helper, 'v2')
  end

  def test_source_link_for_page_entry
    page = @project.pages.create!(:name => 'hello')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/wiki/#{page.identifier}.xml?version=1", feeds.entries.first.version_link.xml_href(view_helper, 'v2')
  end

  def test_version_link_for_revision_entry_is_nil
    revision = @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'xxx'})
    assert_equal nil, feeds.entries.first.version_link
  end

  def test_related_cards_for_card_are_those_mentioned_in_the_card_comment
    card1 = create_card!(:name => 'card1')
    card2 = create_card!(:name => 'card2')
    card3 = create_card!(:name => 'card3')
    card3.add_comment :content => "this card is created for fixing stuff left from ##{card1.number} and ##{card2.number}. Be careful for ##{card2.number}"
    card3.save!
    assert_equal [card1, card2] , feeds.entries.first.related_cards
  end

  def test_related_cards_do_not_include_card_number_that_not_exist
    card = create_card!(:name => 'card')
    card.add_comment :content => "this card is created for fixing stuff left from #100000"
    assert_equal [] , feeds.entries.first.related_cards
  end

  def test_related_cards_for_non_comment_card_changes_is_empty
    card = create_card!(:name => 'card3')
    card.cp_status = 'closed'
    card.name = "new name"
    card.description = 'new desc'
    card.save!
    assert_equal [] , feeds.entries.first.related_cards
  end

  def test_related_cards_for_revisions_are_those_mentioned_in_the_message
    card1 = create_card!(:name => 'card1')
    card2 = create_card!(:name => 'card2')
    @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => "fix card #{card1.number}", :commit_time => Time.now.utc, :commit_user => 'xxx'})
    assert_equal [card1] , feeds.entries.first.related_cards
  end

  def test_should_be_able_to_see_entry_for_card_destroy
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'hello')
      card.cp_iteration = '1'
      card.save!
      card.destroy

      assert_equal 3, feeds.entries.size

      iteration_prop_def = @project.find_property_definition('iteration')

      assert_equal "Card ##{card.number} #{card.name} deleted", feeds.entries.first.title
      assert_equal "Card ##{card.number} #{card.name} changed", feeds.entries.second.title
      assert_equal "Card ##{card.number} #{card.name} created", feeds.entries.third.title

      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
         <changes xmlns="#{Mingle::API.ns}">
          <change type="card-deletion" mingle_timestamp="2015-11-09"> </change>
         </changes>
      XML

      assert_equal_ignoring_spaces <<-XML, feeds.entries.second.content_xml(view_helper)
         <changes xmlns="#{Mingle::API.ns}">
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{@project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>Iteration</name>
              <position nil="true"></position>
              <data_type>string</data_type>
              <is_numerictype="boolean">false</is_numeric>
            </property_definition>
            <old_value nil="true"> </old_value>
            <new_value>1</new_value>
          </change>
         </changes>
      XML

      assert_equal_ignoring_spaces <<-XML, feeds.entries.third.content_xml(view_helper)
         <changes xmlns="#{Mingle::API.ns}">
          <change type="card-creation" />
          <change type="card-type-change" mingle_timestamp="2015-11-09">
            <old_value nil="true"></old_value>
            <new_value>
              <card_type url="http://example.com/api/v2/projects/project_without_cards/card_types/#{@project.card_types.first.id}.xml">
                <name>card</name>
              </card_type>
            </new_value>
          </change>
          <change type="name-change" mingle_timestamp="2015-11-09">
            <old_value nil="true"></old_value>
            <new_value>hello</new_value>
          </change>
        </changes>
      XML
    end
  end

  def test_should_be_able_to_see_entry_for_card_bulk_destroy
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'hello')
      card.cp_iteration = '1'
      card.save!
      params = {:project_id => @project.identifier, :all_cards_selected=>"true"}
      view = CardListView.find_or_construct(@project, params)
      CardSelection.new(@project, view).destroy

      assert_equal 3, feeds.entries.size

      iteration_prop_def = @project.find_property_definition('iteration')

      assert_equal "Card ##{card.number} #{card.name} deleted", feeds.entries.first.title
      assert_equal "Card ##{card.number} #{card.name} changed", feeds.entries.second.title
      assert_equal "Card ##{card.number} #{card.name} created", feeds.entries.third.title

      assert_equal_ignoring_spaces <<-XML, feeds.entries.first.content_xml(view_helper)
         <changes xmlns="#{Mingle::API.ns}">
          <change type="card-deletion" mingle_timestamp="2015-11-09"> </change>
         </changes>
      XML

      assert_equal_ignoring_spaces <<-XML, feeds.entries.second.content_xml(view_helper)
         <changes xmlns="#{Mingle::API.ns}">
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{@project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>Iteration</name>
              <position nil="true"></position>
              <data_type>string</data_type>
              <is_numerictype="boolean">false</is_numeric>
            </property_definition>
            <old_value nil="true"> </old_value>
            <new_value>1</new_value>
          </change>
         </changes>
      XML

      assert_equal_ignoring_spaces <<-XML, feeds.entries.third.content_xml(view_helper)
         <changes xmlns="#{Mingle::API.ns}">
          <change type="card-creation" />
          <change type="card-type-change" mingle_timestamp="2015-11-09">
            <old_value nil="true"></old_value>
            <new_value>
              <card_type url="http://example.com/api/v2/projects/project_without_cards/card_types/#{@project.card_types.first.id}.xml">
                <name>card</name>
              </card_type>
            </new_value>
          </change>
          <change type="name-change" mingle_timestamp="2015-11-09">
            <old_value nil="true"></old_value>
            <new_value>hello</new_value>
          </change>
        </changes>
      XML
    end
  end


  def test_should_generate_property_value_changed_entry_when_property_value_changed
    Timecop.freeze(2015, 11, 9) do
      with_new_project do |project|
        view_helper.default_url_options = view_helper.default_url_options.merge(:project_id => project.identifier)
        setup_property_definitions :estimation => ['foo']
        estimation = project.find_property_definition("estimation")
        one = estimation.values.first
        one.update_attribute(:value, 'bar')
        assert_equal 1, feeds(project).logical_count
        entry = feeds(project).entries.first
        assert_equal "Property definition changed", entry.title
        assert_equal "http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{estimation.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
        assert_nil entry.version_link
        assert_equal [], entry.related_cards
        assert_equal ["feed-correction", 'property-change'], entry.categories

        assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
          <changes xmlns="#{Mingle::API.ns}">
            <change type="managed-property-value-change" mingle_timestamp="2015-11-09">
              <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{estimation.id}.xml" />
              <old_value>foo</old_value>
              <new_value>bar</new_value>
            </change>
          </changes>
        XML
      end
    end
  end

  def test_should_generate_entry_for_property_definition_rename
    Timecop.freeze(2015, 11, 9) do
      with_new_project do |project|
        view_helper.default_url_options = view_helper.default_url_options.merge(:project_id => project.identifier)
        setup_property_definitions :estimation => ['foo']
        estimation = project.find_property_definition("estimation")
        estimation.update_attribute(:name, 'est')
        entry = feeds(project).entries.first
        assert_equal "Property definition changed", entry.title
        assert_equal "http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{estimation.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
        assert_nil entry.version_link
        assert_equal ["feed-correction", 'property-change'], entry.categories

        assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
          <changes xmlns="#{Mingle::API.ns}">
            <change type="property-rename" mingle_timestamp="2015-11-09">
              <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{estimation.id}.xml" />
              <old_value>estimation</old_value>
              <new_value>est</new_value>
            </change>
          </changes>
        XML
      end
    end
  end

  def test_should_generate_entry_for_property_definition_deletion
    Timecop.freeze(2015, 11, 9) do
      with_new_project do |project|
        view_helper.default_url_options = view_helper.default_url_options.merge(:project_id => project.identifier)
        setup_property_definitions :estimation => ['foo']
        estimation = project.find_property_definition("estimation")
        estimation.destroy
        entry = feeds(project).entries.first
        assert_equal "Property definition changed", entry.title
        assert_equal "http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{estimation.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
        assert_nil entry.version_link
        assert_equal ["feed-correction", 'property-deletion'], entry.categories

        assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
          <changes xmlns="#{Mingle::API.ns}">
            <change type="property-deletion" mingle_timestamp="2015-11-09">
              <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{estimation.id}.xml" />
            </change>
          </changes>
        XML
      end
    end
  end

  def test_should_generate_entry_for_property_definition_formula_changes
    Timecop.freeze(2015, 11, 9) do
      with_new_project do |project|
        view_helper.default_url_options = view_helper.default_url_options.merge(:project_id => project.identifier)
        one_third = setup_formula_property_definition('one third', '1/3')
        one_third.update_attributes(:name => "two third", :formula => "2/3")
        project.reload.events.each(&:generate_changes)
        entry = feeds(project).entries.first
        assert_equal "Property definition changed", entry.title
        assert_equal "http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{one_third.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
        assert_nil entry.version_link
        assert_equal ["feed-correction", 'property-change'], entry.categories

        assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
          <changes xmlns="#{Mingle::API.ns}">
            <change type="property-rename" mingle_timestamp="2015-11-09">
              <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{one_third.id}.xml"/>
              <old_value>one third</old_value>
              <new_value>two third</new_value>
            </change>
          </changes>
        XML
      end
    end
  end

  def test_should_generate_entry_for_card_type_property_definition_disassociation
    Timecop.freeze(2015, 11, 9) do
      card_type = @project.card_types.first
      iteration = @project.find_property_definition("iteration")
      card_type.property_definitions = card_type.property_definitions - [iteration]
      card_type.save

      entry = feeds(@project).entries.first
      assert_equal "Card type changed", entry.title
      assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
      assert_nil entry.version_link
      assert_equal ["feed-correction", 'card-type-change', 'property-change'], entry.categories
      assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="card-type-and-property-disassociation" mingle_timestamp="2015-11-09">
            <card_type url="http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml" />
            <property_definition url="http://example.com/api/v2/projects/#{@project.identifier}/property_definitions/#{iteration.id}.xml" />
          </change>
        </changes>
      XML
    end
  end

  def test_should_generate_entry_for_card_type_rename
    Timecop.freeze(2015, 11, 9) do
      card_type = @project.card_types.first
      card_type.update_attribute(:name, 'foo')
      entry = feeds(@project).entries.first
      assert_equal "Card type changed", entry.title
      assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
      assert_nil entry.version_link
      assert_equal ["feed-correction", 'card-type-change'], entry.categories
      assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="card-type-rename" mingle_timestamp="2015-11-09">
            <card_type url="http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml" />
            <old_value> card </old_value>
            <new_value> foo </new_value>
          </change>
        </changes>
      XML
    end
  end

  def test_should_generate_entry_for_card_type_deletion
    Timecop.freeze(2015, 11, 9) do
      card_type = @project.card_types.first
      card_type.destroy
      entry = feeds(@project).entries.first
      assert_equal "Card type changed", entry.title
      assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml", entry.source_link.xml_href(view_helper, 'v2')
      assert_nil entry.version_link
      assert_equal ["feed-correction", 'card-type-deletion'], entry.categories
      assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="card-type-deletion" mingle_timestamp="2015-11-09">
            <card_type url="http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml" />
          </change>
        </changes>
      XML
    end
  end

  def test_should_generate_entry_for_tag_rename
    Timecop.freeze(2015, 11, 9) do
      tag = @project.tags.create!(:name => 'foo')
      tag.update_attribute(:name, 'bar')
      entry = feeds(@project).entries.first
      assert_equal "Tag changed", entry.title
      assert_equal nil, entry.source_link.xml_href(view_helper, 'v2')
      assert_equal nil, entry.source_link.html_href(view_helper)
      assert_equal ["feed-correction", 'tag-change'], entry.categories
      assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="tag-rename" mingle_timestamp="2015-11-09">
            <old_value> foo </old_value>
            <new_value> bar </new_value>
          </change>
        </changes>
      XML
    end
  end

  def test_should_generate_entry_for_project_change
    Timecop.freeze(2015, 11, 9) do
      @project.update_attributes(:card_keywords => 'pandaslikebanana', :precision => '3')
      entry = feeds(@project).entries.first
      assert_equal "Project changed", entry.title
      assert_equal 'http://example.com/api/v2/projects/project_without_cards.xml', entry.source_link.xml_href(view_helper, 'v2')
      assert_equal ["feed-correction", 'project-change'], entry.categories
      assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="card-keywords-change" mingle_timestamp="2015-11-09">
            <project url="http://example.com/api/v2/projects/project_without_cards.xml" />
            <old_value>card, #</old_value>
            <new_value>pandaslikebanana</new_value>
          </change>

          <change type="numeric-precision-change" mingle_timestamp="2015-11-09">
            <project url="http://example.com/api/v2/projects/project_without_cards.xml" />
            <old_value>2</old_value>
            <new_value>3</new_value>
          </change>

        </changes>
      XML
    end
  end

  def test_should_generate_entry_when_repo_get_deleted
    Timecop.freeze(2015, 11, 9) do
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

        entry = feeds(@project).entries.first
        assert_equal "Project changed", entry.title
        assert_equal "Mingle System", entry.author.name
        assert_equal 'http://example.com/api/v2/projects/project_without_cards.xml', entry.source_link.xml_href(view_helper, 'v2')
        assert_equal ["feed-correction", 'repository-settings-change'], entry.categories
        assert_equal_ignoring_spaces <<-XML, entry.content_xml(view_helper)
          <changes xmlns="#{Mingle::API.ns}">
            <change type="repository-settings-change" mingle_timestamp="2015-11-09">
              <project url="http://example.com/api/v2/projects/project_without_cards.xml" />
            </change>
          </changes>
        XML
      end
    end
  end

  def test_entry_for_objective_added_to_plan
    login_as_admin
    program = create_program
    program.plan
    program.objectives.planned.create!(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')

    Timecop.freeze(2015, 11, 9) do
      program.events.find_each do |v|
        Event.set_event_timestamp(v, Time.now)
      end
    end
    assert_equal_ignoring_spaces <<-XML, Feeds.new(program).entries.first.content_xml(view_helper)
      <changes xmlns="#{Mingle::API.ns}">
        <change type="objective-planned"/>
        <change type="end_at-change" mingle_timestamp="2015-11-09">
          <old_value nil="true"></old_value>
          <new_value>2011-02-01</new_value>
        </change>
        <change type="name-change" mingle_timestamp="2015-11-09">
          <old_value nil="true"></old_value>
          <new_value>first objective</new_value>
        </change>
        <change type="start_at-change" mingle_timestamp="2015-11-09">
          <old_value nil="true"></old_value>
          <new_value>2011-01-01</new_value>
        </change>
      </changes>
    XML
  end

  def test_entry_for_objective_removed_from_plan
    Timecop.freeze(2015, 11, 9) do
      login_as_admin
      program = program('simple_program')
      plan = program.plan
      objective = program.objectives.planned.create!(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
      objective.destroy

      Timecop.freeze(2015, 11, 9) do
        program.events.find_each do |v|
          Event.set_event_timestamp(v, Time.now)
        end
      end

      assert_equal_ignoring_spaces <<-XML, Feeds.new(program).entries.first.content_xml(view_helper)
        <changes xmlns="#{Mingle::API.ns}">
          <change type="objective-removed" mingle_timestamp="2015-11-09">
          </change>
        </changes>
      XML
    end
  end

  def test_title_for_program_feeds
    login_as_admin
    program = program('simple_program')
    feed = Feeds.new(program)
    assert_equal "Mingle Plan Events for Program: #{program.name}", feed.title
  end

  def test_feed_for_card_copy
    source_project = create_project(:name => "project 1")
    dest_project = create_project(:name => "project 2")

    source_project.activate
    source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
    dest = source.copier(dest_project).copy_to_target_project

    entry = Feeds.new(source_project).entries.first
    assert_false entry.categories.include?("card-creation")
    assert_equal "Card ##{source.number} copied to #{dest_project.identifier}/##{dest.number}", entry.title

    dest_project.activate
    entry = Feeds.new(dest_project).entries.first
    assert_false entry.categories.include?("card-creation")
    assert_equal "Card ##{dest.number} copied from #{source_project.identifier}/##{source.number}", entry.title
  end

  def test_feed_entry_title_for_deleted_card_copy_entry
    source_project = create_project(:name => "project 1")
    dest_project = create_project(:name => "project 2")

    source_project.activate
    source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
    dest = source.copier(dest_project).copy_to_target_project
    dest_project.activate
    dest.destroy

    feed_entries = Feeds.new(dest_project).entries

    entry = feed_entries[1]
    assert_equal "Deleted card copied from #{source_project.identifier}/##{source.number}", entry.title
  end

  def test_source_link_for_deleted_card_copy_entry
    source_project = create_project(:name => "project 1")
    dest_project = create_project(:name => "project 2")

    source_project.activate
    source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
    dest = source.copier(dest_project).copy_to_target_project
    dest_project.activate
    dest.destroy

    feed_entries = Feeds.new(dest_project).entries

    entry = feed_entries[1]
    assert_nil entry.source_link
  end

  # for data from old version of mingle, where when user delete
  # a card we have chances delete page versions while leaving page event undeleted
  def test_creates_a_feed_entry_for_pages_with_missing_versions
    page = @project.pages.create(:name => 'new page')
    Page.connection.execute("DELETE FROM #{Page::Version.quoted_table_name} WHERE page_id = #{page.id} AND project_id = #{@project.id}")
    assert_equal 1, feeds.entries.count
    entry = feeds.entries.first
    assert_equal "Deleted page", feeds.entries.first.title
    assert_nil entry.source_link
    assert_nil entry.version_link
  end

  # for data from old version of mingle, where when user delete
  # a card we have chances delete card versions while leaving card event undeleted
  def test_creates_a_feed_entry_for_pages_with_missing_versions
    card = create_card!(:name => 'foo')
    Card.connection.execute("DELETE FROM #{Card::Version.quoted_table_name} WHERE card_id = #{card.id}")
    assert_equal 1, feeds.entries.count
    entry = feeds.entries.first
    assert_equal "Deleted card changed", entry.title
    assert_nil entry.source_link
    assert_nil entry.version_link
  end

  def test_entry_for_card_creation_after_a_card_used_same_number_deleted
    card = create_card!(:name => 'hello')
    number = card.number
    card.delete
    card = create_card!(:number => number, :name => 'world')

    assert_equal "Card ##{card.number} world created", feeds.entries.first.title
    assert_equal "http://example.com/api/v2/projects/project_without_cards/cards/1.xml?id=#{card.id}", feeds.entries.first.source_link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/project_without_cards/cards/1?id=#{card.id}", feeds.entries.first.source_link.html_href(view_helper)
  end

  private

  def project_event_count(project)
    Event.count(:conditions => "project_id = #{project.id}")
  end

  def feeds(project=@project, page=nil)
    Feeds.new(project, page)
  end

  def xml_builder
    Builder::XmlMarkup.new
  end
end
