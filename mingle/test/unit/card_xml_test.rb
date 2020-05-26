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

class CardXmlTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = first_project
    @project.activate
    login_as_member
    view_helper.default_url_options = {:project_id => @project.identifier, :host => 'example.com'}
  end

  def teardown
    cleanup_repository_drivers_on_failure
    Clock.reset_fake
  end

  def test_to_xml_should_not_include_has_macro
    card1 = create_card!(:name => 'card1')
    assert !card1.to_xml(:version => 'v2').include?('has_macros')
  end

  def test_to_xml_for_version_2_should_include_relevant_attributes
    card = create_card!(:name => 'card name', :description => 'hi there')
    cp_status = @project.find_property_definition('status')
    cp_status.update_card(card, 'new')
    cp_iteration = @project.find_property_definition('Iteration')
    cp_iteration.update_attribute(:hidden, true)
    cp_iteration.update_card(card, '1')

    card_as_xml = card.to_xml(:version => 'v2')

    assert_equal card.name, get_element_text_by_xpath(card_as_xml, "//card/name")
    assert_equal card.description, get_element_text_by_xpath(card_as_xml, "//card/description")
    assert_equal card.id.to_s, get_element_text_by_xpath(card_as_xml, "//card/id[@type='integer']")
    assert_equal card.number.to_s, get_element_text_by_xpath(card_as_xml, "//card/number[@type='integer']")
    assert_equal card.version.to_s, get_element_text_by_xpath(card_as_xml, "//card/version[@type='integer']")
    assert_equal card.project_card_rank.to_s, get_element_text_by_xpath(card_as_xml, "//card/project_card_rank")

    document = REXML::Document.new(card_as_xml)
    status_property_elements = REXML::XPath.match(document, "//card/properties/property[name='Status']")
    assert_equal 1, status_property_elements.size
    status_property_element = status_property_elements.first
    assert_equal 'new', REXML::XPath.match(status_property_element, "value").first.text
    assert_equal "true", get_attribute_by_xpath(document.to_s, "//card/properties/property[name='Iteration']/@hidden")
    assert_equal "false", get_attribute_by_xpath(document.to_s, "//card/properties/property[name='Status']/@hidden")
  end

  def test_to_xml_for_version_2_should_include_hidden_properties
    card = create_card!(:name => 'card name', :description => 'hi there')
    cp_iteration = @project.find_property_definition('Iteration')
    cp_iteration.update_attribute(:hidden, true)
    cp_iteration.update_card(card, '1')

    card_as_xml = card.to_xml(:version => 'v2')

    document = REXML::Document.new(card_as_xml)
    assert_equal 1, document.element_count_at("//card/properties/property[name='Iteration']")
    assert_equal "true", get_attribute_by_xpath(document.to_s, "//card/properties/property[name='Iteration']/@hidden")
  end

  def test_v2_to_xml_project_should_be_compact
    card = @project.cards.first
    card_as_xml = card.to_xml(:version => 'v2')
    assert_equal card.project.identifier, get_element_text_by_xpath(card_as_xml, "//card/project/identifier")
    document = REXML::Document.new(card_as_xml)
    assert_equal ['identifier', 'name'], document.elements_at("//card/project/*").map(&:name).sort
  end

  def test_v2_to_xml_created_by_user_should_be_compact
    card = @project.cards.first
    card_as_xml = card.to_xml(:version => 'v2')
    assert_equal card.created_by.name, get_element_text_by_xpath(card_as_xml, "//card/created_by/name")
    assert_equal card.created_by.login, get_element_text_by_xpath(card_as_xml, "//card/created_by/login")
    document = REXML::Document.new(card_as_xml)
    assert_equal ['login', 'name'], document.elements_at("//card/created_by/*").map(&:name).sort
  end

  def test_v2_to_xml_modified_by_user_should_be_compact
    card = @project.cards.first
    card_as_xml = card.to_xml(:version => 'v2')
    assert_equal card.modified_by.name, get_element_text_by_xpath(card_as_xml, "//card/modified_by/name")
    assert_equal card.modified_by.login, get_element_text_by_xpath(card_as_xml, "//card/modified_by/login")
    document = REXML::Document.new(card_as_xml)
    assert_equal ['login', 'name'], document.elements_at("//card/modified_by/*").map(&:name).sort
  end

  def test_v2_to_xml_card_type_should_be_compact
    card = @project.cards.first
    card_as_xml = card.to_xml(:version => 'v2')
    assert_equal card.card_type_name, get_element_text_by_xpath(card_as_xml, "//card/card_type/name")
    document = REXML::Document.new(card_as_xml)
    assert_equal ['name'], document.elements_at("//card/card_type/*").map(&:name).sort
  end

  def test_v2_to_xml_project_should_be_compact_for_card_version
    card_version = @project.cards.first.versions.last
    card_version_as_xml = card_version.to_xml(:version => 'v2')
    assert_equal card_version.project.identifier, get_element_text_by_xpath(card_version_as_xml, "//card/project/identifier")
    document = REXML::Document.new(card_version_as_xml)
    assert_equal ['identifier', 'name'], document.elements_at("//card/project/*").map(&:name).sort
  end

  def test_v2_to_xml_created_by_user_should_be_compact_card_version
    card_version = @project.cards.first.versions.last
    card_version_as_xml = card_version.to_xml(:version => 'v2')
    assert_equal card_version.created_by.name, get_element_text_by_xpath(card_version_as_xml, "//card/created_by/name")
    assert_equal card_version.created_by.login, get_element_text_by_xpath(card_version_as_xml, "//card/created_by/login")
    document = REXML::Document.new(card_version_as_xml)
    assert_equal ['login', 'name'], document.elements_at("//card/created_by/*").map(&:name).sort
  end

  def test_v2_to_xml_modified_by_user_should_be_compact_card_version
    card_version = @project.cards.first.versions.last
    card_version_as_xml = card_version.to_xml(:version => 'v2')
    assert_equal card_version.modified_by.name, get_element_text_by_xpath(card_version_as_xml, "//card/modified_by/name")
    assert_equal card_version.modified_by.login, get_element_text_by_xpath(card_version_as_xml, "//card/modified_by/login")
    document = REXML::Document.new(card_version_as_xml)
    assert_equal ['login', 'name'], document.elements_at("//card/modified_by/*").map(&:name).sort
  end

  def test_v2_to_xml_card_type_should_be_compact_for_card_version
    card_version = @project.cards.first.versions.last
    card_version_as_xml = card_version.to_xml(:version => 'v2')
    assert_equal card_version.card_type_name, get_element_text_by_xpath(card_version_as_xml, "//card/card_type/name")
    document = REXML::Document.new(card_version_as_xml)
    assert_equal ['name'], document.elements_at("//card/card_type/*").map(&:name).sort
  end

  def test_to_xml_should_include_card_relationship_properties
    with_three_level_tree_project do |project|
      view_helper.default_url_options = {:project_id => project.identifier}
      card = project.cards.create!(:name => 'card name', :description => 'hi there', :card_type_name => 'Story')
      cp_related_card = project.find_property_definition('related card')
      cp_related_card.update_card(card, project.cards.find_by_name('story1'))
      card.save!

      card_as_xml = card.to_xml(:version => 'v1')
      assert_equal card.cp_related_card.id.to_s, get_element_text_by_xpath(card_as_xml, "//card/cp_related_card_card_id[@type='integer']")
    end
  end

  def test_v2_xml_should_include_user_properties_as_resource_link
    with_first_project do |project|
      view_helper.default_url_options = {:project_id => project.identifier, :host => "example.com"}
      member = User.find_by_login('member')
      card = project.cards.first
      card.update_attribute(:cp_dev, member)
      xml =  card.to_xml(:view_helper => view_helper, :version => 'v2')
      assert_equal "http://example.com/api/v2/users/#{member.id}.xml", get_attribute_by_xpath(xml, "//card/properties/property[name='dev']/value/@url")
    end
  end

  def test_v2_xml_should_include_url_for_rendered_descriptions
    with_first_project do |project|
      view_helper.default_url_options = {:project_id => project.identifier, :host => 'example.com'}
      card = project.cards.first
      xml =  card.to_xml(:view_helper => view_helper, :version => 'v2')
      assert_equal "http://example.com/api/v2/projects/first_project/render?content_provider%5Bid%5D=#{card.id}&amp;content_provider%5Btype%5D=card",
                  get_attribute_by_xpath(xml, "//card/rendered_description/@url")
    end
  end

end
