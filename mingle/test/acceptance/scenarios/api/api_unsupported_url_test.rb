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

# Tags: api_version_2
class ApiUnsupportedUrlTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'unsupported api test') do |project|
        project.cards.create!(:name => 'first card', :card_type_name => 'Card')
      end
      @project.add_member(User.find_by_login('member'), :readonly_member)
    end

    @no_api_version_url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}"
    @no_api_version_url_member_prefix = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}"
  end

  def test_get_card_types_list
    assert_get_404("#{@no_api_version_url_prefix}/card_types.xml")
    assert_get_404("#{@no_api_version_url_member_prefix}/card_types.xml")
  end

  def test_show_card_type
    type_card = @project.card_types.find_by_name('Card')
    assert_get_404("#{@no_api_version_url_prefix}/card_types/#{type_card.id}.xml")
    assert_get_404("#{@no_api_version_url_member_prefix}/card_types/#{type_card.id}.xml")
  end

  def test_get_page
    login_as_member
    @project.pages.create!(:name => 'eggybread')
    assert_get_410("#{@no_api_version_url_prefix}/wiki/eggybread.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/wiki/eggybread.xml")
  end

  def test_update_page
    login_as_member
    page = @project.pages.create!(:name => 'eggybread', :content => 'original content')
    assert_put_410("#{@no_api_version_url_prefix}/wiki/eggybread.xml", 'page[content]' => 'new page content')
    assert_put_410("#{@no_api_version_url_member_prefix}/wiki/eggybread.xml", 'page[content]' => 'new page content')
    assert_equal "original content", page.reload.content
  end

  def test_create_page
    assert_post_410("#{@no_api_version_url_prefix}/wiki.xml", 'page[name]' => 'new page')
    assert_post_410("#{@no_api_version_url_member_prefix}/wiki.xml", 'page[name]' => 'new page')
    assert_nil @project.pages.find_by_name('new page')
  end

  def test_get_page_list
    login_as_member
    page = @project.pages.create!(:name => 'sergeantbuckybeaver')
    assert_get_410("#{@no_api_version_url_prefix}/wiki.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/wiki.xml")
  end

  def test_get_projects
    with_new_project do |project|
      assert_get_410 URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{project.identifier}.xml")
      assert_get_410 URI.parse("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{project.identifier}.xml")
      assert_get_410 URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects.xml")
      assert_get_410 URI.parse("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects.xml")
      assert_get_410 URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/lightweight_projects/#{project.identifier}.xml")
    end
  end

  def test_create_project
    assert_post_410("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects.xml", 'project[name]' => 'More test', 'project[identifier]' => 'more_test')
    assert_post_410("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects.xml", 'project[name]' => 'More test', 'project[identifier]' => 'more_test')
  end

  def test_get_card_attachments_list
    card = @project.cards.first
    sample_file = sample_attachment('Sample $%@ Attachemnt.txt')
    url = URI.parse("#{@no_api_version_url_prefix}/cards/#{card.number}/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal "410", response.code.to_s
    assert_include "The resource URL has changed. Please use the correct URL.", response.body
  end

  def test_get_card_attachment
    card = @project.cards.first
    User.find_by_login('admin').with_current do
      card.attach_files(sample_attachment('attachment_for_card.txt'))
      card.save
    end
    assert_get_410("#{@no_api_version_url_prefix}/cards/#{card.number}/attachments/attachment_for_card.txt")
    assert_get_410("#{@no_api_version_url_member_prefix}/cards/#{card.number}/attachments/attachment_for_card.txt")
  end

  def test_get_wiki_attachment
    login_as_member
    page = @project.pages.create!(:name => 'ninjabuckybeaver')
    User.find_by_login('admin').with_current do
      page.attach_files(sample_attachment('attachment_for_card.txt'))
      page.save
    end

    assert_get_410("#{@no_api_version_url_prefix}/wiki/#{page.identifier}/attachments/attachment_for_card.txt")
    assert_get_410("#{@no_api_version_url_member_prefix}/wiki/#{page.identifier}/attachments/attachment_for_card.txt")
  end

  def test_upload_attachment
    login_as_member
    page = @project.pages.create!(:name => 'ninjabuckybeaver')
    sample_file = sample_attachment('Sample $%@ Attachemnt.txt')
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}/wiki/#{page.identifier}/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal "410", response.code.to_s
    assert_include "The resource URL has changed. Please use the correct URL.", response.body

    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}/cards/1/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal "410", response.code.to_s
    assert_include "The resource URL has changed. Please use the correct URL.", response.body

  end


  def test_get_favorite_list
    assert_get_410("#{@no_api_version_url_prefix}/favorites.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/favorites.xml")
  end

  def test_create_subversion_configuration
    assert_post_410("#{@no_api_version_url_prefix}/subversion_configurations.xml",
                    'subversion_configuration[username]' => 'test',
                    'subversion_configuration[password]' => "password",
                    'subversion_configuration[repository_path]' => "/a_repos")
    assert_post_410("#{@no_api_version_url_member_prefix}/subversion_configurations.xml",
                    'subversion_configuration[username]' => 'test',
                    'subversion_configuration[password]' => "password",
                    'subversion_configuration[repository_path]' => "/a_repos")
  end

  def test_get_subversion_configuration
    assert_get_410("#{@no_api_version_url_prefix}/subversion_configurations.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/subversion_configurations.xml")
  end

  def test_update_subversion_configuration
    assert_put_410("#{@no_api_version_url_prefix}/subversion_configurations/1.xml", {})
    assert_put_410("#{@no_api_version_url_member_prefix}/subversion_configurations/1.xml", {})
  end

  def test_get_project_team_members
    assert_get_410("#{@no_api_version_url_prefix}/users.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/users.xml")
  end

  def test_get_user
    user = @project.users.first
    assert_get_410("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users/#{user.id}.xml")
    assert_get_410("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users/#{user.id}.xml")
  end

  def test_get_users
    assert_get_410("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users.xml")
    assert_get_410("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users.xml")
  end

  def test_create_users
    assert_post_410("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users.xml", 'user[name]' => 'John Smith', 'user[login]' => 'JohnSmith', 'user[password]' => 'JohnSmith', 'user[password_confirmation]' => 'JohnSmith')
    assert_post_410("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users.xml", 'user[name]' => 'John Smith', 'user[login]' => 'JohnSmith', 'user[password]' => 'JohnSmith', 'user[password_confirmation]' => 'JohnSmith')
  end

  def test_update_users
    user = @project.users.first
    assert_post_410("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users/#{user.id}.xml", 'user[name]' => 'John Smith', 'user[login]' => 'JohnSmith', 'user[password]' => 'JohnSmith', 'user[password_confirmation]' => 'JohnSmith')
    assert_post_410("http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/users/#{user.id}.xml", 'user[name]' => 'John Smith', 'user[login]' => 'JohnSmith', 'user[password]' => 'JohnSmith', 'user[password_confirmation]' => 'JohnSmith')
  end

  def test_get_property_definitions
    assert_get_410("#{@no_api_version_url_prefix}/property_definitions.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/property_definitions.xml")
  end

  def test_create_card
    params = {'card[number]' => 10000, 'card[name]' => "created by rest api", 'card[card_type_name]' => "Card"}
    assert_post_410("#{@no_api_version_url_prefix}/cards.xml", params)
    assert_post_410("#{@no_api_version_url_member_prefix}/cards.xml", params)
    assert_nil @project.cards.find_by_number(10000)
  end

  def test_update_card
    card = @project.cards.find_by_number(1)
    new_card_name = "updated card hey-o"
    assert_put_410("#{@no_api_version_url_prefix}/cards/#{card.id}.xml", 'card[name]' => new_card_name)
    assert_put_410("#{@no_api_version_url_member_prefix}/cards/#{card.id}.xml", 'card[name]' => new_card_name)
    assert card.name != new_card_name
  end

  def test_get_card
    card = @project.cards.find_by_number(1)
    assert_get_410("#{@no_api_version_url_prefix}/cards/#{card.id}.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/cards/#{card.id}.xml")
  end

  def test_get_cards
    assert_get_410("#{@no_api_version_url_prefix}/cards.xml")
    assert_get_410("#{@no_api_version_url_member_prefix}/cards.xml")
  end

  def test_execute_transition
    assert_post_410("#{@no_api_version_url_prefix}/transition_executions.xml", "transition_execution[transition]" => 'some transition', "transition_execution[card]" => 1)
    assert_post_410("#{@no_api_version_url_member_prefix}/transition_executions.xml", "transition_execution[transition]" => 'some transition', "transition_execution[card]" => 1)
  end

  def test_version_2_of_transition_execution_should_not_work_with_id
    assert_post_410("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/transition_executions.xml", "transition_execution[card]" => 1, "transition_execution[transition]" => 'some transition')
  end

  private

  def assert_get_410(url)
    response = get(url, {})
    assert_equal '410', response.code.to_s
    assert_include "The resource URL has changed. Please use the correct URL.", response.body
  end

  def assert_put_410(url, params)
    response = put(url, params)
    assert_equal '410', response.code.to_s
    assert_include "The resource URL has changed. Please use the correct URL.", response.body
  end

  def assert_post_410(url, params)
    response = post(url, params)
    assert_equal '410', response.code.to_s
    assert_include "The resource URL has changed. Please use the correct URL.", response.body
  end

  def assert_get_404(url)
    response = get(url, {})
    assert_equal '404', response.code.to_s
  end

  def assert_post_404(url, params)
    response = post(url, params)
    puts response.body
    assert_equal '404', response.code.to_s
  end


end
