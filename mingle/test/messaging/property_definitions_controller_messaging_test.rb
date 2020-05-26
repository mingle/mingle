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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

class PropertyDefinitionsControllerMessagingTest < ActionController::TestCase
  include MessagingTestHelper
  
  def setup
    @controller = create_controller PropertyDefinitionsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @first_user = User.find_by_login('first')
    @proj_admin = User.find_by_login('proj_admin')
    @project = create_project :users => [@first_user], :admins => [@proj_admin]
    login_as_proj_admin
  end
  
  def test_should_create_a_version_with_a_system_generated_comment_when_changing_the_formula_of_a_property_definition
    setup_numeric_text_property_definition 'dev size'
    dave_size = setup_formula_property_definition 'dave size', "3 * 'dev size'"
    
    card = @project.cards.create!(:name => 'Cardy card', :card_type_name => @project.card_types.first.name, :cp_dev_size => '2')
    
    assert_equal 6, dave_size.value(card)
    
    post :update, :project_id => @project.identifier, :id => dave_size.id, :property_definition => {:name => 'dave size', :formula => "2 * 'dev size'"},
      :card_types => {'1' => @project.card_types.first}

    HistoryGeneration.run_once
    change_descriptions = card.reload.versions.last.describe_changes
    assert change_descriptions.any? { |description| description == "System generated comment: dave size changed from 3 * 'dev size' to 2 * 'dev size'"}
  end
end
