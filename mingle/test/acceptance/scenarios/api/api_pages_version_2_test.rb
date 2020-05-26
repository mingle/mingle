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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')

# Tags: api_version_2, pages
class ApiPagesVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access


  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'page api test') do |project|
        project.pages.create(:name => 'with a link')
        project.pages.create(:name => 'page 2', :content => 'this is page 2')
        page3 = project.pages.create(:name => 'page 3')
        page3.update_attribute(:content, 'this is page 3')
        page3.attach_files(sample_attachment('attachment_for_page3.txt'))
        page3.save!
        page4 = project.pages.create(:name => 'page 4')
        page4.attach_files(sample_attachment('attachment_1.txt'))
        page4.attach_files(sample_attachment('attachment_2.txt'))
        page4.save!
      end
      @project.add_member(User.find_by_login('member'), :readonly_member)
    end

    API::Page.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::Page.prefix = "/api/#{version}/projects/#{@project.identifier}/"
    API::Project.prefix = "/api/#{version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_should_display_a_wiki_page
    page = API::Page.find('with_a_link')
    assert_equal 'with a link', page.name
  end

  def test_should_return_identifer_for_a_wiki_page
    page = API::Page.find('with_a_link')
    assert_equal 'with_a_link', page.identifier
  end

  def test_should_show_specific_version_page
    page = API::Page.find('page_3', :params => {:version => 1});
    assert_equal 1, page.version
    assert_nil page.content
    page = API::Page.find('page_3', :params => {:version => 2});
    assert_equal 2, page.version
    assert_equal 'this is page 3', page.content
  end

  def test_should_raise_record_not_found_when_cant_find_page_identifier
    assert_not_found { API::Page.find('this_page_does_not_exist.xml') }
  end

  def test_should_create_a_new_wiki_page
    API::Page.create(:name => 'I am a page', :content => 'I am content')
    page = API::Page.find('I_am_a_page')
    assert_equal 'I am a page', page.name
    assert_equal 'I am content', page.content
  end

  def test_should_return_location_when_create_a_new_wiki_page
    params = {'page[name]' => 'I am a new page'}
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki.xml")
    response = post(url, params)
    assert_equal "http://localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/I_am_a_new_page.xml", response.header['location']
  end

  def test_should_allow_the_content_to_be_updated
    page = @project.pages.first

    update_params = {'page[content]' => 'I am new content'}
    update_url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/#{page.identifier}.xml")
    response = put(update_url, update_params)

    assert_equal 'I am new content', page.reload.content
  end

  def test_should_get_list_of_pages
    pages = API::Page.find(:all)
    assert_equal ['page 2', 'page 3', 'page 4', 'with a link'], pages.collect(&:name).sort
    assert_equal ['page_2', 'page_3', 'page_4', 'with_a_link'], pages.collect(&:identifier).sort
    assert_equal ['this is page 2', 'this is page 3'].sort, pages.collect(&:content).compact.sort
  end

  def test_should_inform_when_no_pages_exist
    @project.pages.delete_all
    assert_equal [], API::Page.find(:all).collect(&:name)
  end

  def test_should_response_correct_error_message_when_trying_to_create_a_wiki_page_that_already_exists
    new_page = API::Page.new(:name => 'page 2', :content => 'some different content')
    assert !new_page.save
    assert_equal ["Name has already been taken"], new_page.errors.full_messages
  end

  def test_version_should_be_readonly
    assert_readonly('version', 10)
  end

  def test_created_at_should_be_readonly
    assert_readonly('created_at', '2005-03-04')
  end

  def test_should_upload_an_attachment
    sample_file = sample_attachment('sample_attachment.txt')
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_2/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal Net::HTTPCreated, response.class
    assert_equal 'sample_attachment.txt', @project.pages.find_by_name('page 2').attachments.first.file_name
    assert response.header['location'].ends_with?('sample_attachment.txt')
  end

  #bug 10258
  def test_upload_an_attachment_for_page_without_correct_username_and_password
    sample_file = sample_attachment('sample_attachment.txt')
    url = URI.parse("http://localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_2/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal Net::HTTPUnauthorized, response.class
    assert_equal 0, @project.pages.find_by_name('page 2').attachments.length
  end

  def test_upload_attachment_file_name_should_support_uppercase_and_space_and_other_special_characters
    sample_file = sample_attachment('Sample $%@ Attachemnt.txt')
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_2/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal Net::HTTPCreated, response.class
    assert response.header['location'].ends_with?("Sample_____Attachemnt.txt")
  end

  def test_should_delete_attachment_from_wiki_page
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_3/attachments/attachment_for_page3.txt")
    response = delete(url)
    assert_equal Net::HTTPAccepted, response.class
    assert @project.pages.find_by_name('page 3').attachments.empty?
  end

  def test_should_update_an_exist_attachment
    sample_file = another_sample_attachment("attachment_for_page3.txt")
    page_3 = @project.pages.find_by_name('page 3')
    start_version = page_3.version
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_3/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    page_3 = @project.pages.find_by_name('page 3')
    assert_equal start_version + 1, page_3.reload.version

    current_attachment = page_3.attachments.first.file
    previous_attachment = page_3.versions.detect { |pv| pv.version == start_version }.attachments.first.file
    assert_not_equal File.new(current_attachment).readline, File.new(previous_attachment).readline
  end

  def test_should_show_error_message_when_delete_an_not_exist_attachment
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_3/attachments/not_exist_attachment.txt")
    response = delete(url)
    assert_equal Net::HTTPNotFound, response.class
  end

  def test_should_return_404_error_when_the_post_url_is_invlid
    params = {'page[name]' => 'I am a new page'}
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/not_exist_uri.xml")
    response = post(url, params)
    assert_equal Net::HTTPNotFound, response.class
  end

  def test_should_return_404_error_when_the_put_url_is_invalid
    params = {'page[name]' => 'I am a new page'}
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/not_exist_identifier.xml")
    response = put(url, params)
    assert_equal Net::HTTPNotFound, response.class
  end

  def test_list_attachments
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_4/attachments.xml")
    response = get(url, {})
    assert_equal Net::HTTPOK, response.class

    first_attachment = @project.pages.find_by_identifier('page_4').attachments.first
    assert response.body.include?("<file_name>#{first_attachment.file_name}</file_name>")
    assert response.body.include?("<url>#{first_attachment.url}</url>")

    second_attachment = @project.pages.find_by_identifier('page_4').attachments[1]
    assert response.body.include?("<file_name>#{second_attachment.file_name}</file_name>")
    assert response.body.include?("<url>#{second_attachment.url}</url>")
  end

  # bug 7721
  def test_get_wiki_attachments_when_no_attachments_exist_should_have_attachments_as_root
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_2/attachments.xml")
    response = get(url, {})
    assert_equal 1, get_number_of_elements(response.body, "/attachments")
  end

  def test_get_an_attachment
    attachment = @project.pages.find_by_identifier('page_3').attachments.first
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/page_3/attachments/attachment_for_page3.txt")
    response = get(url, {})
    assert_equal Net::HTTPOK, response.class
    assert_equal File.new(attachment.file).readline.chomp, response.body.chomp
  end

  private

  def assert_readonly(attr_name, bad_value)
    new_page = API::Page.create(:name => 'this is a new name', attr_name.to_sym => bad_value, :content => 'I am content')
    new_page.reload
    assert_not_equal bad_value, new_page.send(attr_name)
    attr_value = new_page.send(attr_name)
    assert_equal attr_value, API::Page.find('this_is_a_new_name').send(attr_name)

    update_params = {"page[#{attr_name}]" => bad_value}
    update_url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/wiki/#{new_page.identifier}.xml")
    response = put(update_url, update_params)
    assert_not_equal bad_value, API::Page.find('this_is_a_new_name').send(attr_name)
  end

  def version
    'v2'
  end



  # story 11057
  def test_get_rendered_page_description
    project = create_project(:identifier => 'finance')

    login_as_admin
    page = project.pages.create!(:name => 'test',
                                 :content => "
    *As as ... I want to ... so that ....*
    h3. Acceptance Criteria")

    response = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}/wiki/#{page.identifier}.xml", {})
    page_content_url = get_attribute_by_xpath(response.body, "//page/rendered_description/@url").gsub(/localhost/, "admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost")

    page_render = get(page_content_url, {})
    assert_match(/<strong>As as &#8230; I want to &#8230; so that &#8230;.<\/strong>\n/, page_render.body)
    assert_match(/<h3>Acceptance Criteria<\/h3>/, page_render.body)
  end

  def test_project_id_should_be_readonly
    other_project = create_project(:identifier => 'notthisproject', :skip_activation => true)

    login_as_admin
    @project.activate
    page = @project.pages.create!(:name => 'flipadesk', :content => "（╯－＿－）╯╧╧")
    assert_not_equal other_project.identifier, @project.identifier

    response = update_page_via_api(page.identifier, 'page[project][identifier]' => other_project.identifier)
    assert_equal @project.identifier, get_element_text_by_xpath(response.body, "//page/project/identifier")
    assert_equal @project.id, page.reload.project.id

    response = update_page_via_api(page.identifier, 'page[project_id]' => other_project.id)
    assert_equal @project.identifier, get_element_text_by_xpath(response.body, "//page/project/identifier")
    assert_equal @project.id, page.reload.project.id
  end

  # bug 7721
  def test_get_pages_when_no_pages_exist_should_have_pages_as_root
    login_as_admin
    User.find_by_login('admin').with_current do
      with_new_project do |project|
        response = get("#{url_prefix(project)}/wiki.xml", {})
        assert_equal 1, get_number_of_elements(response.body, "/pages")
      end
    end
  end

  def test_modified_by_user_id_should_be_readonly
    login_as_admin
    page = @project.pages.create!(:name => 'sergeantbuckybeaver')
    original_user = page.modified_by
    other_user = User.find_by_login('bob')
    assert_not_equal other_user.login, page.modified_by.login

    response = update_page_via_api(page.identifier, 'page[modified_by][login]' => other_user.login)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//page/modified_by/login")
    assert_equal original_user.login, page.reload.modified_by.login

    response = update_page_via_api(page.identifier, 'page[modified_by_user_id]' => other_user.id)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//page/modified_by/login")
    assert_equal original_user.login, page.reload.modified_by.login
  end

  def test_created_by_is_readonly
    login_as_member
    page = @project.pages.create!(:name => 'sergeantbuckybeaver')
    original_user = page.created_by
    other_user = User.find_by_login('bob')
    assert_not_equal other_user.login, page.created_by.login

    response = update_page_via_api(page.identifier, 'page[created_by][login]' => other_user.login)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//page/created_by/login")
    assert_equal original_user.login, page.reload.created_by.login

    response = update_page_via_api(page.identifier, 'page[created_by_user_id]' => other_user.id)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//page/created_by/login")
    assert_equal original_user.login, page.reload.created_by.login
  end

  private

  def update_page_via_api(page_identifier, params)
    url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    put("#{url_prefix}/wiki/#{page_identifier}.xml", params)
  end

  def url_prefix(project)
    "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}"
  end

end
