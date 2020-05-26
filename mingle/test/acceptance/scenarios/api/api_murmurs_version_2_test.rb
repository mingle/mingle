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

# Tags: murmurs_api, api_version_2
class ApiMurmursVersion2Test < ActiveSupport::TestCase

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.with_first_admin do
      @project = create_project
    end
    API::Murmur.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}"
    API::Murmur.prefix = "/api/v2/projects/#{@project.identifier}/"
    login_as_admin
    @m1 = create_murmur(:murmur => 'm1')
    card = create_card!(:name => 'al toid')
    card.add_comment :content => 'm2', :murmur_this => true
    @m3 = create_murmur(:murmur => 'm3')
  end

  def test_should_be_able_to_get_murmurs
    assert_equal ['m3', 'm2', 'm1'], find
  end

  def test_request_murmurs_since_a_murmur_id
    assert_equal ['m3', 'm2'], find(:since_id => @m1.id)
  end

  def test_request_murmurs_before_a_murmur_id
    assert_equal ['m2', 'm1'], find(:before_id => @m3.id)
  end

  def test_return_400_on_bad_since_id
    assert_raise(ActiveResource::BadRequest) { find(:since_id => 'xyz') }
  end

  private
  def find(params=nil)
    API::Murmur.find(:all, :params => params).collect(&:body)
  end

end
