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

class PageVersionTest < ActiveSupport::TestCase

  def setup
    @project = project_without_cards
    @project.activate
    Page::Version.destroy_all
    login_as_member
  end

  def teardown
    logout_as_nil
    super
  end

  def test_previous_survives_single_missing_version
    page = @project.pages.create!(:name => 'first name')
    page.update_attribute(:name, 'second name')
    page.update_attribute(:name, 'third name')
    Page.connection.execute("DELETE FROM #{Page::Version.table_name} WHERE page_id = #{page.id} AND version = 2")
    assert_equal 2, page.reload.versions.size
    assert_equal page.versions[0], page.versions[1].previous
  end

  def test_previous_survives_multiple_missing_versions
    page = @project.pages.create!(:name => 'first name')
    page.update_attribute(:name, 'second name')
    page.update_attribute(:name, 'third name')
    page.update_attribute(:name, 'fourth name')
    Page.connection.execute("DELETE FROM #{Page::Version.table_name} WHERE page_id = #{page.id} AND version IN (2,3)")
    assert_equal 2, page.reload.versions.size
    assert_equal page.versions[0], page.versions[1].previous
  end

  def test_previous_survives_multiple_missing_earliest_versions
    page = @project.pages.create!(:name => 'first name')
    page.update_attribute(:name, 'second name')
    page.update_attribute(:name, 'third name')
    Page.connection.execute("DELETE FROM #{Page::Version.table_name} WHERE page_id = #{page.id} AND version IN (1,2)")
    assert_equal 1, page.reload.versions.size
    assert_nil page.reload.versions.last.previous
  end

  def test_first
    page = @project.pages.create!(:name => 'first name')
    page.update_attribute(:name, 'second name')
    assert page.reload.versions.first.first?
    assert !page.versions.last.first?
  end

  def test_should_not_escape_macro_when_creating_versions
    page = @project.pages.create!(:name => 'first name')
    page.update_attribute(:content, "{{ project }}")
    assert_equal "{{ project }}", page.versions.last.content
  end

  def test_should_generate_event_after_version_create
    page = @project.pages.create!(:name => 'first name')
    event = page.versions.last.event
    assert_not_nil event
    assert_kind_of PageVersionEvent, event
  end

  def test_first_survives_missing_earliest_versions
    page = @project.pages.create!(:name => 'first name')
    page.update_attribute(:name, 'second name')
    page.update_attribute(:name, 'third name')
    Page.connection.execute("DELETE FROM #{Page::Version.table_name} WHERE page_id = #{page.id} AND version IN (1,2)")
    assert page.reload.versions.first.first?
  end

  def test_to_xml_will_serialize_as_a_page_element
    page = @project.pages.create!(:name => 'first name')
    assert_not_nil get_element_text_by_xpath(page.versions.first.to_xml, '/page')
  end

  def test_changed_uses_html_equivalency_instead_of_strict_equals_on_content
    page = @project.pages.create!(:name => 'hey-tch-tml', :content => " <p>osito bonito</p>\r\n")
    page.content = "<p>osito bonito</p>"
    assert_false page.changed?
    page.save!
    assert_equal 1, page.versions.size
  end

  def test_changed_uses_strict_equals_on_name
    page = @project.pages.create!(:name => '<div><h1>hey there</h1></div>', :content => 'whatevs')
    page.name = '<div> <h1>hey there</h1></div>'
    assert page.changed?
    page.save!
    assert_equal 2, page.versions.size
  end

  def test_chart_executing_option_should_have_version
    login_as_admin
    page = @project.pages.create!(name: 'mypage', content: 'whatevs')
    page.update_attributes(name: 'new_blah')
    assert_equal({controller: 'pages', action: 'chart', pagename: 'new_blah', version: 2}, page.versions.last.chart_executing_option)
  end

  def test_deleting_page_should_create_page_version
    login_as_admin
    page = @project.pages.create!(:name => 'shortlived', :content => 'whatevs')
    page.destroy
    version = page.versions.find(:first, :order => 'version DESC')
    assert_equal 'shortlived', version.name
    assert_nil version.content
    assert_equal @project, version.project
  end

  def test_to_xml_v2_should_return_rendered_description_url
    view_helper.default_url_options = {:project_id => @project.identifier, :host => 'example.com'}
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page.update_attribute :content, 'go home'
    xml = page.versions[-2].to_xml(:view_helper => view_helper, :version => 'v2')
    assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/render?content_provider%5Bid%5D=#{page.versions[-2].id}&amp;content_provider%5Btype%5D=page%3A%3Aversion",
        get_attribute_by_xpath(xml, "//page/rendered_description/@url")
  end

  def test_getting_previous_version_from_deleted_page
    login_as_admin
    with_new_project do |project|
      page = project.pages.create! :name => 'shortlived'
      first_version = page.versions.first

      page.content = 'sample'
      page.save!

      latest_version = page.versions.select(&:latest_version?).first
      page.destroy

      assert_equal latest_version.reload.previous, first_version
    end
  end

  def test_checking_latest_on_version_of_a_deleted_page
    login_as_admin

    with_new_project do |project|
      page = project.pages.create! :name => 'shortlived'
      first_version = page.versions.first

      page.destroy
      assert_false first_version.reload.latest_version?
      assert first_version.next.latest_version?
    end
  end

end
