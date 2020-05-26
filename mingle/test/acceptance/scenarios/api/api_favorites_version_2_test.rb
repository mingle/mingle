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

# Tags: api_version_2, favorites
class ApiFavoritesVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') do |project|
        create_cards(project, 3)
        view = CardListView.construct_from_params(project, :tagged_with => 'story')
        view.name = 'Stories'
        view.save!
        view.tab_view = true
        view.save!
      end

    end
    @version="v2"
    API::Favorite.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::Favorite.prefix = "/api/#{@version}/projects/#{@project.identifier}/"

    API::Project.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/"
    API::Project.prefix = "/api/#{@version}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_can_get_list_of_cards
    @favorites = API::Favorite.find(:all)
    assert_equal ['Stories'], @favorites.collect(&:name)
    assert @favorites.first.tab_view?
    assert !@favorites.first.respond_to?(:favorited_id)
  end

  # bug 5254
  def test_should_return_404_when_the_view_is_not_exist
    url = URI.parse("#{API::Favorite.site}/cards.xml")
    response = get(url, {'view' => 'not_exist_view'})
    assert_equal Net::HTTPNotFound, response.class
  end

  # Bug 7721
  def test_get_favorites_when_none_exist_should_get_favorites_as_root_element
    project = with_new_project(:name => 'with no favorites') do |project|
      response = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{project.identifier}/favorites.xml", {})
      assert_equal 1, get_number_of_elements(response.body, "/favorites")
    end
  end

  # bug #10757 Favorites API includes personal favorites
  def test_list_should_not_include_personal_favorite_for_personal_admin
    login_as_admin
    user = create_user!(:name => 'black_ops')
    @project.add_member(user)
    login(user.email)
    @project.favorites.of_pages.personal(user).create(:favorited => @project.pages.create(:name => 'personal favorite'))

    xml = get("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}/favorites.xml", {}).body
    assert_equal 1, get_number_of_elements(xml, "/favorites/favorite")
    assert_not_equal 'personal favorite', get_elements_text_by_xpath(xml, "/favorites/favorite/name")
  end
end
