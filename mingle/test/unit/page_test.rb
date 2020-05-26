# -*- coding: utf-8 -*-

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
require File.expand_path(File.dirname(__FILE__) + '/renderable_test_helper')

# Tags: #791 #597
class PageTest < ActiveSupport::TestCase
  include ::RenderableTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
    view_helper.default_url_options = {:project_id => @project.identifier}
  end

  def teardown
    logout_as_nil
    super
  end

  def test_can_generate_clean_identifier_from_name
    p = @project.pages.create(:name => 'This is a weird page title')
    assert_equal 'This_is_a_weird_page_title', p.identifier
  end

  def test_can_find_by_identifier
    assert_equal 'First Page', @project.pages.find_by_identifier('First_Page').name
    assert_nil @project.pages.find_by_identifier('page_on_other_project')
  end

  def test_can_set_name_from_identifier
    p = @project.pages.create(:identifier => 'This_is_a_weird_page_title')
    assert_equal 'This is a weird page title', p.name
  end

  def test_can_render_page_links
    @project.pages.create(:name => 'with a link')
    @project.pages.create(:name => 'another one')
    @project.pages.create(:name => 'Link first in document')
    p = @project.pages.create(:name => '1', :content => 'This is a page [[with a link]] and [[another one]]')
    assert_equal 'This is a page <a href="/projects/first_project/wiki/with_a_link">with a link</a> and <a href="/projects/first_project/wiki/another_one">another one</a>', p.formatted_content(view_helper)
    p = @project.pages.create(:name => '2',  :content => "[[Link first in document]]")
    assert_equal '<a href="/projects/first_project/wiki/Link_first_in_document">Link first in document</a>', p.formatted_content(view_helper)
  end

  def test_can_render_formatted_wiki_link
    @project.pages.create(:name => 'Another Page')
    p = @project.pages.create(:name => 'hi', :content => "<h2>This is a h2 link to [[Another Page]] w00t!</h2>")
    assert_equal '<h2>This is a h2 link to <a href="/projects/first_project/wiki/Another_Page">Another Page</a> w00t!</h2>', p.formatted_content(view_helper)
  end

  def test_page_links_can_be_quoted
    p = @project.pages.create(:name => 'whoa', :content => 'I can quote [\[brackets\]]!')
    assert_equal 'I can quote [[brackets]]!', p.formatted_content(view_helper)
  end

  def test_overview_page?
    assert @project.pages.create(:name => 'Overview Page').overview_page?
    assert !@project.pages.create(:name => 'Not the Overview Page').overview_page?
  end

  def test_should_know_modified_by
    Thread.current['user'] = User.find_by_login('admin')
    first_page = @project.pages.find_by_identifier('First_Page')
    first_page.content << 'more interestng stuff going on here'
    first_page.save!
    assert_equal 'admin@email.com', first_page.reload.modified_by.email
  end

  def test_should_know_created_by
    Thread.current["user"] = User.find_by_login('first')
    p = @project.pages.create(:name => "test page")
    p.save!
    assert_equal 'first@email.com', p.reload.created_by.email
  end

  def test_should_convert_link_label
    p = @project.pages.create(:name => '1', :content => 'go [[here|First Page]]')
    assert_equal 'go <a href="/projects/first_project/wiki/First_Page">here</a>', p.formatted_content(view_helper)
    p = @project.pages.create(:name => '2', :content => 'see, [[More description|First Page]]')
    assert_equal 'see, <a href="/projects/first_project/wiki/First_Page">More description</a>', p.formatted_content(view_helper)
  end

  def test_should_link_card
    p = @project.pages.create(:name => '1', :content => 'card #234 shows the detail')
    expected_content = %{card <a href="/projects/first_project/cards/234" class="card-tool-tip card-link-234" data-card-name-url="/projects/first_project/cards/card_name/234">#234</a> shows the detail}
    assert_dom_equal expected_content, p.formatted_content(view_helper)

    p = @project.pages.create(:name => '2', :content => 'card #234a is not a card')
    assert_dom_equal 'card #234a is not a card', p.formatted_content(view_helper)
  end

  def test_should_be_able_to_delete_attachments_from_pages
    page = @project.pages.create!(:name => "card for testing attachment version")
    page.attach_files(sample_attachment)
    page.save!
    assert_equal 1, page.reload.attachments.size
    assert_equal 2, page.versions.size

    page.remove_attachment(page.attachments.first.file_name)
    page.save!

    assert_equal 0, page.reload.attachments.size
    assert_equal 3, page.versions.size
  end

  def test_cannot_remove_attachments_from_page_versions
    page = @project.pages.create!(:name => "card for testing attachment version")
    page.attach_files(sample_attachment)
    page.save!
    assert_equal 1, page.reload.attachments.size
    assert_equal 2, page.versions.size

    older_version = page.versions.last

    page.content = "new content"
    page.save!

    assert_raise RuntimeError do
      older_version.remove_attachment(older_version.attachments.first.file_name)
    end
  end

  # test for bug #597
  def test_can_do_img_tags_with_card_numbers
    p = @project.pages.create(:name => 'pg', :content => '<img src="https://svn.internal.thoughtworksstudios.com/svn/ice/trunk/test/bugs/screenshots/card397.png"/>')
    formatted_content = p.formatted_content(view_helper)
    assert_dom_equal '<img src="https://svn.internal.thoughtworksstudios.com/svn/ice/trunk/test/bugs/screenshots/card397.png" />', formatted_content
  end

  # test for bug #603
  def test_double_underscores_work
    p = @project.pages.create(:name => 'hello', :content => "[[double__underscores]]")
    assert_dom_equal %{
      <a href="/projects/first_project/wiki/double__underscores" class="non-existent-wiki-page-link">double__underscores</a>
    }, p.formatted_content(view_helper)
  end

  def test_should_link_card_if_the_content_include_tag
    p = @project.pages.create(:name => 'zinga', :content => '< good #234')
    expected_content = %{&lt; good <a href="/projects/first_project/cards/234" class="card-tool-tip card-link-234" data-card-name-url="/projects/first_project/cards/card_name/234">#234</a>}

    assert_dom_equal expected_content, p.formatted_content(view_helper)
  end

  def test_can_tag_a_wiki_page
    p = @project.pages.create(:content => "This page will be tagged", :name=>'Here is a name')
    p.tag_with('rss')
    p.save!
    p = @project.pages.find_by_identifier('Here_is_a_name')
    assert_equal 1, p.tags.size
    assert_equal 'rss', p.tag_list
  end

  def test_attach_files_will_generate_new_page_version
   page = @project.pages.create(:name => "page one for attachments", :content => "random wiki content")
   assert_equal 1, page.versions.size
   page.attach_files(sample_attachment("1.gif"))
   page.save!
   assert_equal 2, page.reload.versions.size
   page.attach_files(sample_attachment("2.gif"))
   assert_equal 2, page.attachments.size
   page.save!
   assert_equal 3, page.reload.versions.size
   assert_equal 2, page.reload.attachments.size
   assert_equal 2, page.reload.versions.last.attachments.size
  end

  def test_attachments_will_copyed_to_versions
   page = @project.pages.create(:name => "page two for attachments", :content => "more randomness")
   page.attach_files(sample_attachment("1.gif"))
   page.save!
   page.attach_files(sample_attachment("2.gif"))
   page.save!
   assert_equal 3, page.reload.versions.size
   assert_equal 2, page.attachments.size
   assert_equal 0, page.versions[0].attachments.size
   assert_equal 1, page.versions[1].attachments.size
   assert_equal 2, page.versions[2].attachments.size
  end

  def test_page_version_should_keep_attachment_urls
   page = @project.pages.create(:name => "page three for attachments", :content => "still more randomness")
   page.attach_files(sample_attachment)
   page.save!
   page.reload
   assert_equal page.attachments.first.url, page.versions.last.attachments.first.url
  end

  def test_update_against_no_changes_will_not_generate_new_page_version
   page = @project.pages.create(:name => "page four for attachments", :content => "yet more randomness")
   page.attach_files(sample_attachment)
   page.save!
   assert_equal 2, page.reload.versions.size
   page.save!
   assert_equal 2, page.reload.versions.size
  end

  def test_tag_name_can_contain_hyphens
    page = @project.pages.create!(:name => 'page for tagging bug')
    page.tag_with(['apple','apple-2','apple-3'])
    assert_equal 'apple,apple-2,apple-3', page.tags(&:name).join(',')
  end

  def test_should_delete_all_page_subscriptions_on_page_delete
    login_as_proj_admin
    subscribed_page = @project.pages.create!(:name => 'page', :content => 'content')
    @project.create_history_subscription(User.find_by_login('member'), HistoryFilterParams.new(:page_identifier => subscribed_page.identifier).serialize)
    subscriptions_before_page_delete = @project.history_subscriptions.size
    subscribed_page.destroy
    subscriptions_after_page_delete = @project.reload.history_subscriptions.size
    assert_equal 1, subscriptions_before_page_delete - subscriptions_after_page_delete
  end

  def test_saves_whether_page_has_macros
    has_macro = @project.pages.create!(:name => 'Has macro', :content => "{{ value query: SELECT SUM(Release) }}")
    assert has_macro.has_macros

    no_macro = @project.pages.create!(:name => 'No macro', :content => '[Link]')
    assert !no_macro.has_macros
  end

  def test_page_names_are_enforced_to_be_unique_in_a_case_insensitive_manner
    page_one = @project.pages.create!(:name => 'page one')
    page_two = @project.pages.create(:name => 'PAGE ONE')
    assert_equal ['Name has already been taken'], page_two.errors.full_messages
  end

  def test_find_by_identifier_will_ignore_case
    page_one = @project.pages.create!(:name => 'page one')
    assert_equal page_one, Page.find_by_identifier('PAGE_ONE')
  end

  def test_destroy_also_destroys_favorite
    login_as_proj_admin
    page = @project.pages.create!(:name => 'my favorite')
    favorite = Favorite.create!(:project_id => @project.id, :favorited_type => Page.name, :favorited_id => page.id)
    page.destroy
    assert_record_deleted(favorite)
  end

  def test_destroy_pages_by_project_admin_is_allowed
    login_as_proj_admin
    page = @project.pages.create!(:name => 'to be deleted')
    page.destroy
    assert_record_deleted(page)
  end

  def test_destroy_pages_by_member_is_not_allowed
    login_as_member
    page = @project.pages.create!(:name => 'cannot be deleted')
    assert_raise UserAccess::NotAuthorizedException do
      page.destroy
    end
    assert_record_not_deleted(page)
  end

  def test_to_xml_v1_should_return_the_project_id
    login_as_member
    page = @project.pages.create!(:name => 'dear prudence')
    xml = page.to_xml(:version => 'v1')
    assert_equal page.project_id.to_s, get_element_text_by_xpath(xml, "//page/project_id")
  end

  def test_to_xml_v2_should_return_the_compact_project
    login_as_member
    page = @project.pages.create!(:name => 'dear prudence')
    xml = page.to_xml(:version => 'v2')
    assert_equal page.project.identifier, get_element_text_by_xpath(xml, "//page/project/identifier")
    document = REXML::Document.new(xml)
    assert_equal ['identifier', 'name'], document.elements_at("//page/project/*").map(&:name).sort
  end

  def test_page_version_to_xml_v1_should_return_the_project_id
    login_as_member
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page_version = page.versions.first
    xml = page_version.to_xml(:version => 'v1')
    assert_equal page_version.project_id.to_s, get_element_text_by_xpath(xml, "//page-version/project_id")
  end

  def test_page_version_to_xml_v2_should_return_the_compact_project
    login_as_member
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page_version = page.versions.first
    xml = page_version.to_xml(:version => 'v2')
    assert_equal page_version.project.identifier, get_element_text_by_xpath(xml, "//page/project/identifier")
    document = REXML::Document.new(xml)
    assert_equal ['identifier', 'name'], document.elements_at("//page/project/*").map(&:name).sort
  end

  def test_v1_to_xml_created_by_user_id_should_be_there
    page = @project.pages.create!(:name => 'sergeant buckybeaver')
    xml = page.to_xml(:version => 'v1')
    assert_equal page.created_by_user_id.to_s, get_element_text_by_xpath(xml, "//page/created_by_user_id")
  end

  def test_v2_to_xml_created_by_user_should_be_compact
    page = @project.pages.create!(:name => 'dear prudence')
    xml = page.to_xml(:version => 'v2')
    assert_equal page.created_by.login, get_element_text_by_xpath(xml, "//page/created_by/login")
    document = REXML::Document.new(xml)
    assert_equal ['login', 'name'], document.elements_at("//page/created_by/*").map(&:name).sort
  end

  def test_v1_to_xml_modified_by_user_id_should_be_there
    page = @project.pages.create!(:name => 'sergeant buckybeaver')
    xml = page.to_xml(:version => 'v1')
    assert_equal page.modified_by_user_id.to_s, get_element_text_by_xpath(xml, "//page/modified_by_user_id")
  end

  def test_v2_to_xml_modified_by_user_should_be_compact
    page = @project.pages.create!(:name => 'dear prudence')
    xml = page.to_xml(:version => 'v2')
    assert_equal page.modified_by.login, get_element_text_by_xpath(xml, "//page/modified_by/login")
    document = REXML::Document.new(xml)
    assert_equal ['login', 'name'], document.elements_at("//page/modified_by/*").map(&:name).sort
  end

  def test_page_version_to_xml_v1_should_return_the_created_by_user_id
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page_version = page.versions.first
    xml = page_version.to_xml(:version => 'v1')
    assert_equal page_version.created_by_user_id.to_s, get_element_text_by_xpath(xml, "//page-version/created_by_user_id")
  end

  def test_page_version_to_xml_v2_should_return_the_compact_created_by_user
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page_version = page.versions.first
    xml = page_version.to_xml(:version => 'v2')
    assert_equal page_version.created_by.login, get_element_text_by_xpath(xml, "//page/created_by/login")
    document = REXML::Document.new(xml)
    assert_equal ['login', 'name'], document.elements_at("//page/created_by/*").map(&:name).sort
  end

  def test_page_version_to_xml_v1_should_return_the_modified_by_user_id
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page_version = page.versions.first
    xml = page_version.to_xml(:version => 'v1')
    assert_equal page_version.modified_by_user_id.to_s, get_element_text_by_xpath(xml, "//page-version/modified_by_user_id")
  end

  def test_page_version_to_xml_v2_should_return_the_compact_modified_by_user
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    page_version = page.versions.first
    xml = page_version.to_xml(:version => 'v2')
    assert_equal page_version.modified_by.login, get_element_text_by_xpath(xml, "//page/modified_by/login")
    document = REXML::Document.new(xml)
    assert_equal ['login', 'name'], document.elements_at("//page/modified_by/*").map(&:name).sort
  end

  def test_page_to_xml_v2_should_return_rendered_description_url
    view_helper.default_url_options= {:project_id => @project.identifier, :host => 'example.com'}
    page = @project.pages.create!(:name => 'dear prudence')
    page.update_attribute :content, 'come out and play'
    xml = page.to_xml(:view_helper => view_helper, :version => 'v2')
    assert_equal "http://example.com/api/v2/projects/first_project/render?content_provider%5Bid%5D=#{page.id}&amp;content_provider%5Btype%5D=page",
        get_attribute_by_xpath(xml, "//page/rendered_description/@url")
  end

  #moved from pages_controller_test for fixing #5590
  def test_can_render_chart_container_and_script
    login_as_admin
    with_new_project do |project|
      setup_property_definitions :feature => [], :status => ["Closed"], :old_type => ["Story"]
      setup_numeric_property_definition('size', [])

      chart = %{
        {{
          ratio-bar-chart
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
      }
      page = project.pages.create!(:name => 'Dashboard', :content => chart)
      content = page.formatted_content(view_helper)

      assert_include "id=\"ratiobarchart-Page-#{page.id}-1\"", content
      assert_include "dataUrl = '/projects/#{project.identifier}/wiki/Dashboard/chart_data/1/ratio-bar-chart'", content

      page.update_attributes(:content => %{
        #{chart}
        #{chart}
      })

      content = page.formatted_content(view_helper)

      assert_include "id=\"ratiobarchart-Page-#{page.id}-1\"", content
      assert_include "dataUrl = '/projects/#{project.identifier}/wiki/Dashboard/chart_data/1/ratio-bar-chart'", content
      assert_include "id=\"ratiobarchart-Page-#{page.id}-2\"", content
      assert_include "dataUrl = '/projects/#{project.identifier}/wiki/Dashboard/chart_data/2/ratio-bar-chart'", content
    end
  end

  #moved from pages_controller_test for fixing #5590
  def test_can_render_chart_for_page_version
    login_as_admin
    with_new_project do |project|
      setup_property_definitions :feature => [], :status => ["Closed"], :old_type => ["Story"]
      setup_numeric_property_definition('size', [])

      page = project.pages.create!(:name => 'Dashboard')
      page.update_attribute(:content, %{
        {{
          ratio-bar-chart
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
      })

      content = page.formatted_content(view_helper)

      assert_include "id=\"ratiobarchart-Page-#{page.id}-1\"", content
    end
  end

  def test_deleting_a_page_does_not_delete_its_versions_and_their_events
    login_as_admin
    page = @project.pages.create!(:name => 'mistake', :content => 'oops')
    page.content = "Change the content"
    page.save!

    page_versions = page.versions
    assert_equal 2, page_versions.size
    events = page_versions.collect(&:event)
    assert_equal 2, events.size

    page.destroy

    page_versions.each { |pv| assert_record_not_deleted pv }
    events.each { |ev| assert_record_not_deleted ev }
  end

  def test_by_default_page_should_know_if_it_is_redcloth_or_wysiwyg
    page = @project.pages.create!(:name => 'page', :content => 'blah')
    assert_false page.redcloth
  end

  def test_formatted_content_leaves_in_silly_p_tags_for_wysiwyg_content
    page = @project.pages.create!(:name => 'silly p tags', :content => '<p>[[Page]]</p>')
    paragraphs = Nokogiri::HTML::DocumentFragment.parse(page.formatted_content(view_helper, {})).css("p")
    assert_equal 1, paragraphs.size
  end

  # bug 4604 -- this test will pass trivially on some db setups.  See card if you want details.
  def test_can_find_pages_with_russian_names
    @project.pages.create!(:name => 'Требования', :content => 'Something that a Russian person might say')
    page = Page.find_by_identifier(Page.name2identifier('Требования'))
    assert_equal 'Something that a Russian person might say', page.content
  end

  def test_send_history_notification_should_work_when_something
    with_new_project do |project|
      assert_nothing_raised { Page::Version.load_history_event(project, (1..1001).to_a) }
    end
  end
end
