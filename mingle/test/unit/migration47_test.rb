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

# require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
# require File.dirname(__FILE__) + '/../../db/migrate/047_change_user_property_identifier_to_user_login_in_card_list_view.rb'
# 
# class Migration47Test < ActiveSupport::TestCase
#   
#   def setup
#     @first_user = User.find_by_login('first')
#     @bob = User.find_by_login('bob')
#     @project = create_project :users => [@first_user, @bob]
#     @project = first_project
#     @project.activate
#     @owner = @project.property_definitions.create_user_definition!(:name => 'deve')
#     @project.card_list_views.destroy_all
#   end
#   
#   def tear_down
#     @project.deactivate
#   end
#   
#   def test_revise_filters
#     view = create_card_list_view(:filter_properties => {'deve' => @first_user.id.to_s, 'type' => 'story'})
#     ChangeUserPropertyIdentifierToUserLoginInCardListView.up
#     assert_equal({'deve' => @first_user.login, 'type' => 'story'}, view.reload.params[:filter_properties])
#   end
#   
#   def test_if_user_do_not_exist_the_filter_will_be_removed
#     view = create_card_list_view(:filter_properties => {'deve' => 'not_existed_id'})
#     ChangeUserPropertyIdentifierToUserLoginInCardListView.up
#     assert_nil view.reload.params[:filter_properties]
#   end
#   
#   def test_revise_lanes
#     view = create_card_list_view(:group_by => 'deve', :lanes => " ,#{@first_user.id},#{@bob.id}")
#     ChangeUserPropertyIdentifierToUserLoginInCardListView.up
#     assert_equal(" ,#{@first_user.login},#{@bob.login}", view.reload.params[:lanes])
#   end
#   
#   def test_wrong_user_id
#     view = create_card_list_view(:group_by => 'deve', :lanes => "not_exist_id")
#     ChangeUserPropertyIdentifierToUserLoginInCardListView.up
#     assert_nil view.reload.params[:lanes]
#   end
#   
#   private
#   
#   def create_card_list_view(request_params)
#     @project.card_list_views.create_or_update(request_params.merge(:view => {:name => "view name"}))
#   end
# end
