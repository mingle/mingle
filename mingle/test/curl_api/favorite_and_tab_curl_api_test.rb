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

require File.expand_path(File.dirname(__FILE__) + '/curl_api_test_helper')

# Tags: api, cards
class FavoriteAndTabCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  STATUS = 'Status'
  SIZE = 'Size'
  STORY = 'Story'
  DEFECT = 'Defect'
  ITERATION = 'Iteration'
  VALID_VALUES_FOR_DATE_PROPERTY = [['01-05-07', '01 May 2007'], ['07/01/68', '07 Jan 2068'], ['1 august 69', '01 Aug 1969'], ['29 FEB 2004', '29 Feb 2004']]
  DATE_PROPERTY = 'modified on (2.3.1)'
  DATE_TYPE = 'Date'
  URL = 'url'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'WonderWorld') do |project|
        setup_numeric_property_definition(SIZE, [2, 4])
        setup_property_definitions(STATUS => ['new', 'open'])
        setup_date_property_definition(DATE_PROPERTY)
        setup_card_type(project, STORY, :properties => [STATUS, SIZE, DATE_PROPERTY])
        setup_card_type(project, ITERATION, :properties => [STATUS])
        card_favorite = CardListView.find_or_construct(project, :filters => ["[type][is][card]"])
        card_favorite.name = 'Cards Wall'
        card_favorite.save!
        page = project.pages.create!(:name => 'bonna page1'.uniquify, :content => "Welcome")
        page_favorite = project.favorites.create!(:favorited => page)
        create_cards(project, 3)
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_to_view_all_favorites
    url = project_base_url_for "favorites.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_match /<name>Cards Wall<\/name>/, output
    assert_match /<name>bonna page1/, output
    assert_match /type>CardListView<\/fav/, output
    assert_match /type>Page<\/fav/, output
  end

  def test_to_view_all_favorites_by_anon_user
    User.find_by_login('admin').with_current do
      @project.update_attribute :anonymous_accessible, true
      @project.save
    end
    change_license_to_allow_anonymous_access
    url = project_base_url_for "favorites.xml"
    output = %x[curl -X GET -i #{url}]
    assert_match /<name>Cards Wall<\/name>/, output
    assert_match /<name>bonna page1/, output
    assert_match /type>CardListView<\/fav/, output
    assert_match /type>Page<\/fav/, output
  end

  def test_view_favorites_via_api
    url = project_base_url_for "cards.xml?view=Cards+Wall"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    index_card_1 = output.index('card 1')
    index_card_2 = output.index('card 2')
    index_card_3 = output.index('card 3')

    assert index_card_3 > 0
    assert index_card_3 < index_card_2
    assert index_card_2 < index_card_1
  end

  def test_case_sensitivity_to_view_tabs_and_favorites_name
    url = project_base_url_for "cards.xml?view=CARDS+WALL"
    output = %x[curl -i #{url}]
    index_card_1 = output.index('card 1')
    index_card_2 = output.index('card 2')
    index_card_3 = output.index('card 3')

    assert index_card_3 > 0
    assert index_card_3 < index_card_2
    assert index_card_2 < index_card_1
  end

  def test_use_wrong_favorite_name
    wrong_url = cards_list_url :query => "view=Cards+wxeij"
    output2 = %x[curl -X GET -i #{wrong_url}]
    assert_response_code(404, output2)

    assert_not_include '<html>', output2

    #viewing tabs
  end

  def test_view_favorites_as_read_only_user
    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)

    url = cards_list_url :query => "view=Cards+wall", :user => login, :password => password
    output = %x[curl #{url} | xmllint --format -].tap { |output| raise "xml malformed!\n#{output}" unless $?.success? }
    index_card_1 = output.index('card 1')
    index_card_2 = output.index('card 2')
    index_card_3 = output.index('card 3')

    assert index_card_3 > 0
    assert index_card_3 < index_card_2
    assert index_card_2 < index_card_1
  end

end
