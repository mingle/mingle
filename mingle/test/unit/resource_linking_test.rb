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
class ResourceLinkingTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    view_helper.default_url_options = {:project_id => @project.identifier, :host => 'example.com'}
  end

  def test_link_for_project
    link = @project.resource_link
    assert_equal @project.name, link.title
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}.xml", link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/#{@project.identifier}", link.html_href(view_helper)
  end

  def test_link_to_project_with_override_host
    link = @project.resource_link
    assert_equal "http://mingle-api.com/api/v2/projects/#{@project.identifier}.xml", link.xml_href(view_helper, 'v2', :host => 'mingle-api.com')
  end

  def test_link_for_card
    card = @project.cards.first
    link = card.resource_link
    assert_equal "#{card.card_type_name} ##{card.number}", link.title
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml", link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/#{@project.identifier}/cards/#{card.number}", link.html_href(view_helper)
  end

  def test_link_for_card_directly_using_number
    link = Card.resource_link("card 123", {:number => '123', :project_id => @project.identifier})
    assert_equal "card 123", link.title
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/123.xml", link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/#{@project.identifier}/cards/123", link.html_href(view_helper)
  end

  def test_link_for_card_version
    card_version = @project.cards.first.versions.first
    link = card_version.resource_link
    assert_equal "#{card_version.card_type_name} ##{card_version.number} (v#{card_version.version})", link.title
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/cards/#{card_version.number}.xml?version=#{card_version.version}", link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/#{@project.identifier}/cards/#{card_version.number}?version=#{card_version.version}", link.html_href(view_helper)
  end

  def test_link_for_page_version
    login_as_member
    page = @project.pages.create! :name => 'resource'
    page_version = page.versions.first
    link = page_version.resource_link
    assert_equal page_version.name + " (v#{page_version.version})", link.title
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/wiki/#{page_version.identifier}.xml?version=#{page_version.version}", link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/#{@project.identifier}/wiki/#{URI.escape(page_version.name)}?version=#{page_version.version}", link.html_href(view_helper)
  end

  def test_link_for_page
    page = @project.pages.first
    link = page.resource_link
    assert_equal page.name, link.title
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/wiki/#{page.identifier}.xml", link.xml_href(view_helper, 'v2')
    assert_equal "http://example.com/projects/#{@project.identifier}/wiki/#{URI.escape(page.name)}", link.html_href(view_helper)
  end

  def test_link_for_revision
    rev = @project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'xxx'})
    link = rev.resource_link
    assert_equal "Revision revision_id", link.title
    assert_equal "http://example.com/projects/#{@project.identifier}/revisions/#{rev.identifier}", link.html_href(view_helper)
    assert_nil link.xml_href(view_helper, 'v2')
  end

  def test_link_for_tag
    link = @project.tags.create!(:name => 'foo').resource_link
    assert_nil link.html_href(view_helper)
    assert_nil link.xml_href(view_helper, 'v2')
  end

  def test_link_for_card_type
    card_type = @project.card_types.first
    link = card_type.resource_link
    assert_equal "http://example.com/projects/#{@project.identifier}/card_types/#{card_type.id}", link.html_href(view_helper)
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml", link.xml_href(view_helper, 'v2')
  end

  def test_link_for_property_definition
    pd = @project.property_definitions.first
    link = pd.resource_link
    assert_equal "http://example.com/projects/#{@project.identifier}/property_definitions/#{pd.id}", link.html_href(view_helper)
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/property_definitions/#{pd.id}.xml", link.xml_href(view_helper, 'v2')
  end

  def test_link_for_subversion_configuration
    sc = SubversionConfiguration.create_or_update(@project.id, nil, :username =>"test", :password => "password", :repository_path =>"/a_repos")
    assert_equal "http://example.com/projects/#{@project.identifier}/subversion_configurations", sc.resource_link.html_href(view_helper)
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/subversion_configurations.xml", sc.resource_link.xml_href(view_helper, 'v2')
  end

  def test_link_for_attachement
    attachment = Attachment.create!(:file => sample_attachment, :project => @project)
    assert_equal "Attachment #{attachment.id}", attachment.resource_link.title
    assert_nil attachment.resource_link.xml_href(view_helper, 'v2')
  end

  def test_link_for_user
    user = User.find_by_login("member")
    assert_equal "http://example.com/api/v2/users/#{user.id}.xml", user.resource_link.xml_href(view_helper, 'v2')
  end

end
