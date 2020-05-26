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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MultiLevelDepotTest < ActiveSupport::TestCase

  def setup
    init_p4_driver_and_repos("#{RAILS_ROOT}/test/data/multi_level_repos")
    @project = create_project
    @config = PerforceConfiguration.new(:project => @project, 
                                        :username => "ice_user", 
                                        :host=> "localhost", 
                                        :port=> "1666", 
                                        :repository_path =>"//depot/...")
    @repos = @config.repository
  end

  def teardown
    @driver.teardown
  end
  
  def test_should_retrieve_correct_names_for_sub_directories_of_a_depot_path
    node = @repos.node('//depot', 'HEAD')
    assert_equal ['bam.bam', 'bar'], node.children.collect(&:name)
  end
    
  def test_should_retrieve_correct_names_for_contents_of_sub_directories_of_a_depot_path
    node = @repos.node('//depot/bar', 'HEAD')
    assert_equal ['bar.txt'], node.children.collect(&:name)

    node = @repos.node('//depot/bam.bam', 'HEAD')
    assert_equal ['baz.txt', 'rubbles'], node.children.collect(&:name)
  end
    
end


