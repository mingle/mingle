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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class MurmurIndexingTest < ActiveSupport::TestCase

  def setup
    @user = create_user! :login => 'bjanakir', :email => 'badri@thoughtworks.com', :name => 'Badri Soft D', :version_control_user_name => 'jb'
    login(@user.email)
    @project = first_project
    @project.activate
  end

  def teardown
    @project.deactivate
  end

  def test_indexing_should_include_murmur
    murmur = create_murmur(:murmur => "Pillar 2 above all others")
    assert_equal murmur.murmur, murmur.as_json_for_index['murmur']
  end

  def test_indexing_should_include_project_id
    murmur = create_murmur(:murmur => "Pillar 2 above all others")
    assert_equal @project.id, murmur.as_json_for_index['project_id']
  end

  def test_when_indexed_should_include_author
    murmur = create_murmur(:murmur => "I love saloon music")
    json = murmur.as_json_for_index[:author]
    assert_equal 'Badri Soft D', json['name']
    assert_equal 'bjanakir', json['login']
    assert_equal 'badri@thoughtworks.com', json['email']
    assert_equal 'jb', json['version_control_user_name']
  end
end
