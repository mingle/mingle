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

# Tags: cards, api_version_2
class ApiForCardsExecuteMqlTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')]) { |project| create_cards(project, 3) }
    end
    @project.add_member(User.find_by_login('bob'))
    API::Card.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    API::Card.prefix = "/api/v2/projects/#{@project.identifier}/"
    @url_prefix = url_prefix(@project)
    @no_api_version_url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}"
    @read_only_url_prefix = "http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
  end

  def teardown
    disable_basic_auth
  end

  def url_prefix(project)
    "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}"
  end

  def test_error_message_from_execute_mql_should_not_contain_html_tags
    setup_property_definitions :status => ['open', 'close']
    card = @project.cards.detect { |c| c.id != c.number }
    original_user = card.modified_by
    other_user = User.find_by_login('bob')
    assert_not_equal other_user.login, card.modified_by.login

    response = get("#{@url_prefix}/cards/execute_mql.xml", {'mql' => 'select name where status = new'})
    assert_equal "new is not a valid value for status, which is restricted to open and close", get_element_text_by_xpath(response.body, "/errors/error")

    response = get("#{@url_prefix}/cards/execute_mql.json", {'mql' => 'select name where status = new'})
    assert_equal({"errors" => ["new is not a valid value for status, which is restricted to open and close"]}, ActiveSupport::JSON::decode(response.body))
  end

  def test_can_get_execute_mql_results_in_json_form
    User.find_by_login('admin').with_current do
      setup_property_definitions :status => ['whoa', 'jeez']
      @project.cards.create!(:name => 'one', :card_type_name => 'Card', :cp_status => 'whoa')
      @project.cards.create!(:name => 'two', :card_type_name => 'Card', :cp_status => 'jeez')
    end

    response = get("#{@url_prefix}/cards/execute_mql.json", {'mql' => 'select name where status = whoa'})
    assert_equal [{"Name" => "one"}], ActiveSupport::JSON::decode(response.body)
    assert_equal 'application/json;charset=utf-8', response['Content-Type']
  end

  def test_can_get_execute_mql_results_in_jsonp_form
    User.find_by_login('admin').with_current do
      setup_property_definitions :status => ['whoa', 'jeez']
      @project.cards.create!(:name => 'one', :card_type_name => 'Card', :cp_status => 'whoa')
      @project.cards.create!(:name => 'two', :card_type_name => 'Card', :cp_status => 'jeez')
    end

    response = get("#{@url_prefix}/cards/execute_mql.json", {'mql' => 'select name where status = whoa', 'callback' => 'myMethod'})
    assert_equal "myMethod([{\"Name\":\"one\"}])", response.body
    assert_equal 'application/javascript;charset=utf-8', response['Content-Type']
  end

  def test_execute_mql_should_show_error_in_json_format_if_no_mql_argument_is_supplied
    response = get "#{@url_prefix}/cards/execute_mql.json", {}
    assert_equal '422', response.code
    assert_equal({'errors' => ["Parameter mql is required"]}, ActiveSupport::JSON::decode(response.body))
  end

  # bug 7861
  def test_execute_mql_should_422_if_no_mql_argument_is_supplied
    response = get "#{@url_prefix}/cards/execute_mql.xml", {}
    assert_equal '422', response.code
    assert_equal 'Parameter mql is required', get_element_text_by_xpath(response.body, "/errors/error")
  end

  # bug 7863, 8700
  def test_should_return_error_when_using_this_card
    login_as_admin
    UnitTestDataLoader.create_card_query_project("card_query_project_x").with_active_project do |project|
      url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}/cards/execute_mql"
      error_msg = "THIS CARD is not supported in MQL filters."

      assert_equal '422', get("#{url}.xml", {'mql' => "select number, name where number = this card.number"}).code
      assert_equal '422', get("#{url}.json", {'mql' => "select number, name where number = this card.number"}).code

      assert_equal error_msg, get_element_text_by_xpath(get("#{url}.xml", {'mql' => "select number, name where number = this card.number"}).body, "//errors/error")
      assert_equal error_msg, get_element_text_by_xpath(get("#{url}.xml", {'mql' => "select number, name where number in (3, this card.number)"}).body, "//errors/error")
      assert_equal error_msg, get_element_text_by_xpath(get("#{url}.xml", {'mql' => "select number, name where 'related card' = this card"}).body, "//errors/error")
      assert_equal error_msg, get("#{url}.json", {'mql' => "select number, name where date_created = this card.date_created"}).body.json_to_hash[:errors].first
    end
  end

  def test_distinct_should_return_result_without_duplications
    User.find_by_login('admin').with_current do
      setup_property_definitions :estimation => [2, 4, 6, 8]
      @project.cards.create!(:name => 'one', :card_type_name => 'Card', :cp_estimation => '2')
      @project.cards.create!(:name => 'two', :card_type_name => 'Card', :cp_estimation => '4')
      @project.cards.create!(:name => 'three', :card_type_name => 'Card', :cp_estimation => '4')
      @project.cards.create!(:name => 'three', :card_type_name => 'Card')
    end
    response = get("#{@url_prefix}/cards/execute_mql.json", {'mql' => 'select distinct estimation'})
    assert_equal [0, 2, 4], ActiveSupport::JSON::decode(response.body).collect { |r| r["estimation"].to_i }.sort
  end
end
