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
class TransitionCurlApiTest < ActiveSupport::TestCase
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

  def test_admin_execute_transition_on_card
    t = create_transition(@project, 'move story to two', :set_properties => {:size => '2'})
    card = @project.cards.first

    # TODO: the v1 api supports transitions by name, but v2 requires the db id. seriously?
    # api v1 used to find transition by form data: transition_execution[transition]='move story to two'
    url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/transition_executions/#{t.id}.xml"

    %x[curl -i -X POST -d transition_execution[card]=#{card.number} #{url}]
    view_card = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/#{card.number}.xml"
    output = %x[curl #{view_card} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }

    properties = collect_inner_text(output, "//property")
    assert properties.include?("#{SIZE} 2"), "did not find property #{SIZE} with value #{2} in:\n#{output}"
  end

end
