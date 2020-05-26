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

# Tags: cards, card-comments, api_version_2
class ApiForCardsCommentsTest < ActiveSupport::TestCase
  include XMLBuilderTestHelper

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')]) { |project| create_cards(project, 3) }
    end
  end

  def teardown
    disable_basic_auth
  end

  def version
    "v2"
  end

  def test_get_comments_of_a_card
    card = User.with_first_admin do
      card = create_card!(:name => 'new card')
      card.add_comment :content => "first comment"
      card.add_comment :content => "second comment"
      card
    end

    API::Comment.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/cards/#{card.number}/"
    API::Comment.prefix = "/api/#{version}/projects/#{@project.identifier}/cards/#{card.number}/"

    assert_sort_equal ["second comment", "first comment"], API::Comment.find(:all).collect(&:content)
  end

  def test_create_comment_for_a_card
    card = User.with_first_admin do
      create_card!(:name => 'new card')
    end

    API::Comment.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/cards/#{card.number}/"
    API::Comment.prefix = "/api/#{version}/projects/#{@project.identifier}/cards/#{card.number}/"
    API::Comment.create(:content => 'first comment')
    API::Comment.create(:content => 'second comment')
    assert_sort_equal ["second comment", "first comment"], API::Comment.find(:all).collect(&:content)
  end

  def test_should_return_404_when_card_is_not_found
    API::Comment.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/cards/1234567/"
    API::Comment.prefix = "/api/#{version}/projects/#{@project.identifier}/cards/1234567/"
    assert_not_found { API::Comment.find(:all) }
    assert_not_found { API::Comment.create(:content => 'something') }
  end

  # bug 7721
  def test_get_comments_when_no_comments_exist_should_have_comments_as_root
    card = User.with_first_admin do
      card = create_card!(:name => 'new card without comments')
      card.save!
      card
    end

    response = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/cards/#{card.number}/comments.xml", {})
    assert_equal 1, get_number_of_elements(response.body, "/card_comments")
  end

  # bug 7923
  def test_user_information_should_be_compacted
    card = User.with_first_admin do
      card = create_card!(:name => 'new card without comments')
      card.add_comment :content => "first comment"
      card
  end

    response = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}/cards/#{card.number}/comments.xml", {})

    assert_equal 2, elements_children_count_at(response.body, "/card_comments/comment/created_by")
  end

end
