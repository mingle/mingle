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

class ApiForSortingCardsTest < ActiveSupport::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')], :users => [User.find_by_login('member')]) do |project|
        @first_card = create_card!(:name => 'F')
        @second_card = create_card!(:name => 'S')
        @third_card = create_card!(:name => 'T')
      end
    end
    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"
  end

  def test_should_rank_cards_on_project_card_rank

    User.find_by_login('admin').with_current do
      @third_card.rerank({:leading_card_number => @first_card.number, :following_card_number => @second_card.number})
    end

    body = get(@url_prefix + '/cards.xml', {"sort" => "project_card_rank", "order" => "ASC"}).body
    ordered_card_names = Hash.from_xml(body.to_s)['cards'].map { |card| card['name']}

    assert_not_nil get_element_text_by_xpath(body, "/cards")
    assert_equal ['F','T','S'], ordered_card_names
  end

  def teardown
    disable_basic_auth
  end

  def version
    "v2"
  end
end
