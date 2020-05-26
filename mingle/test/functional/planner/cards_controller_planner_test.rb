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

require File.expand_path(File.dirname(__FILE__) + '/../../functional_test_helper')

class CardsControllerPlannerTest < ActionController::TestCase

  def setup
    @controller = CardsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @program = program('simple_program')
    @plan = @program.plan
    login_as_admin
  end

  def test_show_objective_info_on_card_show_page
    assign_project_cards(@program.objectives.first, sp_first_project)
    get :show, :project_id => sp_first_project.identifier, :number => 1
    assert_response :success
    assert_select 'table.program-list tr', :text => /#{@program.name}.*#{@program.objectives.first.name}/m
  end

  def test_should_not_show_objective_info_for_old_card_versions
    objective = @program.objectives.first
    @plan.assign_cards(sp_first_project, [1], objective)
    update_card_properties(sp_first_project, :number => 1, :status => 'closed')
    get :show, :project_id => sp_first_project.identifier, :number => 1, :version => 2
    assert_response :success
    assert_select 'table.program-list td a', :text => @program.name
    assert_select 'table.program-list td', :text => objective.name
    get :show, :project_id => sp_first_project.identifier, :number => 1, :version => 1
    assert_response :success
    assert_select '#programs-container', :count => 0
  end

  def test_show_editable_objective_link_on_card_show_page_for_full_team_member
    member = login_as_member
    sp_first_project.with_active_project do |proj|
      proj.add_member(member, :full_member)
    end
    get :show, :project_id => sp_first_project.identifier, :number => 1
    assert_response :success
    assert_select 'table.program-list tr', :text => /#{@program.name}.*\(not set\)/m
    assert_select 'td', :text => "(not set)"
    assert_select 'td a', :text => "Edit Features"
  end

  def test_show_objective_info_on_card_show_page_for_readonly_user
    with_new_project do |project|
      create_card!(:name => 'card')
      @program.projects << project
      assign_project_cards(@program.objectives.first, project)
      bob = login_as_bob
      project.add_member(bob, :readonly_member)
      get :show, :project_id => project.identifier, :number => 1
      assert_response :success
      assert_select 'table.program-list tr', :text => /#{@program.name}.*#{@program.objectives.first.name}/m
      assert_select 'td', :text => @program.objectives.first.name
    end
  end

  def test_show_objective_info_on_card_show_page_for_anonymous_user
    with_new_project do |project|
      set_anonymous_access_for(project, true)
      change_license_to_allow_anonymous_access
      create_card!(:name => 'card')
      @program.projects << project
      assign_project_cards(@program.objectives.first, project)
      logout_as_nil
      get :show, :project_id => project.identifier, :number => 1
      assert_response :success
      assert_select 'table.program-list tr', :text => /#{@program.name}.*#{@program.objectives.first.name}/m
    end
  end

  def test_show_smart_sorted_objective_info
    with_first_project do |project|
      card_1 = create_card!(:name => 'card 1')
      program_a = Program.create!(:name => 'program 11', :identifier => 'program_a')
      plan_a = program_a.plan
      program_a.projects << project
      objective_a = create_planned_objective(program_a, {:name => 'objective a'})
      plan_a.assign_cards(project, card_1.number, objective_a)

      program_b = Program.create!(:name => 'program 1', :identifier => 'program_b')
      plan_b = program_b.plan
      program_b.projects << project
      objective_b = create_planned_objective(program_b, {:name => 'objective b'})
      plan_b.assign_cards(project, card_1.number, objective_b)

      get :show, :project_id => project.identifier, :number => card_1.number
      assert_response :success
      assert_select 'table.program-list tr:nth-child(2)', :text => /#{program_b.name}.*#{objective_b.name}/m
      assert_select 'table.program-list tr:last-child', :text => /#{program_a.name}.*#{objective_a.name}/m
    end
  end

  def test_show_should_hide_plan_container_when_no_plan
    get :show, :project_id => first_project.identifier, :number => 1
    assert_select 'div[id=programs-container]', :count => 0
  end

  def test_show_should_not_display_plan_container_when_license_does_not_allow_planner_feature
    @program = create_program
    @plan = @program.plan
    license_key = { :licensee => 'barbobo', :max_active_users => '10' ,:expiration_date => '2099-07-13', :max_light_users => '8', :product_edition => Registration::NON_ENTERPRISE }
    CurrentLicense.register!(license_key.to_query, 'barbobo')

    @program.projects << first_project
    objective = @program.objectives.planned.create!(:name => 'objective', :start_at => '2012-10-23', :end_at => '2012-11-15')
    assign_project_cards(objective, first_project)

    get :show, :project_id => first_project.identifier, :number => 1
    assert_response :success
    assert_select 'div[id=programs-container]', :count => 0
  end

  def test_update_objectives_when_update_card
    objective = @program.objectives.find_by_name('objective a')
    sp_first_project.with_active_project do |project|
      card = project.cards.first
      post :update, :project_id => project.identifier, :id => card.id, :card => {:name => 'new name'}, :plan_objectives => {@plan.id => objective.id.to_s}
      assert_redirected_to :action => 'show'
      assert_equal 1, @plan.works.scheduled_in(objective).size
      assert_equal 'new name', card.reload.name
    end
  end

  def test_should_response_error_when_update_objectives_failed_with_updating_card
    objective = @program.objectives.find_by_name('objective a')
    sp_first_project.with_active_project do |project|
      card = project.cards.first
      deleted_objective_id = objective.id
      objective.destroy
      post :update, :project_id => project.identifier, :id => card.id, :card => {:name => 'new name'}, :plan_objectives => {@plan.id => 1}
      assert_template 'edit'
      assert_match /update.*objective.*failed/i, flash[:error].join
    end
  end

  def test_show_objectives_info_when_edit_card
    objective = @program.objectives.find_by_name('objective a')
    sp_first_project.with_active_project do |project|
      card = project.cards.first
      get :edit, :project_id => project.identifier, :number => card.number
      assert_response :success
      assert_select 'table.program-list tr', :text => /#{@program.name}.*\(not set\)/m
      assert_select 'td', :text => "(not set)"
      assert_select 'td a', :text => "Edit Features"
    end
  end

  def test_show_plan_objectives_when_new_card
    objective = @program.objectives.find_by_name('objective a')
    sp_first_project.with_active_project do |project|
      card = project.cards.first
      get :new, :project_id => project.identifier, :plan_objectives => {@plan.id.to_s => objective.id.to_s}
      assert_response :success
      assert_select 'table.program-list tr', :text => /#{@program.name}.*objective a/m
      assert_select 'td', :text => "objective a"
      assert_select 'td a', :text => "Edit Features"
    end
  end

  def test_add_card_to_objectives_when_create_card
    objective_a = @program.objectives.find_by_name('objective a')
    objective_b = @program.objectives.find_by_name('objective b')
    sp_first_project.with_active_project do |project|
      post :create, :project_id => project.identifier, :card => {:name => 'card name', :number => 5}, :plan_objectives => {@plan.id => "#{objective_a.id},#{objective_b.id}"}, :card_type => project.card_types.first
      assert_redirected_to :action => 'list'
      assert_equal 1, @plan.works.scheduled_in(objective_a).size
      assert_equal 1, @plan.works.scheduled_in(objective_b).size
      assert project.reload.cards.find_by_name('card name')
    end
  end

  def test_add_another_card_with_objectives_info_when_create_card
    objective = @program.objectives.find_by_name('objective a')
    sp_first_project.with_active_project do |project|
      post :create, :project_id => project.identifier, :card => {:name => 'card name', :number => 5}, :plan_objectives => {@plan.id => objective.id.to_s}, :card_type => project.card_types.first, :add_another => true
      assert_redirected_to :action => 'new', :plan_objectives => {@plan.id => objective.id}
    end
  end

  def test_updating_a_card_included_in_multiple_objectives
   objective_a = @program.objectives.find_by_name('objective a')
   objective_b = @program.objectives.find_by_name('objective b')

   with_new_project(:anonymous_accessible => true) do |project|
     set_anonymous_access_for(project, true)
     card = create_card!(:name => 'morning sf')
     @plan.assign_cards(sp_first_project, [card.number], objective_a)
     @plan.assign_cards(sp_first_project, [card.number], objective_b)
     post :update, :project_id => project.identifier, :id => card.id, :name => 'new card name'
     assert_redirected_to :action => 'show'
   end
  end

end
