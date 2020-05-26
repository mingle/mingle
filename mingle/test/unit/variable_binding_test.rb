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

class VariableBindingTest < ActiveSupport::TestCase  
  
  def test_url_identifier_returns_the_display_name_of_its_project_variable
    with_new_project do |project|
      plv = create_plv!(project, :name => 'Foo', :data_type => ProjectVariable::STRING_DATA_TYPE)
      binding = VariableBinding.new :project_variable => plv
      assert_equal '(Foo)', binding.url_identifier
    end
  end
  
  def test_db_value_pair_returns_assigned_value_pair
    with_new_project do |project|
      owner = setup_user_definition("owner")
      member = User.find_by_login("member")
      project.add_member(member)
      dude = create_plv!(project, :name => 'dude', :data_type => ProjectVariable::USER_DATA_TYPE, :value => member.id )
      binding = VariableBinding.new :project_variable => dude, :property_definition => owner
      assert_equal [member.name, member.id.to_s], binding.db_value_pair
    end
    
  end
  
end
