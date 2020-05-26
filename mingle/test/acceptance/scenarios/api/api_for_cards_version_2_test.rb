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
class ApiForCardsVersion2Test < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra', :read_only_users => [User.find_by_login('read_only_user')]) { |project| create_cards(project, 3) }
    end
    @project.add_member User.find_by_login('bob')
    API::Card.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    API::Card.prefix = "/api/v2/projects/#{@project.identifier}/"
    @url_prefix = url_prefix(@project)
    @no_api_version_url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}"
    @read_only_url_prefix = "http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
  end

  def teardown
    disable_basic_auth
  end

  # story 11057
  def test_get_redcloth_rendered_card_description
    login_as_admin
    card = create_card!(:name => 'sample card',
                        :description => "
    As as ... I want to ... so that ....
    Acceptance Criteria")
    response = get("#{@url_prefix}/cards/#{card.number}.xml", {})
    card_content_url = get_attribute_by_xpath(response.body, "//card/rendered_description/@url").gsub(/localhost/, "admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost")

    card_render = get(card_content_url, {})
    assert_match(/As as ... I want to ... so that ....\n/, card_render.body)
    assert_match(/Acceptance Criteria/, card_render.body)
  end

  # story 11057
  def test_get_rendered_card_description
    login_as_admin
    card = create_card!(:name => 'sample card', :description => "{{ project }}")
    response = get("#{@url_prefix}/cards/#{card.number}.xml", {})
    card_content_url = get_attribute_by_xpath(response.body, "//card/rendered_description/@url").gsub(/localhost/, "admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost")

    card_render = get(card_content_url, {})
    assert_match(/zebra/, card_render.body)
  end

  def test_can_get_list_of_cards
    all_cards = get("#{@url_prefix}/cards.xml", {}).body
    card_names = get_elements_by_xpath(all_cards, '//cards/card/name').map(&:text)
    assert_equal ['card 3', 'card 2', 'card 1'], card_names
  end

  def test_update_simple_card_attribute_by_number
    card = @project.cards.detect { |c| c.id != c.number }
    response = update_card_via_api(card.number, 'card[name]' => 'updated card')
    assert_equal "updated card", card.reload.name
  end

  def test_should_update_card_relationship_properties_by_number
    card_dependency_property = setup_card_relationship_property_definition('card dependency')
    card = @project.cards.detect { |c| c.id != c.number }
    response = update_card_via_api(card.number, 'card[name]' => 'updated card', "card[properties][][name]" => 'card dependency', "card[properties][][value]" => card.number)
    assert_equal card, card_dependency_property.value(card.reload)
  end

  def test_create_card
    create_card_via_api('card[number]' => 10000, 'card[name]' => "created by rest api", 'card[card_type_name]' => "Card")
    new_card = @project.cards.find_by_number(10000)
    assert new_card
    assert_equal 'created by rest api', new_card.name
    assert_equal 'Card', new_card.card_type_name
  end

  def test_create_card_with_properties_in_old_format
    setup_managed_text_definition 'status', ['open', 'closed']
    create_card_via_api('card[number]' => 10000, 'card[name]' => "created by rest api", 'card[card_type_name]' => "Card", "properties[status]" => 'open')
    new_card = @project.cards.find_by_number(10000)
    assert new_card
    assert_equal 'created by rest api', new_card.name
    assert_equal 'open', new_card.cp_status
  end

  def test_create_card_with_properties_in_new_format
    setup_managed_text_definition 'status', ['open', 'closed']
    card_dependency_property = setup_card_relationship_property_definition('card dependency')
    value_card = @project.cards.detect { |c| c.id != c.number }
    create_card_via_api('card[number]' => 10000,
                        'card[name]' => "created by rest api",
                        'card[card_type_name]' => "Card",
                        "card[properties][][name]" => 'card dependency',
                        "card[properties][][value]" => value_card.number)

    new_card = @project.cards.find_by_number(10000)
    assert new_card
    assert_equal 'created by rest api', new_card.name
    assert_equal value_card, card_dependency_property.value(new_card)
  end

  def test_update_card_with_properties_not_related_with_card_type
    User.with_first_admin do
      setup_managed_text_definition 'status', ['open', 'closed']
      @story = @project.card_types.create(:name => 'story')
      @card = create_card!(:name => 'card name', :card_type => @story)
    end
    response = update_card_via_api(@card.number, 'card[name]' => 'updated card', "card[properties][][name]" => 'status', "card[properties][][value]" => 'closed')
    assert_equal "422", response.code
    assert_equal 'status is not being applicable to card type story', get_element_text_by_xpath(response.body, '/errors/error')
  end

  def test_create_card_with_multiple_properties_in_new_format
    setup_managed_text_definition 'status', ['open', 'closed']
    card_dependency_property = setup_card_relationship_property_definition('card dependency')
    value_card = @project.cards.detect { |c| c.id != c.number }

    url = URI.parse("#{@url_prefix}/cards.xml")
    request = Net::HTTP::Post.new(url.path)
    request.body = [encode_card_parameter('card[number]', 10000),
                    encode_card_parameter('card[name]', 'created by rest api'),
                    encode_card_parameter('card[card_type_name]', 'Card'),
                    encode_property('card dependency', value_card.number),
                    encode_property('status', 'open')].join("&")
    request.basic_auth(url.user, url.password)
    Net::HTTP.new(url.host, url.port).start { |http| http.request(request) }

    new_card = @project.cards.find_by_number(10000)
    assert new_card
    assert_equal 'created by rest api', new_card.name
    assert_equal value_card, card_dependency_property.value(new_card)
  end

  def test_create_card_via_api_should_never_use_card_defaults
    login_as_admin
    setup_property_definitions :status => ['new', 'old'], :size => [1, 2]
    size_def = @project.find_property_definition 'size'
    size_def.update_attribute :hidden, true
    status_def = @project.find_property_definition 'status'

    card_defaults = @project.card_types.first.card_defaults
    card_defaults.update_properties(:status => 'new')
    card_defaults.update_properties(:size => '1')
    card_defaults.save!

    create_card_via_api('card[number]' => 10000, 'card[name]' => "created by rest api", 'card[card_type_name]' => "Card")

    created_card = @project.cards.find_by_number(10000)
    assert_equal nil, created_card.cp_status
    assert_equal nil, created_card.cp_size
  end

  def test_card_list_contains_a_card_element_per_card_in_project
    assert_equal @project.cards.size, get_elements_by_xpath(get("#{@url_prefix}/cards.xml", {}).body, "//cards/card").size
  end

  def test_card_resource_gets_a_card_property_as_a_vector_with_the_card_number
    card_dependency_property = setup_card_relationship_property_definition('card dependency')
    card = @project.cards.detect { |c| c.id != c.number }
    update_card_via_api(card.number, 'card[name]' => 'updated card', "card[properties][][name]" => 'card dependency', "card[properties][][value]" => card.number)

    response = get("#{@url_prefix}/cards/#{card.number}.xml", {})
    assert_equal card.number.to_s, get_elements_by_xpath(response.body, "//card[number='#{card.number}']/properties/property[name='card dependency']/value/number/text()").first.to_s
  end

  # Bug 7641
  def test_non_admins_should_not_be_able_to_update_hidden_properties
    login_as_admin
    setup_property_definitions :status => ['new', 'old'], :size => [1, 2]
    status_def = @project.find_property_definition 'status'
    size_def = @project.find_property_definition 'size'
    size_def.update_attribute :hidden, true

    card = create_card!(:name => 'my first card')
    size_def.update_card(card, '1')
    status_def.update_card(card, 'new')
    card.save!

    url = "http://bob:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml"

    put(url, 'card[name]' => 'updated card', "card[properties][][name]" => 'size', "card[properties][][value]" => 2)
    assert_equal "1", card.reload.cp_size

    put(url, 'card[name]' => 'updated card', "card[properties][][name]" => 'status', "card[properties][][value]" => 'old')
    assert_equal "old", card.reload.cp_status
  end

  def test_card_resource_provides_link_to_card_in_value_of_a_card_property
    card_dependency_property = setup_card_relationship_property_definition('card dependency')
    cards = @project.cards.select { |c| c.id != c.number }
    first_card = cards.first
    second_card = cards.last

    update_card_via_api(first_card.number, 'card[name]' => 'updated card', "card[properties][][name]" => 'card dependency', "card[properties][][value]" => first_card.number)
    update_card_via_api(second_card.number, 'card[name]' => 'updated card', "card[properties][][name]" => 'card dependency', "card[properties][][value]" => first_card.number)

    response = get("#{@url_prefix}/cards.xml", {})

    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{first_card.number}.xml", get_elements_by_xpath(response.body, "//card[number='#{first_card.number}']/properties/property[name='card dependency']/value/@url").first.to_s
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{first_card.number}.xml", get_elements_by_xpath(response.body, "//card[number='#{second_card.number}']/properties/property[name='card dependency']/value/@url").first.to_s
  end

  def test_card_resource_includes_created_on_and_modified_on_property
    card = @project.cards.first

    response = get("#{@url_prefix}/cards/#{card.number}.xml", {})

    assert_equal card.created_at.tz_format, get_element_text_by_xpath(response.body, "//card/created_on")
    assert_equal card.updated_at.tz_format, get_element_text_by_xpath(response.body, "//card/modified_on")
  end

  # bug 7629
  def test_read_only_users_cannot_update_card
    card = @project.cards.detect { |c| c.id != c.number }
    original_card_name = card.name
    response = put("#{@read_only_url_prefix}/cards/#{card.number}.xml", 'card[name]' => 'updated card')
    assert_equal original_card_name, card.reload.name
    assert_equal "403", response.code
  end

  def test_project_is_readonly
    other_project = create_project(:identifier => 'notthisproject', :skip_activation => true)

    @project.activate
    card = @project.cards.detect { |c| c.id != c.number }
    assert_not_equal other_project.identifier, @project.identifier

    response = update_card_via_api(card.number, 'card[project][identifier]' => other_project.identifier)
    assert_equal @project.identifier, get_element_text_by_xpath(response.body, "//card/project/identifier")
    assert_equal @project.id, card.reload.project.id

    response = update_card_via_api(card.number, 'card[project_id]' => other_project.id)
    assert_equal @project.identifier, get_element_text_by_xpath(response.body, "//card/project/identifier")
    assert_equal @project.id, card.reload.project.id
  end

  def test_created_by_is_readonly
    card = @project.cards.detect { |c| c.id != c.number }
    original_user = card.created_by
    other_user = User.find_by_login('bob')
    assert_not_equal other_user.login, card.created_by.login

    response = update_card_via_api(card.number, 'card[created_by][login]' => other_user.login)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//card/created_by/login")
    assert_equal original_user.login, card.reload.created_by.login

    response = update_card_via_api(card.number, 'card[created_by_user_id]' => other_user.id)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//card/created_by/login")
    assert_equal original_user.login, card.reload.created_by.login
  end

  def test_modified_by_is_readonly
    card = @project.cards.detect { |c| c.id != c.number }
    original_user = card.modified_by
    other_user = User.find_by_login('bob')
    assert_not_equal other_user.login, card.modified_by.login

    response = update_card_via_api(card.number, 'card[modified_by][login]' => other_user.login)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//card/modified_by/login")
    assert_equal original_user.login, card.reload.modified_by.login

    response = update_card_via_api(card.number, 'card[modified_by_user_id]' => other_user.login)
    assert_equal original_user.login, get_element_text_by_xpath(response.body, "//card/modified_by/login")
    assert_equal original_user.login, card.reload.modified_by.login
  end

  # bug 7642

  # bug 7721
  def test_get_cards_when_no_cards_exist_should_have_cards_as_root
    User.find_by_login('admin').with_current do
      with_new_project do |project|
        response = get("#{url_prefix(project)}/cards.xml", {})
        assert_equal 1, get_number_of_elements(response.body, "/cards")
      end
    end
  end

  # bug 7721
  def test_get_transitions_when_no_transitions_exist_should_have_transitions_as_root
    response = get("#{url_prefix(@project)}/cards/1/transitions.xml", {})
    assert_equal 1, get_number_of_elements(response.body, "/transitions")
  end

  # bug 8156
  def test_should_get_400_error_when_update_property_which_doesnt_exist
    card = @project.cards.detect { |c| c.id != c.number }
    response = update_card_via_api(card.number, 'card[name]' => 'updated card', "card[properties][][name]" => 'doesnt_exist', "card[properties][][value]" => card.number)
    assert_equal "422", response.code
    assert_equal "Project #{@project.name} does not have card property doesnt_exist", get_element_text_by_xpath(response.body, '/errors/error')
  end

  # bug 8993
  def test_card_type_should_come_with_url_attribute
    card = @project.cards.first
    response = get("#{@url_prefix}/cards/#{card.number}.xml", {})
    assert_match /api\/v2\/projects\/#{@project.identifier}\/card_types\/#{card.card_type.id}.xml/, get_elements_by_xpath(response.body, "//card[number='#{card.number}']/card_type/@url").first.to_s
  end

  def test_should_get_tags_with_card
    login_as_admin
    card = @project.cards.first
    card.add_tag "api"
    card.add_tag "V2"
    card.save!
    response = get("#{@url_prefix}/cards/#{card.number}.xml", {})
    assert_equal card.tag_summary, get_element_text_by_xpath(response.body, "//tags")
  end

  def test_should_get_card_using_oauth_token_to_authenticate
    url_prefix = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    card = @project.cards.first
    user = User.find_by_login('admin')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

    url = URI.parse("#{url_prefix}/cards/#{card.number}.xml")

    request = Net::HTTP::Get.new(url.path)
    request["Authorization"] = %{Token token="#{token.access_token}"}
    request['X_FORWARDED_PROTO'] = 'https'

    http = Net::HTTP.new(url.host, url.port)
    response = http.request(request)

    assert_equal card.number.to_s, get_element_text_by_xpath(response.body, '/card/number')
  end

  def test_should_not_authenticate_if_access_token_invalid
    url_prefix = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    card = @project.cards.first

    url = URI.parse("#{url_prefix}/cards/#{card.number}.xml")

    request = Net::HTTP::Get.new(url.path)
    request["Authorization"] = %{Token token="1234"}
    request['X_FORWARDED_PROTO'] = 'https'

    http = Net::HTTP.new(url.host, url.port)
    response = http.request(request)

    assert_equal "401", response.code
    assert response.body =~ /The OAuth token provided is invalid/
  end

  def test_should_not_authenticate_if_using_valid_token_and_user_was_deleted_even_if_project_is_anonymous_access_enabled
    login_as_admin
    @project.anonymous_accessible = true
    @project.save

    url_prefix = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    card = @project.cards.first

    user = User.find_by_login('admin')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)
    user.delete

    url = URI.parse("#{url_prefix}/cards/#{card.number}.xml")

    request = Net::HTTP::Get.new(url.path)
    request["Authorization"] = %{Token token="#{token.access_token}"}
    request['X_FORWARDED_PROTO'] = 'https'

    http = Net::HTTP.new(url.host, url.port)
    response = http.request(request)

    assert_equal "403", response.code
    assert_equal "Either the resource you requested does not exist or you do not have access rights to that resource.", get_element_text_by_xpath(response.body, '/errors/error')
  end

  def test_should_not_authenticate_if_access_token_is_valid_but_user_is_deleted
    login_as_admin
    @project.anonymous_accessible = false
    @project.save

    url_prefix = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    card = @project.cards.first
    user = User.find_by_login('admin')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)
    user.delete

    url = URI.parse("#{url_prefix}/cards/#{card.number}.xml")

    request = Net::HTTP::Get.new(url.path)
    request["Authorization"] = %{Token token="#{token.access_token}"}
    request['X_FORWARDED_PROTO'] = 'https'

    http = Net::HTTP.new(url.host, url.port)
    response = http.request(request)

    assert_equal "403", response.code
    assert_equal "Either the resource you requested does not exist or you do not have access rights to that resource.", get_element_text_by_xpath(response.body, '/errors/error')
  end

  def test_should_not_authenticate_using_valid_oauth_token_if_not_api_request
    url_prefix = "http://localhost:#{MINGLE_PORT}/projects/#{@project.identifier}"
    card = @project.cards.first
    user = User.find_by_login('admin')
    oauth_client = Oauth2::Provider::OauthClient.create!(:name => 'foo application', :redirect_uri => 'http://does.not.exist/cb')
    token = Oauth2::Provider::OauthToken.create!(:user_id => user.id.to_s, :oauth_client_id => oauth_client.id)

    url = URI.parse("#{url_prefix}/cards/#{card.number}")

    request = Net::HTTP::Get.new(url.path)
    request["Authorization"] = %{Token token="#{token.access_token}"}
    request['X_FORWARDED_PROTO'] = 'https'

    http = Net::HTTP.new(url.host, url.port)
    response = http.request(request)

    assert response.header["Location"] =~ Regexp.new("/profile/login")
    assert_equal "302", response.code
  end


  def test_upload_an_attachment_for_card
    card = @project.cards.first
    sample_file = sample_attachment('Sample $%@ Attachemnt.txt')
    url = URI.parse("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{card.number}/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal Net::HTTPCreated, response.class
    assert response.header['location'].ends_with?("Sample_____Attachemnt.txt")
  end

  #bug 10258
  def test_upload_an_attachment_for_card_without_correct_username_and_password
    card = @project.cards.first
    sample_file = sample_attachment('Sample $%@ Attachemnt.txt')
    url = URI.parse("http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{card.number}/attachments.xml")
    response = MultipartPost.multipart_post(url, :file => sample_file)
    assert_equal Net::HTTPUnauthorized, response.class
    assert_equal 0, @project.cards.find_by_number(1).attachments.length
  end

  #bug 13002
  def test_get_only_first_25_cards_when_requested_for_all_cards
    User.find_by_login('admin').with_current do
      with_new_project do |project|
        create_cards(project, 28)
        response = get("#{url_prefix(project)}/cards.xml", {})
        assert_equal 25, get_number_of_elements(response.body, "/cards/card")

        response = get("#{url_prefix(project)}/cards.xml?page=all", {})
        assert_equal 25, get_number_of_elements(response.body, "/cards/card")
      end
    end
  end

  private

  def encode_property(property_name, property_value)
    [encode_card_parameter('card[properties][][name]', property_name), encode_card_parameter('card[properties][][value]', property_value)].join('&')
  end

  def encode_card_parameter(param_name, param_value)
    Rack::Utils.build_query(param_name => param_value)
  end

  def update_card_via_api(card_number, params)
    put("#{@url_prefix}/cards/#{card_number}.xml", params)
  end

  def create_card_via_api(params)
    post("#{@url_prefix}/cards.xml", params)
  end

  def url_prefix(project)
    "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{project.identifier}"
  end
end
