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

class CardVersionTest < ActiveSupport::TestCase

  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end

  def test_previous_survives_single_missing_version
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card.update_attribute(:name, 'second name')
    card.update_attribute(:name, 'third name')
    Card.connection.execute("DELETE FROM #{Card::Version.quoted_table_name} WHERE card_id = #{card.id} AND version = 2")
    assert_equal 2, card.reload.versions.size
    assert_equal card.versions[0], card.versions[1].previous
  end

  def test_previous_survives_multiple_missing_versions
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card.update_attribute(:name, 'second name')
    card.update_attribute(:name, 'third name')
    card.update_attribute(:name, 'fourth name')
    Card.connection.execute("DELETE FROM #{Card::Version.quoted_table_name} WHERE card_id = #{card.id} AND version IN (2,3)")
    assert_equal 2, card.reload.versions.size
    assert_equal card.versions[0], card.versions[1].previous
  end

  def test_previous_survives_multiple_missing_earliest_versions
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card.update_attribute(:name, 'second name')
    card.update_attribute(:name, 'third name')
    Card.connection.execute("DELETE FROM #{Card::Version.quoted_table_name} WHERE card_id = #{card.id} AND version IN (1,2)")
    assert_equal 1, card.reload.versions.size
    assert_nil card.reload.versions.last.previous
  end

  def test_first
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card.update_attribute(:name, 'second name')
    assert card.reload.versions.first.first?
    assert !card.versions.last.first?
  end

  def test_first_survives_missing_earliest_versions
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card.update_attribute(:name, 'second name')
    card.update_attribute(:name, 'third name')
    Card.connection.execute("DELETE FROM #{Card::Version.quoted_table_name} WHERE card_id = #{card.id} AND version IN (1,2)")
    assert card.reload.versions.first.first?
  end

  def test_should_create_system_generated_comment_on_property_change_only_for_relevant_cards
    with_new_project do |project|
      bug_type = project.card_types.create!(:name => 'bug')
      story_type = project.card_types.create!(:name => 'story')

      bug_size = setup_numeric_property_definition 'bug size', ['1', '2', '3']
      story_size = setup_numeric_property_definition 'story size', ['1', '2', '3']

      b2 = setup_formula_property_definition 'b2', "2 * 'bug size'"
      s2 = setup_formula_property_definition 's2', "2 * 'story size'"

      bug_size.card_types = [bug_type]
      b2.card_types = [bug_type]

      story_size.card_types = [story_type]
      s2.card_types = [story_type]

      bug = project.cards.create!(:name => 'bug', :card_type_name => bug_type.name, :cp_bug_size => '2')
      story = project.cards.create!(:name => 'story', :card_type_name => story_type.name, :cp_story_size => '1')

      b2.change_formula_to("2.5 * 'bug size'")
      b2.save!

      assert bug.versions.reload.last.system_generated?
      assert !story.versions.reload.last.system_generated?
    end
  end

  def test_should_create_card_version_event_after_create
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    assert_not_nil card.versions.last.event
    assert_kind_of CardVersionEvent, card.versions.last.event
  end

  def test_card_version_should_only_contain_card_version_events_for_a_version
    first_card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    second_card = @project.cards.create!(:name => 'second name', :project => @project, :card_type => @project.card_types.first)

    first_card.insert_after(second_card.reload)
    second_card.insert_after(first_card.reload)
    card_version = first_card.versions.last

    assert_equal 2, Event.find(:all, :conditions => {:origin_id => card_version.id}).count
    assert_equal 1,first_card.versions.size
    assert_equal 'CardVersionEvent',card_version.event.type

  end


  def test_changing_description_with_an_html_equivalent_description_does_not_create_version
    card = @project.cards.create!(:name => 'html sameness', :description => " <p>osito <em>beary</em> bonito!</p>\r\n", :card_type => @project.card_types.first)
    card.description = "<p>osito <em>beary</em> bonito!</p>"
    assert_false card.altered?
    card.save!
    assert_equal 1, card.versions.size
  end

  # bug 3676
  def test_changes_method_does_not_throw_exception_if_card_type_no_longer_exists
    type_card = @project.card_types.find_by_name('Card')
    type_bug = @project.card_types.create!(:name => 'Bug')

    some_card = @project.cards.create!(:name => 'some card', :card_type => type_card)

    some_card.card_type = type_bug
    some_card.save!

    some_card.card_type = type_card
    some_card.save!

    type_bug.destroy
    @project.reload

    begin
      some_card.reload.versions[1].changes
    rescue Exception => e
      fail "The changes method has thrown an exception #{e} when it wasn't expected to."
    end
  end

  def test_diff_excludes_changing_descrition_from_nil_to_empty
    card =create_card!(:name => 'first name', :description => nil)
    card.update_attributes(:description => "")
    assert_equal 1, card.reload.versions.size
  end

  def test_to_xml_will_serialize_as_a_card_element
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    assert_not_nil get_element_text_by_xpath(card.versions.first.to_xml, '/card')
  end

  def test_to_xml_will_include_rendered_description_link
    view_helper.default_url_options = {:project_id => @project.identifier, :host => 'example.com'}
    card =create_card!(:name => 'first name', :description => nil)
    card.update_attributes(:description => 'h3. hello')
    card.update_attributes(:description => 'h3. goodbye')

    xml =  card.versions[-2].to_xml(:view_helper => view_helper, :version => 'v2')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/render?content_provider%5Bid%5D=#{card.versions[-2].id}&amp;content_provider%5Btype%5D=card%3A%3Aversion",
                get_attribute_by_xpath(xml, "//card/rendered_description/@url")
  end

  # bug 8173
  def test_chart_executing_option_should_return_card_id_and_not_version_id
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    assert_equal({ :controller=>"cards", :action=>"chart", :id => card.id, version: 1 }, card.versions.last.chart_executing_option)
  end

  def test_chart_executing_option_should_return_version_number
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    card.update_attributes(name: 'new name')
    assert_equal({ :controller=>"cards", :action=>"chart", :id => card.id, version: 2 }, card.versions.last.chart_executing_option)
  end

  def test_latest_version
    with_new_project do |project|
      card = create_card!(:name => 'a card')
      card.update_attribute(:description, 'new description')
      card = project.cards.first
      assert card.latest_version?
      assert card.versions.last.latest_version?
      assert !card.versions.first.latest_version?
      assert_equal 2, card.version
      assert_equal 2, card.versions[0].latest_version
      assert_equal 2, card.versions[1].latest_version
    end
  end

  def test_latest_version_on_version_of_deleted_card
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    last_version = card.versions.last
    card.destroy

    assert_false last_version.reload.latest_version?
    assert last_version.next.latest_version?
  end
end
