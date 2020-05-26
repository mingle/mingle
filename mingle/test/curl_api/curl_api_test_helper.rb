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

require File.expand_path(File.dirname(__FILE__) + '/../acceptance/scenarios/api/api_test_helper')

class ActiveSupport::TestCase
  include API::URLTestHelper

  def assert_response_includes(message, output)
    assert(output =~ /#{message}/im, "text '#{message}' should be present in the response body:\n#{output}")
  end

  def assert_absent_in_response(message, output)
    assert(output !~ /#{message}/im, "text '#{message}' should be absent in the response body:\n#{output}")
  end

  def assert_response_code(code, output)
    status = output.split("\n").first.strip
    assert(status =~ /#{code}/, "#{code} expected, but responded: #{status}")
  end

  def create_card_by_api_v2(name='new story', card_type='story')
    output = %x[curl -d "card[name]=#{name}" -d "card[card_type_name]=#{card_type}" #{cards_list_url}]
    assert_equal "", output.to_s.strip
    Card.find_by_name(name)
  end

  def update_property(name, value)
    "-d 'card[properties][][name]=#{name}' -d 'card[properties][][value]=#{value}'"
  end

  def collect_xpath_elements(xml_content, xpath)
    Nokogiri::XML::DocumentFragment.parse(xml_content).xpath(xpath)
  end

  def collect_inner_text(xml_content, xpath)
    collect_xpath_elements(xml_content, xpath).map do |prop|
      # normalize whitespace
      prop.inner_text.gsub(/[\s]+/, " ").strip
    end
  end

end
