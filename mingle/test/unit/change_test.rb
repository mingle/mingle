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
class ChangeTest < ActiveSupport::TestCase
  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end

  def test_revision_change
    commit_time = Time.now.utc
    revision = @project.revisions.create!(
            :number => '42',
            :identifier => '42',
            :commit_message => "a wonderful checkin",
            :commit_time => commit_time,
            :commit_user => 'fred')

    revision.reload
    revision.event.send(:generate_changes)
    revision.reload
    assert_equal revision, revision.event.origin
    assert_equal "Revision 42 committed by fred at #{commit_time}. a wonderful checkin", revision.describe_changes.first
  end

  def test_should_display_correctly_when_revisions_are_created_but_project_repository_configuration_no_longer_exist
    assert_equal false, @project.has_source_repository?
    revision = @project.revisions.create!(
            :number => '42',
            :identifier => '42',
            :commit_message => "a wonderful checkin",
            :commit_time => Time.now.utc,
            :commit_user => 'fred')
    assert_equal 'Revision 42', revision.name
    assert_equal 'Revision 42', revision.short_name
    assert_equal 'Revision 42 committed by fred', revision.description
    assert_equal '42', revision.short_identifier
  end

  def test_commit_message_truncated_to_255_chars_when_generating_changes
    message = "#1992, added card_type into Card and Card::Version, added card_types table and migration, made card_type displayed on card show page, update card type on card show page, added CardTypeChange for generating changes; refactored card creation in test to assign first card_types in project to card, made first card_types in project as default card_type when creating card or importing cards"
    rev = Revision.create!(:commit_time => Time.new, :commit_user => 'dave',
      :project => @project, :number => 23, :identifier => '23', :commit_message => message)
    rev.reload.generate_changes
    assert rev.event.reload.changes.first.describe.ends_with?(message[0..254]), "Expected change description to end with the truncated version of the message."
  end

  def test_should_create_changes_for_name_and_card_type_after_card_created
    create_card!(:name => 'my first card', :card_type => first_card_type)
    first_version = first_card.versions.first.reload
    reload_generate_changes_version(first_version)
    assert_equal 2, first_version.event.changes.size
    assert_equal NameChange, first_version.event.changes.sort_by(&:id).first.class
    assert_equal CardTypeChange, first_version.event.changes.sort_by(&:id).last.class
  end

  def test_should_create_single_change_on_modifying_card_name
    create_card!(:name => 'my first card', :card_type => first_card_type)

    @project.cards.first.update_attribute(:name, 'a new name')
    @project.cards.first.update_attribute(:name, 'another new name')

    assert_equal 3, first_card.reload.versions.size
    version(2..3) do |version|
          reload_generate_changes_version(version)
      assert_equal 1, version.changes.size
      assert_equal NameChange, version.changes.first.class
    end
  end

  def test_should_create_description_change_when_modifying_description
   create_card!(:name => 'my first card', :description => 'nothing')
    first_card.update_attribute(:description, 'still nothing')
    assert_equal 1, reload_generate_changes_version(version(2)).changes.size
  end

  def test_should_create_property_change_event_on_create_or_update
    create_card!(:name => 'my first card', :status => 'new', :priority => 'high', :card_type => @project.card_types.first)
    first_card.update_attribute(:cp_status, 'in progress')
    first_card.update_attribute(:cp_status, 'fixed')
    first_card.update_attribute(:cp_status, 'closed')

    assert_equal 4, first_card.reload.versions.size
    assert_equal 4, reload_generate_changes_version(version(1)).changes.size
    version(2..4) do |version|
      assert_equal 1, reload_generate_changes_version(version).changes.size
    end
  end

  def test_tagging_generates_tag_addition_and_deletion_changes
   create_card!(:name => 'my first card')
    first_card.tag_with('rss,history').save!
    last_version = reload_generate_changes_version(first_card.versions.last)

    assert_equal 2, last_version.changes.size
    assert [TagAdditionChange, TagAdditionChange].contains_all?(last_version.changes.collect(&:class))
    assert ['rss', 'history'].collect { |tag| @project.tag_named(tag) }.contains_all?(last_version.changes.collect(&:tag))
    first_card.tag_with('rss,atom').save!

    last_version = reload_generate_changes_version(first_card.reload.versions.last)
    assert_equal 2, last_version.changes.size
    assert [TagAdditionChange, TagDeletionChange].contains_all?(last_version.changes.collect(&:class))
    assert ['atom', 'history'].contains_all?(last_version.changes.collect(&:tag).collect(&:name))
  end

  def test_should_create_attachment_event
   create_card!(:name => 'my first card')
    first_card.attach_files(sample_attachment("1.gif"))
    first_card.save!
    assert_equal 2, first_card.versions.size
    assert_equal 1, reload_generate_changes_version(version(2)).changes.size
    assert_equal first_card.attachments.first, version(2).changes.first.attachment
  end

  def test_should_create_attachment_event_when_attachments_are_replaced_on_a_card
    create_card!(:name => 'my first card')
     first_card.attach_files(sample_attachment("1.gif"))
     first_card.save!

     first_card.attach_files(sample_attachment("1.gif"))
     first_card.save!

     assert_equal 3, first_card.versions.size
     assert_equal 1, reload_generate_changes_version(version(3)).changes.size
  end

  def test_should_create_attachment_event_when_attachments_are_replaced_on_a_page
    @project.pages.create!(:name => 'first page', :identifier => 'first_page')
    first_page = @project.pages.find_by_name('first page')

    first_page.attach_files(sample_attachment("1.gif"))
    first_page.save!

    first_page.attach_files(sample_attachment("1.gif"))
    first_page.save!

    assert_equal 3, first_page.reload.versions.size
    assert_equal 1, reload_generate_changes_version(first_page.versions.last).changes.size
    assert_equal "Attachment replaced 1.gif", first_page.versions.last.describe_changes.first
  end

  def test_should_create_changes_for_name_and_card_type_and_attachment
    create_card!(:name => 'my first card', :attachments => ["1.gif"])

    assert_equal 1, first_card.versions.size
    assert_equal 3, reload_generate_changes_version(version(1)).changes.size
  end

  def test_page_changes_work_similar_to_card_changes
    @project.pages.create!(:name => 'first page', :identifier => 'first_page')
    @project.pages.first.update_attribute(:content, 'more description')
    @project.pages.first.tag_with('discussions,feature').save!
    @project.pages.first.attach_files(sample_attachment("1.gif"))
    @project.pages.first.save!

    assert_equal 4, @project.pages.first.reload.versions.size
    first_page = @project.pages.first
    assert_equal 1, reload_generate_changes_version(first_page.find_version(1)).changes.size
    assert_equal 1, reload_generate_changes_version(first_page.find_version(2)).changes.size
    assert_equal 2, reload_generate_changes_version(first_page.find_version(3)).changes.size
    assert_equal 1, reload_generate_changes_version(first_page.find_version(4)).changes.size
  end

  def test_descriptions_of_first_version
    create_card!(:name => 'my first card', :status => 'open', :old_type => 'story', :priority => 'high')

    descriptions = reload_generate_changes_version(first_card.versions[0]).describe_changes
    assert descriptions.contains_all?(["Priority set to high", "Status set to open", "old_type set to story"])
  end

  def test_should_trace_changes_to_user_properties_similar_to_enumerated_properties
    first = User.find_by_login('first')
    bob = User.find_by_login('bob')

    @project.add_member(bob)
    @project.reload

    card = create_card!(:name => 'a card', :dev => first.id, :card_type => @project.card_types.first)
    card.cp_dev = bob
    card.save!

    assert_equal 2, card.reload.versions.size
    assert_equal 3, reload_generate_changes_version(version(1)).changes.size
    assert_equal 1, reload_generate_changes_version(version(2)).changes.size
    assert_equal "dev changed from #{first.name} to #{bob.name}", version(2).describe_changes.first
  end

  def test_should_create_a_change_for_comments
    card =create_card!(:name => 'story')
    card.add_comment :content => "Here is a comment for you"

    assert 1, reload_generate_changes_version(version(2)).changes.size
    assert_equal "Comment added: Here is a comment for you", version(2).describe_changes.first
  end

  def test_can_describe_a_change_for_a_hidden_property
    card = create_card!(:name => 'a card', :status => 'new')
    @project.find_property_definition('Status').update_attribute(:hidden, true)

    @project.reload
    assert_equal 'Status set to new', reload_generate_changes_version(@project.cards.find(:all).first.versions[0]).event_changes.find_by_field('Status').describe
  end

  def test_persisted_date_values_in_changes_table_are_y2k_compliant
    card = create_card! :name => 'foo', :startdate => '03 Feb 1945'
    card.cp_startdate = '04 Feb 1945 00:00:00'
    card.save!
    version = reload_generate_changes_version(card.versions.last)
    assert_equal '1945-02-04', version.event_changes.find_by_field('startdate').new_value
    assert_equal '1945-02-03', version.event_changes.find_by_field('startdate').old_value
  end

  def test_card_property_definition_change_should_have_correct_description_for_changes_to_card_history
    with_card_prop_def_test_project_and_card_type_and_pd do |project, story_type, iteration_type, iteration_propdef|
      iteration1 = project.cards.create!(:name => 'iteration1', :card_type => iteration_type)
      story1 = project.cards.create!(:name => 'story1', :card_type => story_type)
      story1.update_attributes(:cp_iteration => iteration1)

      description = reload_generate_changes_version(story1.versions[1]).describe_changes.first
      assert_equal "iteration set to ##{iteration1.number} iteration1", description
    end
  end

  def test_change_table_should_be_updated_when_the_card_type_name_was_changed
    first_card_type = @project.card_types.first
    defect = @project.card_types.create(:name => 'Defect')
    card = create_card!(:name => 'I am a defect', :card_type => defect)

    card.update_attribute(:card_type_name, first_card_type.name)

    # card_type_name change from nil to defect
    assert_equal 'Defect', reload_generate_changes_version(card.versions[0]).changes.sort_by(&:id)[1].new_value
    # card_type_name change from defect to first_card_type
    assert_equal 'Defect', reload_generate_changes_version(card.versions[1]).changes.sort_by(&:id)[0].old_value

    defect.update_attribute(:name, 'Bug')
    card.reload

    # card_type_name change from nil to defect
    assert_equal 'Bug', reload_generate_changes_version(card.versions[0]).changes.sort_by(&:id)[1].new_value
    # card_type_name change from defect to first_card_type
    assert_equal 'Bug', reload_generate_changes_version(card.versions[1]).changes.sort_by(&:id)[0].old_value
  end

  def test_update_enumeration_value_does_not_update_changes_for_other_projects
    project_foo = with_new_project do |project|
      setup_property_definitions :age => ['new', 'open']
      create_card!(:name => 'card foo', :age => 'new')
    end

    project_bar = with_new_project do |project|
      setup_property_definitions :age => ['new', 'open']
      create_card!(:name => 'card bar', :age => 'new')
    end

    project_foo.with_active_project do |project|
      project.find_enumeration_value('age', 'new').update_attribute(:value, 'brand new')
      card_foo = project.cards.find_by_name('card foo')
      assert_equal 'brand new', reload_generate_changes_version(card_foo.versions[0]).changes.detect{|c| c.field == 'age'}.new_value
    end

    project_bar.with_active_project do |project|
      card_bar = project.cards.find_by_name('card bar')
      assert_equal 'new', reload_generate_changes_version(card_bar.versions[0]).changes.detect{|c| c.field == 'age'}.new_value
    end
  end

  def test_update_enumeration_value_updates_cards_and_versions_and_changes
    with_new_project do |project|
      setup_property_definitions :age => ['neux', 'open']
      card1 = create_card!(:name => 'first card', :age => 'neux')
      card1.update_attribute :cp_age, 'open'
      assert_equal 'neux', card1.reload.versions[0].cp_age

      project.find_enumeration_value('age', 'neux').update_attribute(:value, 'new')

      assert_equal 'new', project.reload.find_enumeration_value('age', 'new').value

      assert_equal 'open', card1.reload.cp_age

      version_1 = reload_generate_changes_version card1.versions[0]
      assert_equal 'new', version_1.cp_age
      assert_equal 'new', version_1.changes.detect{|c| c.field == 'age'}.new_value

      version_2 = reload_generate_changes_version card1.versions[1]
      assert_equal 'open', version_2.cp_age
      assert_equal 'new', version_2.changes.detect{|c| c.field == 'age'}.old_value
      assert_equal 'open', version_2.changes.detect{|c| c.field == 'age'}.new_value
    end
  end

  #bug #4998 Version information is broken when a tree/card relationship card in the version is deleted
  def test_should_show_deleted_card_property_message_when_card_is_deleted
    with_card_query_project do |project|
      card_one = project.cards.create!(:name => 'card one', :card_type_name => 'Card')
      card_related = project.cards.create!(:name => 'card related', :card_type_name => 'Card')
      prop = project.find_property_definition('related card')

      card_one.update_properties('related card' => card_related.id)
      card_one.save
      card_related.destroy
      versions = card_one.reload.versions
      assert 'related card changed from deleted card to (not set)', reload_generate_changes_version(versions.last).changes.first.describe
    end
  end

  def test_to_xml_for_card_copy_to_changes
    Timecop.freeze(2015, 11, 9) do
      source_project = create_project(:name => "project 1")
      dest_project = create_project(:name => "project 2")

      source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
      dest = source.copier(dest_project).copy_to_target_project

      expected = <<-XML
        <change type="card-copied-to" mingle_timestamp="2015-11-09">
          <source url="http://example.com/api/v2/projects/#{source_project.identifier}/cards/#{source.number}.xml"/>
          <destination url="http://example.com/api/v2/projects/#{dest_project.identifier}/cards/#{dest.number}.xml"/>
        </change>
      XML

      event = source_project.reload.events.last
      event.send :generate_changes
      change = event.changes.first
      assert_equal_ignoring_spaces expected, xml_for(change)
    end
  end

  def test_to_xml_for_card_copy_to_changes_for_card_deleted_in_source_project
    Timecop.freeze(2015, 11, 9) do
      source_project = create_project(:name => "project 1")
      dest_project = create_project(:name => "project 2")

      source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
      dest = source.copier(dest_project).copy_to_target_project
      source.destroy

      expected = <<-XML
        <change type="card-copied-to" mingle_timestamp="2015-11-09">
          <source deleted="true" url=""/>
          <destination url="http://example.com/api/v2/projects/#{dest_project.identifier}/cards/#{dest.number}.xml"/>
        </change>
      XML

      event = source_project.reload.events.last
      event.send :generate_changes
      change = event.changes.first
      assert_equal_ignoring_spaces expected, xml_for(change)
    end
  end

  def test_to_xml_for_card_copy_from_changes
    Timecop.freeze(2015, 11, 9) do
      source_project = create_project(:name => "project 1")
      dest_project = create_project(:name => "project 2")

      source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
      dest = source.copier(dest_project).copy_to_target_project

      expected = <<-XML
        <change type="card-copied-from" mingle_timestamp="2015-11-09">
          <source url="http://example.com/api/v2/projects/#{source_project.identifier}/cards/#{source.number}.xml"/>
          <destination url="http://example.com/api/v2/projects/#{dest_project.identifier}/cards/#{dest.number}.xml"/>
        </change>
      XML

      event = dest_project.reload.events.find_by_type("CardCopyEvent::From")
      event.send :generate_changes
      change = event.changes.first
      assert_equal 1, event.changes.count
      assert_equal_ignoring_spaces expected, xml_for(change)
    end
  end

  def test_to_xml_for_card_copy_from_changes_for_card_deleted_in_destination_project
    Timecop.freeze(2015, 11, 9) do
      source_project = create_project(:name => "project 1")
      dest_project = create_project(:name => "project 2")

      source = source_project.cards.create! :name => 'card', :card_type_name => source_project.card_types.first.name
      dest = source.copier(dest_project).copy_to_target_project
      dest.destroy

      expected = <<-XML
        <change type="card-copied-from" mingle_timestamp="2015-11-09">
          <source url="http://example.com/api/v2/projects/#{source_project.identifier}/cards/#{source.number}.xml"/>
          <destination deleted="true" url=""/>
        </change>
      XML

      event = dest_project.reload.events.find_by_type("CardCopyEvent::From")
      event.send :generate_changes
      change = event.changes.first
      assert_equal 1, event.changes.count
      assert_equal_ignoring_spaces expected, xml_for(change)
    end
  end

  def test_to_xml_for_card_name_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'old name')
      card.update_attribute(:name, 'a new name')

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="name-change" mingle_timestamp="2015-11-09">
          <old_value>old name</old_value>
          <new_value>a new name</new_value>
        </change>
      XML
    end
  end

  def test_to_xml_for_card_description_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'hello', :description => 'old desc')
      card.update_attribute(:description, 'new desc')

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="description-change" mingle_timestamp="2015-11-09"> </change>
      XML
    end
  end

  def test_to_xml_for_card_type_changes
    Timecop.freeze(2015, 11, 9) do
      with_card_prop_def_test_project do |project|
        story = project.find_card_type("story")
        iteration = project.find_card_type("iteration")


        card = create_card!(:name => 'hello', :card_type => story)
        card.update_attribute(:card_type, iteration)

        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
          <change type="card-type-change" mingle_timestamp="2015-11-09">
            <old_value>
              <card_type url="http://example.com/api/v2/projects/card_prop_def_test_project/card_types/#{story.id}.xml">
                <name>story</name>
              </card_type>
            </old_value>
            <new_value>
              <card_type url="http://example.com/api/v2/projects/card_prop_def_test_project/card_types/#{iteration.id}.xml">
                <name>iteration</name>
              </card_type>
            </new_value>
          </change>
        XML
      end
    end
  end

  def test_to_xml_for_card_type_changes_with_deleted_card_type
    Timecop.freeze(2015, 11, 9) do
      with_card_prop_def_test_project do |project|
        story = project.find_card_type("story")
        iteration = project.find_card_type("iteration")
        card = create_card!(:name => 'hello', :card_type => story)
        card.update_attribute(:card_type, iteration)

        assert iteration.destroy
        project.reload
        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
          <change type="card-type-change" mingle_timestamp="2015-11-09">
            <old_value>
              <card_type url="http://example.com/api/v2/projects/card_prop_def_test_project/card_types/#{story.id}.xml">
                <name>story</name>
              </card_type>
            </old_value>
            <new_value>
              <deleted_card_type>
                <name>iteration</name>
              </deleted_card_type>
            </new_value>
          </change>
        XML
      end
    end
  end


  def test_to_xml_for_tag_addition_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'first card')
      card.tag_with('foo')
      card.save!

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="tag-addition" mingle_timestamp="2015-11-09">
          <tag>foo</tag>
        </change>
      XML
    end
  end

  def test_to_xml_for_tag_remove_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'first card')
      card.tag_with('foo')
      card.save!

      card.remove_tag('foo')
      card.save!

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="tag-removal" mingle_timestamp="2015-11-09">
          <tag>foo</tag>
        </change>
      XML
    end
  end

  def test_to_xml_for_attachment_addition_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'my first card')
      card.attach_files(sample_attachment("1.gif"))
      card.save!
      attachment = card.attachments.first

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="attachment-addition" mingle_timestamp="2015-11-09">
          <attachment>
            <url>#{attachment.url}</url>
            <file_name>1.gif</file_name>
          </attachment>
        </change>
      XML
    end
  end

  def test_to_xml_for_attachment_remove_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'my first card')
      card.attach_files(sample_attachment("1.gif"))
      card.save!
      attachment = card.attachments.first

      card.remove_attachment(attachment.file_name)
      card.save!

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="attachment-removal" mingle_timestamp="2015-11-09">
          <attachment>
            <url>#{attachment.url}</url>
            <file_name>1.gif</file_name>
          </attachment>
        </change>
      XML
    end
  end


  def test_to_xml_for_attachment_replacing_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'my first card')
      card.attach_files(sample_attachment("1.gif"))
      card.save!

      card.attach_files(sample_attachment("1.gif"))
      card.save!

      new_attachment = card.attachments.first

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="attachment-replacement" mingle_timestamp="2015-11-09">
          <attachment>
            <url>#{new_attachment.url}</url>
            <file_name>1.gif</file_name>
          </attachment>
        </change>
      XML
    end
  end

  def test_to_xml_for_comment_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'my first card')
      card.add_comment(:content => "aha")
      card.save!

      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="comment-addition" mingle_timestamp="2015-11-09">
          <comment> aha </comment>
        </change>
      XML
    end
  end


  def test_to_xml_for_enumrated_property_changes
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'my first card', :status => 'new')
      card.cp_status = "close"
      card.save!
      status = @project.find_property_definition("status")
      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="property-change" mingle_timestamp="2015-11-09">
          <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{status.id}.xml" >
            <name>status</name>
            <position nil="true"></position>
            <data_type>string</data_type>
            <is_numeric type="boolean">false</is_numeric>
          </property_definition>

          <old_value>new</old_value>
          <new_value>close</new_value>
        </change>
      XML
    end
  end

  def test_to_xml_for_date_property_change
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'my first card', :status => 'new')
      old_startdate = Time.now
      card.cp_startdate = old_startdate
      card.save!
      new_startdate = 2.days.ago
      card.cp_startdate = new_startdate
      card.save!

      startdate = @project.find_property_definition("startdate")
      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="property-change" mingle_timestamp="2015-11-09">
          <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{startdate.id}.xml" >
            <name>startdate</name>
            <position nil="true"></position>
            <data_type>date</data_type>
            <is_numeric type="boolean">false</is_numeric>
          </property_definition>

          <old_value type="date">#{old_startdate.to_date.to_s(:db)}</old_value>
          <new_value type="date">#{new_startdate.to_date.to_s(:db)}</new_value>
        </change>
      XML
    end
  end

  def test_to_xml_for_user_property_changes
    Timecop.freeze(2015, 11, 9) do
      member = User.find_by_login("member")
      first = User.find_by_login("first")

      card = create_card!(:name => 'my first card')
      card.cp_dev = first
      card.save!

      card.cp_dev = member
      card.save!
      dev = @project.find_property_definition("dev")
      assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(card))
        <change type="property-change" mingle_timestamp="2015-11-09">
          <property_definition url="http://example.com/api/v2/projects/project_without_cards/property_definitions/#{dev.id}.xml" >
            <name>dev</name>
            <position nil="true"></position>
            <data_type>user</data_type>
            <is_numeric type="boolean">false</is_numeric>
          </property_definition>

          <old_value>
            <user url="http://example.com/api/v2/users/#{first.id}.xml">
              <name>first@email.com</name>
              <login>first</login>
            </user>
          </old_value>

          <new_value>
            <user url="http://example.com/api/v2/users/#{member.id}.xml">
              <name>member@email.com</name>
              <login>member</login>
            </user>
          </new_value>

        </change>
      XML
    end
  end

  def test_to_xml_for_card_property_changes
    Timecop.freeze(2015, 11, 9) do
      with_card_prop_def_test_project do |project|
        iteration1 = create_card!(:name => "iteration1", :card_type_name => 'iteration')
        iteration2 = create_card!(:name => "iteration2", :card_type_name => 'iteration')
        story = create_card!(:name => 'email', :card_type_name => 'story')
        story.cp_iteration = iteration1
        story.save!

        story.cp_iteration = iteration2
        story.save!

        iteration_prop_def = project.find_property_definition("iteration")
        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(story))
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>iteration</name>
              <position nil="true"></position>
              <data_type>card</data_type>
              <is_numeric type="boolean">false</is_numeric>
            </property_definition>

            <old_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration1.number}.xml">
                <number type="integer"> #{iteration1.number} </number>
              </card>
            </old_value>

            <new_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration2.number}.xml">
                <number type="integer"> #{iteration2.number} </number>
              </card>
            </new_value>

          </change>
        XML
      end
    end
  end

  def test_to_xml_for_card_property_changes_which_point_to_deleted_card
    Timecop.freeze(2015, 11, 9) do
      with_card_prop_def_test_project do |project|
        iteration1 = create_card!(:name => "iteration1", :card_type_name => 'iteration')
        iteration2 = create_card!(:name => "iteration2", :card_type_name => 'iteration')
        story = create_card!(:name => 'email', :card_type_name => 'story')
        story.cp_iteration = iteration1
        story.save!

        story.cp_iteration = iteration2
        story.save!

        iteration_prop_def = project.find_property_definition("iteration")

        iteration1.destroy

        # This should be fixed for real by story #9256
        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(story))
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>iteration</name>
              <position nil="true"></position>
              <data_type>card</data_type>
              <is_numeric type="boolean">false</is_numeric>
            </property_definition>

            <old_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration1.number}.xml">
                <number type="integer"> #{iteration1.number} </number>
              </card>
            </old_value>

            <new_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration2.number}.xml">
                <number type="integer"> #{iteration2.number} </number>
              </card>
            </new_value>
          </change>
        XML
      end
    end
  end

  def test_to_xml_for_card_property_changes_which_point_to_deleted_card_with_deleted_card_type
    Timecop.freeze(2015, 11, 9) do
      with_card_prop_def_test_project do |project|
        iteration1 = create_card!(:name => "iteration1", :card_type_name => 'iteration')
        iteration2 = create_card!(:name => "iteration2", :card_type_name => 'iteration')
        story = create_card!(:name => 'email', :card_type_name => 'story')
        story.cp_iteration = iteration1
        story.save!

        story.cp_iteration = iteration2
        story.save!

        iteration_prop_def = project.find_property_definition("iteration")

        iteration1.destroy
        iteration2.destroy
        project.find_card_type('iteration').destroy

        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(story))
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>iteration</name>
              <position nil="true"></position>
              <data_type>card</data_type>
              <is_numeric type="boolean">false</is_numeric>
            </property_definition>

            <old_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration1.number}.xml">
                <number type="integer"> #{iteration1.number} </number>
              </card>
            </old_value>

            <new_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration2.number}.xml">
                <number type="integer"> #{iteration2.number} </number>
              </card>
            </new_value>
          </change>
        XML
      end
    end
  end


  def test_to_xml_for_card_property_changes_which_point_to_really_deleted_card
    Timecop.freeze(2015, 11, 9) do
      with_card_prop_def_test_project do |project|
        iteration1 = create_card!(:name => "iteration1", :card_type_name => 'iteration')
        iteration2 = create_card!(:name => "iteration2", :card_type_name => 'iteration')
        story = create_card!(:name => 'email', :card_type_name => 'story')
        story.cp_iteration = iteration1
        story.save!

        story.cp_iteration = iteration2
        story.save!

        iteration_prop_def = project.find_property_definition("iteration")

        iteration1.destroy
        iteration1.versions.delete_all

        # This should be fixed for real by story #9256
        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(story))
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>iteration</name>
              <position nil="true"></position>
              <data_type>card</data_type>
              <is_numeric type="boolean">false</is_numeric>
            </property_definition>

            <old_value>
              <deleted_card> </deleted_card>
            </old_value>

            <new_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration2.number}.xml">
                <number type="integer"> #{iteration2.number} </number>
              </card>
            </new_value>
          </change>
        XML
      end
    end
  end


  ##################################################################
  #                       Planning tree
  #                            |
  #                    ----- release1----
  #                   |                 |
  #            ---iteration1----    iteration2
  #           |                |
  #       story1            story2
  #
  ##################################################################
  def test_to_xml_for_tree_relationship_property_changes
    Timecop.freeze(2015, 11, 9) do
      with_three_level_tree_project do |project|
        planning_tree = project.tree_configurations.find_by_name("three level tree")
        story1 = project.cards.find_by_name("story1")
        iteration1 = project.cards.find_by_name("iteration1")
        iteration2 = project.cards.find_by_name("iteration2")
        planning_tree.add_child story1, :to => iteration2
        story1.save!

        iteration_prop_def = project.find_property_definition("Planning iteration")

        assert_equal_ignoring_spaces <<-XML, xml_for(first_change_of(story1))
          <change type="property-change" mingle_timestamp="2015-11-09">
            <property_definition url="http://example.com/api/v2/projects/#{project.identifier}/property_definitions/#{iteration_prop_def.id}.xml" >
              <name>Planning iteration</name>
              <position type="integer">2</position>
              <data_type>card</data_type>
              <is_numeric type="boolean">false</is_numeric>
            </property_definition>

            <old_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration1.number}.xml">
                <number type="integer"> #{iteration1.number} </number>
              </card>
            </old_value>

            <new_value>
              <card url="http://example.com/api/v2/projects/#{project.identifier}/cards/#{iteration2.number}.xml">
                <number type="integer"> #{iteration2.number} </number>
              </card>
            </new_value>

          </change>
        XML
      end
    end
  end

  def test_to_xml_for_card_deletion_change
    Timecop.freeze(2015, 11, 9) do
      card = create_card!(:name => 'old name')
      card.destroy

      event = card.versions.reload.last.event
      event.send(:generate_changes)

      assert_equal_ignoring_spaces <<-XML, xml_for(event.changes.reload.first)
        <change type="card-deletion" mingle_timestamp="2015-11-09"> </change>
      XML
    end
  end

  def test_to_xml_for_revision_changes
    Timecop.freeze(2015, 11, 9) do
      commit_time = Time.now.utc
      revision = @project.revisions.create!(
              :number => '42',
              :identifier => 'ab02xsd',
              :commit_message => "a wonderful checkin",
              :commit_time => commit_time,
              :commit_user => 'fred')

      revision.reload
      revision.event.send(:generate_changes)
      revision.reload

      assert_equal_ignoring_spaces <<-XML, xml_for(revision.event.changes.first)
      <change type="revision-commit" mingle_timestamp="2015-11-09">
        <changeset>
          <user>fred</user>
          <check_in_time type="datetime">#{commit_time.xmlschema}</check_in_time>
          <revision>ab02xsd</revision>
          <message>a wonderful checkin</message>
        </changeset>
      </change>
      XML
    end
  end

  def test_to_xml_for_system_generated_changes
    Timecop.freeze(2015, 11, 9) do
      with_new_project do |project|
        release = setup_numeric_text_property_definition('release')
        next_release = setup_formula_property_definition('next release', "release + 1")

        card = project.cards.create!(:name => 'Card One', :card_type_name => project.card_types.first.name, :cp_release => '41')
        next_release.change_formula_to('release + 8')
        card.reload
        change = reload_generate_changes_version(card.versions.last).changes.detect { |c| SystemGeneratedCommentChange === c }

        assert_equal_ignoring_spaces <<-XML, xml_for(change)
        <change type="system-comment-addition" mingle_timestamp="2015-11-09">
        <comment> next release changed from release + 1 to release + 8 </comment>
        </change>
        XML
      end
    end
  end

  def test_related_card_for_comment_changes
    first_card = create_card!(:name => 'my first card')
    second_card = create_card!(:name => 'my second card')
    second_card.add_comment(:content => "aha, maybe ##{first_card.number} already covered this? ##{first_card.number} already been there for so long")
    second_card.save!

    assert_equal [first_card.number.to_s], first_change_of(second_card).related_card_numbers
  end

  def test_related_card_for_revision
    card = create_card!(:name => 'card')
    revision = @project.revisions.create!(
            :number => '42',
            :identifier => 'ab02xsd',
            :commit_message => "fixes ##{card.number}",
            :commit_time => Time.now.utc,
            :commit_user => 'fred')

    revision.reload
    revision.event.send(:generate_changes)
    revision.reload

    assert_equal [card.number.to_s], revision.event.changes.first.related_card_numbers
  end

  def test_describe_type_for_export_should_change_type_to_sentance_case
    card = create_card!(:name => 'card')
    card.save!
    change_type = reload_generate_changes_version(card.versions.last).changes.last
    assert_equal 'Card type set', change_type.describe_type_for_export
  end

  def test_describe_type_for_export_should_be_attachment_added
    card = create_card!(:name => 'card')
    card.attach_files(sample_attachment('attachment-for-export.png'))
    card.save!
    attachment_change = reload_generate_changes_version(card.versions.last).changes.last
    assert_equal 'Attachment added', attachment_change.describe_type_for_export
    assert_equal 'attachment-for-export.png', attachment_change.attachment_name
  end

  def test_describe_type_for_export_should_be_attachment_removed
    card = create_card!(:name => 'card')
    card.attach_files(sample_attachment('attachment-for-export.png'))
    card.save!
    card.remove_attachment('attachment-for-export.png')
    card.save!
    attachment_change = reload_generate_changes_version(card.versions.last).changes.last
    assert_equal 'Attachment removed', attachment_change.describe_type_for_export
    assert_equal 'attachment-for-export.png', attachment_change.attachment_name
  end

  private
  def first_change_of(card)
    reload_generate_changes_version(card.versions.last).changes.first
  end

  def xml_for(change)
    view_helper.default_url_options = {:project_id => Project.current.identifier, :host => 'example.com'}
    change.to_xml(:skip_instruct => true, :view_helper => view_helper, :api_version => 'v2')
  end

  def first_card
    @project.cards.first
  end

  def first_card_type
    @project.card_types.first
  end

  def version(range_or_number)
    return first_card.find_version(range_or_number) if !(range_or_number.respond_to? :first)
    range_or_number.each do |version_number|
      yield first_card.find_version(version_number)
    end
  end

  def reload_generate_changes_version(version)
    version.event.send(:generate_changes)
    version.reload
  end
end
