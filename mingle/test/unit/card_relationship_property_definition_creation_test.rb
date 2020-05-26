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

class CardRelationshipPropertyDefinitionCreationTest < ActiveSupport::TestCase

  def test_should_create_a_card_relationship_property
    User.with_current(User.find_by_login('admin')) do
      create_project.with_active_project do |project|
        project.create_card_relationship_property_definition(:name => 'timmy')
        assert project.reload.find_property_definition('timmy')
      end  
    end  
  end  
  
  def test_should_not_be_able_to_create_a_card_relationship_property_when_not_an_admin
    User.with_current(User.find_by_login('bob')) do
      create_project.with_active_project do |project|
        assert_raise(UserAccess::NotAuthorizedException) { project.create_card_relationship_property_definition(:name => 'jimmy') }
      end
    end  
  end
end
