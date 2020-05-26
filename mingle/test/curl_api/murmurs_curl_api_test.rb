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
class MurmursCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'murmurs_curl_api_test') do |project|
      end
    end
    login_as_admin
  end

  def teardown
    disable_basic_auth
  end

  def test_should_be_able_to_get_murmurs
    create_murmur(:murmur => 'Hello world')
    output = %x[curl -X GET #{murmurs_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal "Hello world", get_element_text_by_xpath(output, "/murmurs/murmur/body")
  end

  def test_should_be_able_to_post_murmurs
    %x[curl -X POST -i -d "murmur[body]=hello world" #{murmurs_list_url}]
    assert_equal 1, @project.reload.murmurs.size
    assert_equal "hello world", @project.reload.murmurs.first.murmur
  end

  def test_should_be_able_to_post_card_murmurs
    card = create_cards(@project, 1).first
    url = create_card_murmurs_url(1)
    output = %x[curl -X POST #{url} -d "comment[content]=murmur on card" | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'murmur on card', card.origined_murmurs.last.murmur
    assert_equal 'murmur on card', get_element_text_by_xpath(output, "/murmur/body")
    assert_equal User.current.login, get_element_text_by_xpath(output, "/murmur/author/login")
    assert_equal card.number, get_element_text_by_xpath(output, "/murmur/stream/origin/number").to_i
  end

  def test_should_truncate_the_murmur_when_it_is_more_than_1000_characters
    create_murmur(:murmur => 'a' * 1001)
    output = %x[curl -X GET #{murmurs_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'a' * 997, get_element_text_by_xpath(output, "/murmurs/murmur/body")
  end

  def test_should_not_truncate_murmur_when_show_a_single_murmur
    expected_content = "a" * 1001
    murmur = create_murmur(:murmur => expected_content)
    output = %x[curl -X GET #{murmur_url_for(murmur)} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal expected_content, get_element_text_by_xpath(output, "/murmur/body")
  end

  def test_should_be_able_to_get_murmurs_from_specified_page
    1.upto(26) do |i|
      create_murmur(:murmur => "murmur #{i}")
    end
    url = murmurs_list_url :query => "page=1"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 25, get_number_of_elements(output, "/murmurs/murmur")

    url = murmurs_list_url :query => "page=2"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "/murmurs/murmur")
    assert_equal "murmur 1", get_element_text_by_xpath(output, "/murmurs/murmur/body")
  end

  def test_should_give_empty_array_when_there_is_not_any_murmur_yet
    output = %x[curl -X GET #{murmurs_list_url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'murmurs', get_root_element_name(output)
    assert_equal 0, get_number_of_elements(output, "/murmurs/murmur")
  end

  def test_should_give_empty_array_when_trying_to_get_a_non_existing_page_of_murmurs
    create_murmur(:murmur => "murmur")
    url = murmurs_list_url :query => "page=9999"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 'murmurs', get_root_element_name(output)
    assert_equal 0, get_number_of_elements(output, "/murmurs/murmur")
  end

end
