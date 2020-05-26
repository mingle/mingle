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
class CardCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  STATUS = 'Status'
  SIZE = 'Size'
  STORY = 'Story'
  ITERATION = 'Iteration'
  VALID_VALUES_FOR_DATE_PROPERTY = [['01-05-07', '01 May 2007'], ['07/01/68', '07 Jan 2068'], ['1 august 69', '01 Aug 1969'], ['29 FEB 2004', '29 Feb 2004']]
  DATE_PROPERTY = 'modified on (2.3.1)'
  DATE_TYPE = 'Date'
  URL = 'url'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'WonderWorld', :users => [User.find_by_login('member')]) do |project|
        setup_numeric_property_definition(SIZE, [2, 4])
        setup_property_definitions(STATUS => ['new', 'open'])
        setup_date_property_definition(DATE_PROPERTY)
        setup_user_definition('owner')
        setup_card_type(project, STORY, :properties => [STATUS, SIZE, DATE_PROPERTY])
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


  # bug 8993
  def test_should_return_card_type_url_when_get_single_card_via_api_v2_format
    url = project_base_url_for "cards", "1.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    card_type = @project.card_types.find_by_name("Card")
    card_type_url = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/card_types/#{card_type.id}.xml"
    assert_equal card_type_url, get_attribute_by_xpath(output, "//card/card_type/@url")
  end

  def test_error_message_when_delete_attachment_for_card_use_old_api_format
    url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}/cards/3/attachments"
    output = %x[curl -i -X DELETE "#{url}/not_exist.jpg"]
    assert_response_code(410, output)
    assert_include('<message>The resource URL has changed. Please use the correct URL.</message>', output)
  end

  def test_slack_endpoints_with_team_id_get_redirected_to_projects
    with_saas_env_set do
      url ="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/slack/teams/#{@project.groups.first.id}/cards.xml"
      output = %x[curl -H 'MINGLE_API_KEY: some_key' -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes('<number type="integer">3<', output)
      assert_response_includes('<number type="integer">2<', output)
      assert_response_includes('<number type="integer">1<', output)
    end
  end

  def test_slack_endpoints_with_invalid_team_id_gets_error_response
    with_saas_env_set do
      url ="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/slack/teams/9999999/cards.xml"
      output = %x[curl -H 'MINGLE_API_KEY: some_key' -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
    end
  end

  def test_slack_endpoints_with_missing_mingle_api_key_gets_error_response
    with_saas_env_set do
      url ="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/slack/teams/#{@project.groups.first.id}/cards.xml"
      output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
      assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output)
    end
  end

  # bug 7642
  def test_full_member_can_not_add_new_value_for_locked_property
    property = @project.find_property_definition(STATUS)
    User.find_by_login('admin').with_current do
      property.update_attributes(:restricted => true)
    end

    url = project_base_url_for "cards", "1.xml", :user => "member"
    output = %x[curl -X PUT #{update_property(STATUS, "closed")} #{url}]
    expected_error = '<error>Status is restricted to new and open</error>'
    assert_response_includes(expected_error, output)

    url = property_definition_url_for property
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_not_include('<value>closed</value>', output)
  end

  def test_readonly_user_and_anon_user_should_not_be_able_to_update_card_via_api_v2_format
    User.find_by_login('admin').with_current do
      @project.update_attribute(:anonymous_accessible, true)
      @project.save
    end
    change_license_to_allow_anonymous_access

    read_only_user = users(:read_only_user)
    @project.add_member(read_only_user, :readonly_member)

    url_anon = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1.xml"
    output_anon = %x[curl -i -X PUT -d card[name]='update card by a anon user' #{url_anon}]
    assert_response_code(403, output_anon)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output_anon)

    output1 = %x[curl "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1.xml" | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_not_include('<name>update card by a anon user</name>', output1)

    url_read_only = "http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1.xml"
    output_read_only = %x[curl -i -X PUT -d card[name]='update card by a readonly user' #{url_read_only}]
    assert_response_code(403, output_read_only)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output_read_only)

    output2 = %x[curl "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1.xml" | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_not_include('<name>update card by a readonly user', output2)
  end

  def test_update_properties_with_v2_api_format
    card = create_card_by_api_v2
    url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml"
    output = %x[curl -X PUT -d "card[properties][][name]=status&card[properties][][value]=closed" #{url}]
    assert_response_includes('<name>status<', output)
    assert_response_includes('<value>closed<', output)
  end

  def test_get_all_cards_with_v2_api_format
    url ="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<number type="integer">3<', output)
    assert_response_includes('<number type="integer">2<', output)
    assert_response_includes('<number type="integer">1<', output)
  end

  def test_create_new_card_with_v2_api_format
    url ="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards.xml"
    output = %x[curl -X POST -i -d "card[name]=another new story" -d "card[description]=new description : {{project}}" -d "card[card_type_name]=story" #{url}]
    assert_response_code(201, output)
    assert_equal "new description : #{@project.identifier}", @project.cards.find_by_name("another new story").formatted_content(FakeViewHelper.new)
  end

  def test_limit_to_view_single_card_list_page
    26.times do |index|
      create_card_by_api_v2("Story #{index}", STORY)
    end

    url = project_base_url_for "cards.xml?page=1"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<number type="integer">7<', output)
    assert_response_includes('<number type="integer">6<', output)
    assert_response_includes('<number type="integer">5<', output)
    assert_not_include '<number type="integer">4<', output
    assert_not_include '<number type="integer">3<', output
    assert_not_include '<number type="integer">2<', output
    assert_not_include '<number type="integer">1<', output
  end

  def test_page_size_limits_number_of_cards_on_page
    6.times do |index|
      create_card_by_api_v2("Story #{index}", STORY)
    end
    url = project_base_url_for "cards.xml?page=1&page_size=3"
    output = %x[curl '#{url}' | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_response_includes('<number type="integer">9<', output)
    assert_response_includes('<number type="integer">8<', output)
    assert_response_includes('<number type="integer">7<', output)
    assert_not_include '<number type="integer">6<', output
    assert_not_include '<number type="integer">5<', output
    assert_not_include '<number type="integer">4<', output
  end

  def test_page_count_is_displayed_only_if_show_page_count_attribute_is_set
    6.times do |index|
      create_card_by_api_v2("Story #{index}", STORY)
    end
    url = project_base_url_for "cards.xml?page=1&page_size=4"
    output = %x[curl '#{url}' | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_not_include('page_count="2"', output)

    url = project_base_url_for "cards.xml?page=1&page_size=4&show_page_count=true"
    output = %x[curl '#{url}' | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('page_count="3"', output)
  end

  def test_to_view_beyond_existing_card_list_page
    26.times do |index|
      create_card_by_api_v2("Story #{index}", STORY)
    end

    url = project_base_url_for "cards.xml?page=1000"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<number type="integer">4<', output)
    assert_response_includes('<number type="integer">3<', output)
    assert_response_includes('<number type="integer">2<', output)
    assert_response_includes('<number type="integer">1<', output)
  end

  def test_wrong_login_or_password
    wrong_login_name = projects_list_url :user => "amin"
    output = %x[curl -i #{wrong_login_name}]
    assert_response_code(401, output) #401 unauthorized

    wrong_password = projects_list_url :password => "test13"
    output2 = %x[curl -i #{wrong_password}]
    assert_response_code(401, output2)

    wrong_login_password = projects_list_url :user => "amin", :password => "test13"
    output3 = %x[curl -i #{wrong_login_password}]
    assert_response_code(401, output3)
  end

  def test_to_create_card_by_read_only_user
    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)

    url = cards_list_url :user => login, :password => password
    output = %x[curl -X POST -i -d "card[name]=new card" -d "card[card_type_name]=card" #{url}]
    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_to_create_card_by_anon_user
    User.find_by_login('admin').with_current do
      @project.update_attribute :anonymous_accessible, true
      @project.save
    end
    change_license_to_allow_anonymous_access
    url = cards_list_url :user => nil
    output = %x[curl -X POST -i -d "card[name]=new card" -d "card[card_type_name]=card" #{url}]
    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_update_old_version_of_card
    card = create_card_by_api_v2
    assert_equal 'new story', card.name

    %x[curl -X PUT #{update_property("status", "open")} #{update_property("size", "4")} #{card_url_for card}]

    card.reload
    assert_equal 2, card.version

    url = project_base_url_for "cards", "#{card.number}.xml?version=1"
    output = %x[curl -X PUT -i #{update_property("status", "closed")} #{url}]
    assert_response_code(403, output) #403 forbidden. is it good status code for this case?
  end

  def test_update_and_view_non_existing_card
    #card id is used (for PUT and POST)
    url = project_base_url_for "cards", "#{Card.maximum(:number) + 1}.xml"

    # try to update non_existing card
    output = %x[curl -i -X PUT #{update_property(STATUS, "open")} #{url}]
    assert_response_code(404, output)

    # try to view non_existing card
    output = %x[curl -i #{url}]
    assert_response_code(404, output)

    assert_not_include '<html>', output
  end

  def test_to_view_single_existing_card
    #card number is used (for GET)
    url = project_base_url_for "cards", "1.xml"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes("<name>card 1</name>", output)
  end

  def test_error_messages_when_using_old_api_format_to_update
    old_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}/cards/1.xml"

    output = %x[curl -i -X PUT -d "card[cp_status]=open" #{old_url}]
    assert_response_code(410, output)
    assert_response_includes("The resource URL has changed. Please use the correct URL", output)
  end

  def test_create_card
    create_card_by_api_v2('new_story', STORY)

    card = Card.find_by_name('new_story')
    assert_not_nil card
    assert_equal 'Story', card.card_type_name
  end

  def test_create_card_when_include_defaults_is_set_to_true
    card_type = @project.card_types.find_by_name("Story")
    card_defaults = card_type.card_defaults

    status_default = 'new'
    dev_default = @project.users.first.id

    card_defaults.update_properties :Status => status_default, :dev => dev_default
    card_defaults.save!


    url ="http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards.xml"
    output = %x[curl -X POST -i -d "card[name]=new_story" -d "card[description]=new description : {{project}}" -d "card[card_type_name]=story" -d "include_defaults=true" #{url}]

    new_card = @project.cards.last
    assert_equal 'new', new_card.cp_status

  end


  def test_should_not_allow_to_update_user_property_when_the_user_is_not_team_member
    login_as_admin
    member = @project.users.find_by_login('member')
    not_member = User.find_by_login('first')
    card = create_card!(:name => 'I am card', :owner => member.id)

    url = project_base_url_for "cards", "#{card.number}.xml"
    output = %x[curl -X PUT #{update_property("owner", not_member.login)} #{url}]
    assert_response_includes("is not a project member", output)
  end

  def test_should_get_murmurs_on_card_via_api
    login_as_member
    card = create_card!(:name => 'I am card')
    murmur = create_murmur(:murmur => "I am murmur for ##{card.number}")
    CardMurmurLink.create!(:project => @project, :card => card, :murmur => murmur)

    url = project_base_url_for "cards", "#{card.number}", "murmurs.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "I am murmur for ##{card.number}", get_element_text_by_xpath(output, "/murmurs/murmur/body")
  end

  def test_should_truncate_large_murmur_when_get_murmurs_on_card_via_api
    login_as_member
    card = create_card!(:name => 'I am card')
    murmur = create_murmur(:murmur => "I am murmur for ##{card.number}, and I'm #{'really' * 200} large")
    CardMurmurLink.create!(:project => @project, :card => card, :murmur => murmur)

    url = project_base_url_for "cards", "#{card.number}", "murmurs.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 997, get_element_text_by_xpath(output, "/murmurs/murmur/body").length
    assert_equal "true", get_element_text_by_xpath(output, "/murmurs/murmur/is_truncated")
  end

  def test_should_fetch_all_murmurs_posted_on_cards_via_api
    login_as_member
    card = create_card!(:name => 'I am card')
    murmur = create_murmur(:murmur => 'I am a murmur without any card number reference')
    CardMurmurLink.create!(:project => @project, :card => card, :murmur => murmur)

    url = project_base_url_for "cards", "#{card.number}", "murmurs.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'I am a murmur without any card number reference', get_element_text_by_xpath(output, "/murmurs/murmur/body")
  end

  def test_should_give_empty_murmurs_array_when_card_has_no_murmur
    login_as_member
    card = create_card!(:name => 'I am card')
    url = project_base_url_for "cards", "#{card.number}", "murmurs.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'murmurs', get_root_element_name(output)
    assert_equal 0, get_number_of_elements(output, "/murmurs/murmur")
  end

  def test_should_give_transition_ids_when_include_transition_ids_param_is_true
    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'not set'})
    url = project_base_url_for "cards", "1.xml"
    output = %x[curl -X GET -d include_transition_ids=true #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_response_includes("<transition_ids>#{new_transition.id}</transition_ids>", output)
  end

  def test_should_not_give_transition_ids_when_params_does_not_contain_include_transitions_ids
    new_transition = create_transition(@project, 'sample transition', :set_properties => {STATUS => 'not set'})
    url = project_base_url_for "cards", "1.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    assert_absent_in_response("<transition_ids>#{new_transition.id}</transition_ids>", output)
  end

  def test_should_return_relevant_transition_ids_for_a_particular_card_state
    login_as_admin
    notset_transition = create_transition(@project, 'notset transition', :required_properties => {STATUS => 'not set'}, :set_properties => {STATUS => 'new'})
    new_card_transition = create_transition(@project, 'new transition', :required_properties => {STATUS => 'new'}, :set_properties => {STATUS => 'open'})
    open_card_transition = create_transition(@project, 'open transition', :required_properties => {STATUS => 'open'}, :set_properties => {STATUS => 'not set'})

    url = project_base_url_for 'cards', '1.xml'
    output = %x[curl -X GET -d include_transition_ids=true #{url} | xmllint --format -].tap { raise 'xml malformed!' unless $?.success? }

    assert_absent_in_response("<transition_ids>#{notset_transition.id}</transition_ids>", output)

    card1 = create_card!(:name => 'card1', :status=> 'new')
    card2 = create_card!(:name => 'card2', :status=> 'open')
    card3 = create_card!(:name => 'card3', :status=> 'not set')

    execute_curl_card_api_with_transition_ids(card1, new_card_transition)
    execute_curl_card_api_with_transition_ids(card2, open_card_transition)
    execute_curl_card_api_with_transition_ids(card3, notset_transition)
  end

  pending 'need to discuss the expected behavior again'
  # bug 7641
  def test_full_member_should_not_be_able_to_upate_hidden_properties_via_api_v2_format
    login_as_admin
    status = @project.all_property_definitions.find_by_name(STATUS)
    status.update_attributes(:hidden => true)

    card = create_card_by_api_v2
    url = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml"
    output = %x[curl -i -X PUT #{update_property(STATUS, 1)} #{url}]
    assert_response_code(200, output)
  end

  private
  def execute_curl_card_api_with_transition_ids(card, expected_transition)
    url = project_base_url_for 'cards', card.number.to_s + '.xml'
    output = %x[curl -X GET -d include_transition_ids=true #{url} | xmllint --format -].tap { raise 'xml malformed!' unless $?.success? }
    assert_response_includes("<transition_ids>#{expected_transition.id}</transition_ids>",output)
  end
end
