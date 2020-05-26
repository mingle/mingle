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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')  

#Tags: mql, macro, cross_project

class Scenario150MqlCrossProjectRollupTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  STATUS = "status"
  SIZE = "size"
  ADDRESS = "address"
  ITERATION = "iteration"
  RELATED_CARD = "related card"
  START_ON = "start on"
  END_ON = "end on"
  EFFORT = "effort"
  OWNER = "owner"
  CARD = 'Card'
  
  RELEASE = "Release"
  STORY = "Story"
  PLANNING_TREE= "Planning tree"
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @bob = users(:bob)
    @another_bob = User.create(:name => @bob.name, :login => 'another_bob', :password => "anotherbob2.", :password_confirmation => 'anotherbob2.')
    
    @project_1 = create_project(:prefix => 'scenario_150_1', :admins => [@project_admin_user, users(:admin)], :users => [@bob, @another_bob])
    @project_2 = create_project(:prefix => 'scenario_150_2', :admins => [@project_admin_user, users(:admin)], :users => [@bob, @another_bob])
    login_as_proj_admin_user
  end
  
  # hijacking this test to also check html escaping
  def test_using_current_user_today_and_plv_in_collumn_conditions
    [@project_1, @project_2].each do |project|
      get_all_types_of_properties_ready(project)
      related_card_value = create_card!(:name => 'related card')

      card = create_card!(:name => 'card', STATUS => '<h1>new</h1>', SIZE => '5')
      open_card(project, card)
      set_relationship_properties_on_card_show(OWNER=> "(current user)")
      card = create_card!(:name => 'card', STATUS => '<h1>new</h1>', SIZE => '4')
      open_card(project, card)
      set_relationship_properties_on_card_show(OWNER=> "(current user)")
      card = create_card!(:name => 'card', STATUS => 'open', SIZE => '4')
      open_card(project, card)
      set_relationship_properties_on_card_show(START_ON => "(today)")
      card = create_card!(:name => 'card', STATUS => 'open', SIZE => '3')
      open_card(project, card)
      set_relationship_properties_on_card_show(START_ON => "(today)")
      end
      
      setup_project_variable(@project_1, :name => 'plv', :data_type => "NumericType", :value => "4", :properties => [SIZE])
      setup_project_variable(@project_2, :name => 'plv', :data_type => "NumericType", :value => "4", :properties => [SIZE])
      
      open_project(@project_1)
      edit_overview_page
      create_free_hand_macro(%{
           cross-project-rollup
           project-group:  #{@project_1.name}, #{@project_2.name}
           rows: #{STATUS}
           columns:
           -     label: max size of owner = current user
                 aggregate: MAX(#{SIZE})
                 conditions: #{OWNER} = current user 
           -     label: min size of start on = today
                 aggregate: MIN(#{SIZE})
                 conditions: "#{START_ON}" = today
           -     label: size > plv
                 aggregate: SUM(#{SIZE})
                 conditions:  #{SIZE} > (plv)                 

       })
    click_save_link
    assert_table_column_headers_and_order("cpr_table", STATUS, "max size of owner = current user", "min size of start on = today", "size > plv")
    assert_table_row_data_for("cpr_table", :row_number => 1, :cell_values => ['<h1>new</h1>', '5', '0', '10'])
    assert_table_row_data_for("cpr_table", :row_number => 2, :cell_values => ['open', '0', '3', '0'])
  end
  
 
  def test_using_relationship_property_as_rows
    [@project_1, @project_2].each do |project|
      get_a_R_I_S_tree_ready(project)
    end
    
    @project_1.activate
    card_not_set = create_card!(:card_type => STORY, :name => 'no release set')    
    
    open_project(@project_1)
    edit_overview_page
    create_free_hand_macro(%{

         cross-project-rollup
         project-group:  #{@project_1.name}, #{@project_2.name}
         rows: #{RELEASE}
         columns:
         -     label: label
               aggregate: count(*)
               conditions: Type = Story
     })
     click_save_link
     assert_table_column_headers_and_order("cpr_table", RELEASE, "label")
     assert_table_row_data_for("cpr_table", :row_number => 1, :cell_values => ["#{@release_card.name}", '2'])
     assert_table_row_data_for("cpr_table", :row_number => 2, :cell_values => ['(not set)', '1'])    
  end
  
  def test_using_some_regular_property_as_rows
    rows = [STATUS, SIZE, ADDRESS, SIZE, ITERATION]
    row_values = ["new", "2", "200 E Randolph St 25th Floor Chicago, IL 60601-6501", "16151"]    
    get_all_types_of_properties_ready(@project_1, @project_2)
    
    0.upto(3) do |i|
      @project_1.activate
      card_1 = create_card!(:name => 'card', rows[i]  => row_values[i]) 
      card_2 = create_card!(:name => 'card')
      @project_2.activate
      card_3 = create_card!(:name => 'card', rows[i]  => row_values[i]) 
      open_project(@project_1)
      edit_overview_page
      enter_text_in_editor("\\n\\n")
      create_free_hand_macro(%{
           cross-project-rollup
           project-group:  #{@project_1.name}, #{@project_2.name}
           rows: #{rows[i]}
           columns:
           -     label: label
                 aggregate: count(*)
                 conditions: Type = Card
       })
       enter_text_in_editor("\\n\\n")
       click_save_link
       
       assert_table_column_headers_and_order("cpr_table", rows[i], "label")
       assert_table_row_data_for("cpr_table", :row_number => 1, :cell_values => ["#{row_values[i]}", '2'])
       assert_table_row_data_for("cpr_table", :row_number => 2, :cell_values => ['(not set)', '1'])
       
       @project_1.activate
       destroy_cards(card_1, card_2)
       @project_2.activate
       destroy_cards(card_3)
    end 
  end
  
  # bug 7797
  def test_should_not_aggregate_users_when_their_display_name_is_the_same
    assert_equal @bob.name, @another_bob.name
    get_all_types_of_properties_ready(@project_1, @project_2)
    
    
    @project_1.with_active_project do |project|
      status_one = project.find_property_definition(STATUS)
      size_one = project.find_property_definition(SIZE)
      owner_one = project.find_property_definition(OWNER)
      
      card = project.cards.create!(:name => 'card one', :card_type_name => CARD)
      status_one.update_card(card, 'low')
      size_one.update_card(card, 2)
      owner_one.update_card(card, @bob.id)
      card.save!
      
      card_two = project.cards.create!(:name => 'card two', :card_type_name => CARD)
      status_one.update_card(card_two, 'low')
      size_one.update_card(card_two, 8)
      owner_one.update_card(card_two, @another_bob.id)
      card_two.save!
    end
    
    @project_2.with_active_project do |project|
      status_two = project.find_property_definition(STATUS)
      size_two = project.find_property_definition(SIZE)
      owner_two = project.find_property_definition(OWNER)
      
      card = project.cards.create!(:name => 'card one', :card_type_name => CARD)
      status_two.update_card(card, 'low')
      size_two.update_card(card, 4)
      owner_two.update_card(card, @another_bob.id)
      card.save!
    end
    
    cross_project_rollup_content = %{
      cross-project-rollup
      project-group: #{@project_1.identifier}, #{@project_2.identifier}
      rows: #{OWNER}
      columns:
      -    label: Points for Cards with Status low
           aggregate: SUM(#{SIZE})
           conditions: Type = Card AND #{STATUS} = low
      -    label: Number of Cards Owned
           aggregate: COUNT(*)
           conditions: Type = Card
         }
    
    open_overview_page_for_edit(@project_1)
    create_free_hand_macro(cross_project_rollup_content)
    click_save_link
    
    assert_table_column_headers_and_order("cpr_table", OWNER, "Points for Cards with Status low", "Number of Cards Owned")
    assert_table_row_data_for("cpr_table", :row_number => 1, :cell_values => ['bob@email.com (another_bob)', '12', '2'])
    assert_table_row_data_for("cpr_table", :row_number => 2, :cell_values => ['bob@email.com (bob)', '2', '1'])
  end
  
  def test_cross_project_rollup_should_show_and_sort_display_name_and_login_name    
    logins_and_display_names = [
      {:login => 'uncap',   :name => "b admin"},
      {:login => 'c_admin', :name => "c admin"},
      {:login => 'a_admin', :name => "admin"},    
      {:login => 'b_admin', :name => "admin"},
      {:login => 'cap',     :name => "B admin"}
      ]
    users = create_new_users(logins_and_display_names)                     
    team_members_in_project_1 = users
    team_members_in_project_2 = users[1,3]
    
    create_property_definition_for(@project_1, OWNER, :type => 'user')
    team_members_in_project_1.each do |user|
      @project_1.add_member(user) 
      create_card!(:name => user.name, :card_type => 'Card', 'owner' =>  user.id)
    end

    create_property_definition_for(@project_2, OWNER, :type => 'user')
    team_members_in_project_2.each do |user|
      @project_2.add_member(user) 
      create_card!(:name => user.name, :card_type => 'Card', 'owner' =>  user.id)
    end
    
    cross_project_rollup_content = %{
      cross-project-rollup
      project-group: #{@project_1.identifier}, #{@project_2.identifier}
      rows: #{OWNER}
      columns:
      -    label: number of cards associated to the user
           aggregate: count(*)
           conditions: 
    }    
    login_as_admin_user
    open_project(@project_1)
    add_macro_and_save_on(@project_1, cross_project_rollup_content)    
    assert_table_row_data_for("cpr_table", :row_number => 1, :cell_values => ['admin (a_admin)',   "2"])
    assert_table_row_data_for("cpr_table", :row_number => 2, :cell_values => ['admin (b_admin)',   "2"])
    assert_table_row_data_for("cpr_table", :row_number => 3, :cell_values => ['B admin (cap)',     "1"])
    assert_table_row_data_for("cpr_table", :row_number => 4, :cell_values => ['b admin (uncap)',   "1"])
    assert_table_row_data_for("cpr_table", :row_number => 5, :cell_values => ['c admin (c_admin)', "2"])
    destroy_users_by_logins(users.collect(&:login))
  end
  
  # from zendesk ticket 2316
  def test_name_should_work_as_row_value_in_project_rollup
    [@project_1, @project_2].each do |project|
      project.activate  
      iteration_type = setup_card_type(project, 'Iteration')
      card_type = project.card_types.find_by_name('Card')
      tree = setup_tree(project, 'Initiative - Card', :types => [iteration_type, card_type], :relationship_names => ["iteration"])   
      aggregate = setup_aggregate_property_definition('card count', AggregateType::COUNT, nil, tree.id, iteration_type.id, card_type)

      iteration_1 = create_card!(:card_type => iteration_type, :name => 'Iteration 1' )
      iteration_2 = create_card!(:card_type => iteration_type, :name => 'Iteration 2' )

      card_a = create_card!(:card_type => card_type, :name => 'card A', :iteration => iteration_1.id )
      card_b = create_card!(:card_type => card_type, :name => 'card B', :iteration => iteration_1.id )
      card_c = create_card!(:card_type => card_type, :name => 'card C', :iteration => iteration_1.id )
      card_d = create_card!(:card_type => card_type, :name => 'card D', :iteration => iteration_2.id )

      AggregateComputation.run_once
      sleep 1
    end
  
    login_as_admin_user
    open_project(@project_1)
    cross_project_rollup_content = %{
      cross-project-rollup
      project-group: #{@project_1.identifier}, #{@project_2.identifier}
      rows: name
      rows-conditions: type = iteration
      columns:
      -    label: count of stories
           aggregate: SUM("card count")
           conditions: Type = iteration
         }
    
    add_macro_and_save_on(@project_1, cross_project_rollup_content)    
    
    assert_table_row_data_for("cpr_table", :row_number => 1, :cell_values => ['Iteration 1',   "6"])
    assert_table_row_data_for("cpr_table", :row_number => 2, :cell_values => ['Iteration 2',   "2"])   
  end
  
  # bug 9730
  def test_cross_project_rollup_would_not_cause_following_average_macro_throw_error
    @project_1.activate
    create_property_for_card("Managed number list", SIZE)  
    create_card!(:name => 'card 1', :size => 1)
    create_card!(:name => 'card 2', :size => 2)
    open_project(@project_1)
    edit_overview_page
    create_free_hand_macro(%{
         cross-project-rollup
         project-group:  #{@project_1.name}, #{@project_2.name}
         rows: name
         columns:
         -     label: label
               aggregate: count(*)

     })
     
     create_free_hand_macro(%{
            average
              query: SELECT "size"
        
     })
     click_save_link        
     @browser.assert_text_present_in("content","1.5")    
  end
  
  private
  def get_a_R_I_S_tree_ready(project)
    @release_type = setup_card_type(project, RELEASE)
    @iteration_type = setup_card_type(project, ITERATION)
    @story_type = setup_card_type(project, STORY)
    project.reload.activate
    @tree = setup_tree(project, PLANNING_TREE, :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["Release", "Iteration"])         
    @iteration_card = create_card!(:card_type => @iteration_type, :name => 'iteration' )
    @release_card = create_card!(:card_type => @release_type, :name => 'release' )
    @story_card = create_card!(:card_type => @story_type, :name => 'story')
    add_card_to_tree(@tree, @release_card)
    add_card_to_tree(@tree, @iteration_card, @release_card)
    add_card_to_tree(@tree, @story_card, @iteration_card)
  end

  
  def get_all_types_of_properties_ready(*projects)
    projects.each do |project|
      project.activate
      create_property_for_card("Managed text list", STATUS)
      create_property_for_card("Allow any text", ADDRESS)
      create_property_for_card("Managed number list", SIZE)
      create_property_for_card("Allow any number", ITERATION)
      create_property_for_card("date", START_ON)
      create_property_for_card("date", END_ON)
      create_property_for_card("team", OWNER)
      create_property_for_card("card", RELATED_CARD)
    end
  end
  
  def destroy_cards(*cards)
    cards.each do |card|
      card.destroy
    end
  end
end
