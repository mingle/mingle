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
class PropertyCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  STATUS = 'Status'
  SIZE = 'Size'
  STORY = 'Story'
  DEFECT = 'Defect'
  ITERATION = 'Iteration'
  HIDDEN = 'Hidden'
  VALID_VALUES_FOR_DATE_PROPERTY = [['01-05-07', '01 May 2007'], ['07/01/68', '07 Jan 2068'], ['1 august 69', '01 Aug 1969'], ['29 FEB 2004', '29 Feb 2004']]
  DATE_PROPERTY = 'modified on pro'
  DATE_TYPE = 'Date'
  URL = 'url'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'WonderWorld') do |project|
        setup_numeric_property_definition(SIZE, [2, 4])
        setup_property_definitions(STATUS => %w(new open))
        setup_date_property_definition(DATE_PROPERTY)
        prop = setup_numeric_property_definition(HIDDEN, [1, 2])
        prop.update_attributes(:hidden => true)
        setup_card_type(project, STORY, :properties => [STATUS, SIZE, DATE_PROPERTY, HIDDEN])
        setup_card_type(project, ITERATION, :properties => [STATUS])
        card_favorite = CardListView.find_or_construct(project, :filters => ["[type][is][card]"])
        card_favorite.name = 'Cards Wall'
        card_favorite.save!
        page = project.pages.create!(:name => 'bonna page1'.uniquify, :content => "Welcome")
        project.favorites.create!(:favorited => page)
        create_cards(project, 3)
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_admin_should_be_able_to_update_hidden_properties_via_api_v2_format
    proj_admin = users(:proj_admin)
    User.find_by_login('admin').with_current do
      @project.add_member(proj_admin, :project_admin)
    end

    card = @project.cards.first
    url = card_url_for(card)
    response = %x[curl -i -X PUT #{update_property(HIDDEN, 2009)} #{url}]

    assert_response_code(200, response)

    hidden_properties = collect_inner_text(response, "//property[@hidden='true']")
    assert hidden_properties.include?("#{HIDDEN} 2009")

    url = card_url_for(card, :user => "proj_admin")
    response = %x[curl -i -X PUT #{update_property(HIDDEN, 2010)} #{url}]

    assert_response_code(200, response)

    hidden_properties = collect_inner_text(response, "//property[@hidden='true']")
    assert hidden_properties.include?("#{HIDDEN} 2010")
  end

  # Bug 7708
  def test_view_property_definition
    output = %x[curl -X GET #{property_definitions_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<property_definitions/ && output =~ /<property_definition>/, "expected <property_definitions> to be root element with child nodes of <property_definition>"
    assert output =~ /cp_size/ && output =~ /cp_status/ && output =~ /cp_modified_on_pro/, "Expected properties are not listed."
  end

  pending "bjanakir - This appears to be broken by check-in: http://bjcruise.thoughtworks.com:8153/cruise/tab/build/detail/Mingle_trunk--CentOS5-Oracle10g/927/Acceptances/1/Curl#tab-failures"

  def test_to_update_card_name_and_properties_by_read_only_user
    card = create_card_by_api_v2
    assert_equal 'new story', card.name

    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)

    url = card_url_for(card, :user => login, :password => password)
    output = %x[curl -X PUT -i -d "card[name]=updated story" #{update_property(SIZE, 4)} #{url}]

    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_update_card_properties
    card = create_card_by_api_v2
    assert_equal 'new story', card.name

    url = card_url_for(card)
    %x[curl -X PUT #{update_property(STATUS, "open")} #{update_property(SIZE, 4)} #{url}]
    card.reload

    assert_equal 'open', card.cp_status
    assert_equal '4', card.cp_size

    # set a property to new enum value. this should create new enum value for property
    %x[curl -X PUT #{update_property(STATUS, "closed")} #{url}]
    card.reload
    assert_equal 'closed', card.cp_status
  end

  def test_should_be_able_to_update_hidden_properties
    card = create_card_by_api_v2
    url = card_url_for(card)
    %x[curl -X PUT #{update_property(HIDDEN, 1)} #{url}]
    card.reload
    assert_equal '1', card.cp_hidden
    %x[curl -X PUT #{update_property(HIDDEN, 2)} #{url}]
    card.reload
    assert_equal '2', card.cp_hidden
  end

  def test_filter_by_properties
    create_card_by_api_v2('new story', STORY)

    2.times do |index|
      create_card_by_api_v2("Iteration #{index}", ITERATION)
    end

    output = %x[curl -G -d "filters[]=[type][is][Iteration]" #{cards_list_url}]
    assert_response_includes("Iteration 0", output)
    assert_response_includes("Iteration 1", output)
    assert_not_include 'Story', output
    assert_not_include 'Card 1', output
  end

  def test_error_messages_for_numeric_property
    card = create_card_by_api_v2
    assert_equal 'new story', card.name

    url = card_url_for(card)
    output = %x[curl -X PUT -i #{update_property(SIZE, "dfsdf")} #{url}]
    assert_response_code(422, output)
    assert_response_includes('invalid', output) # DO WE WANT TO LOG BUG ABOUT THIS - WE DO NOT PROVIDE READABLE ERROR MESSAGE.
    assert_not_include '<html>', output
  end

  def test_error_messages_for_date_property
    card = create_card_by_api_v2
    assert_equal 'new story', card.name

    url = card_url_for(card)
    output = %x[curl -X PUT -i #{update_property(DATE_PROPERTY, "two")} #{url}]
    assert_response_code(422, output)
    assert_response_includes('invalid', output)
    assert_not_include '<html>', output
  end

end
