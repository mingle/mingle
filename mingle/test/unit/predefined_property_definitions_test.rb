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

class PredefinedPropertyDefinitionsTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    login_as_member
  end
  
  def test_nullable
    assert !predefined('number').nullable?
    assert !predefined('name').nullable?
    assert predefined('description').nullable?
    assert !predefined('project_card_rank').nullable?
    assert !predefined('created_by').nullable?
    assert !predefined('modified_by').nullable?
  end
  
  def test_they_should_know_they_are_predefined
    assert predefined('number').is_predefined
    assert predefined('name').is_predefined
    assert predefined('description').is_predefined
    assert predefined('project_card_rank').is_predefined
    assert predefined('created_by').is_predefined
    assert predefined('modified_by').is_predefined    
    assert predefined('modified_on').is_predefined    
    assert predefined('created_on').is_predefined    
    assert predefined('project').is_predefined    
  end
  
  def test_should_return_null_if_not_found
    assert_nil predefined('no exit property')
  end  
  
  private
  def predefined(name)
    PredefinedPropertyDefinitions.find(@project, name)
  end
end
