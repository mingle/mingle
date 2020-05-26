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

class BacklogObjectivesControllerTest < ActionController::TestCase
  def setup
    login_as_admin
    @program = create_program
  end

  def test_deleting_objective_in_backlog
    backlog_objective = @program.objectives.backlog.create!(:name => "test")

    post :destroy, :program_id => @program.identifier, :id => backlog_objective.id
    assert_redirected_to program_backlog_objectives_path(@program)
    assert_equal "Feature #{backlog_objective.name.bold} has been deleted.", flash[:notice]

    assert_equal 0, @program.objectives.backlog.size
  end

  def test_deleting_invalid_objective_in_backlog
    post :destroy, :program_id => @program.identifier,  :id => 12
    assert_equal "Invalid Backlog Feature, cannot continue to delete.", flash[:error]
  end

  def test_should_plan_backlog_objective
    backlog_objective = @program.objectives.backlog.create!(:name => "test")
    put :plan_objective, :program_id => @program.identifier, :id => backlog_objective.id

    assert_redirected_to "#{program_plan_path(@program)}?planned_objective=test"
    assert_false @program.objectives.backlog.any?{|o| o.name == "test" }
    assert_equal 1, @program.objectives.reload.size
  end

  def test_should_update_size_and_value_of_backlog_objectives
    backlog_objective = @program.objectives.backlog.create!(:name => "test")

    xhr :put, :update, :program_id => @program.identifier, :id => backlog_objective.id, :objective => {:size => 1, :value => 2}

    assert_response :success
    assert_equal 1, backlog_objective.reload.size
    assert_equal 2, backlog_objective.reload.value
  end

  def test_updating_objective_name
    @program.objectives.backlog.create!(:name => "test")
    backlog_objective = @program.objectives.backlog.first

    xhr :put, :update, :program_id => @program.to_param, :id => backlog_objective.id, :objective => {:name => "test123"}

    assert_equal 1, @program.objectives.backlog.size
    assert_equal "test123", @program.objectives.backlog.first.name
  end

  def test_update_value_statement_responds_with_html_escaped_value_statement
    backlog_objective = @program.objectives.backlog.create!(:name => "test")
    xhr :put, :update, :program_id => @program.to_param, :id => backlog_objective.id, :objective => {:value_statement => '<h1>Tenacious D</h1>'}
    assert_equal "<h1>Tenacious D</h1>", @program.objectives.backlog.first.value_statement
  end

  def test_updating_duplicate_name_errors
    assert @program.objectives.backlog.create(:name => "first")
    assert @program.objectives.backlog.create(:name => "second")
    first_objective = @program.objectives.backlog.find_by_name("first")

    xhr :put, :update, :program_id => @program.to_param, :id => first_objective.id, :objective => {:name => "second"}
    assert_equal 'Name already used for an existing Feature.', @response.body
  end

  def test_shows_objectives_in_backlog
    assert @program.objectives.backlog.create(:name => 'unplanned objective')

    get :index, :program_id => @program.to_param
    assert_equal @program, assigns(:program)
  end

  def test_backlog_objectives_should_have_intitial_values
    @program.objectives.backlog.create(:name => 'unplanned objective', :size => 10, :value => 30)

    get :index, {:program_id => @program.to_param}

    assert_select "#objective_size[value=10]"
    assert_select "#objective_value[value=30]"
  end

  def test_should_hide_header_if_no_objectives
    get :index, {:program_id => @program.to_param}

    assert_select "#backlog_objectives_list.hide", :count => 1
  end

  def test_create_objective_to_backlog
    post :create, :program_id => @program.to_param, :id => @program.id, :backlog_objective => {:name => "test"}
    assert_response :success
    assert_equal 1, @program.objectives.backlog.size
    assert_equal "test", @program.objectives.backlog.first.name
    assert_equal @program.id, @program.objectives.backlog.first.program_id
  end

  def test_create_should_not_assign_program_id_if_backlog_objective_table_does_not_have_program_id_column
    Objective.stubs(:column_names).returns(%w(id name backlog_id position size value value_statement number)) do
      post :create, :program_id => @program.to_param, :id => @program.id, :objective => {:name => "test"}
      assert_response :success
      created_backlog_objective = @program.objectives.backlog.find_by_name('test')
      assert_nil created_backlog_objective.program_id
      assert_equal 1, @program.objectives.backlog.size
      assert_equal "test", created_backlog_objective.name
    end
  end

  def test_add_objective_to_backlog_shows_error_when_duplicate_objective_name_is_added
    assert @program.objectives.backlog.create(:name => "test")

    post :create, :program_id => @program.to_param, :id => @program.id, :backlog_objective => {:name => "test"}
    assert_equal 'Name already used for an existing Feature.', flash[:error]

    assert_equal 1, @program.objectives.backlog.size
  end

  def test_reorder_objectives
    first_objective = @program.objectives.backlog.create(:name => "first")
    second_objective = @program.objectives.backlog.create(:name => "second")

    backlog_objectives = @program.objectives.backlog
    assert_equal 1, backlog_objectives.find_by_name('second').position
    assert_equal 2, backlog_objectives.find_by_name('first').position

    put :reorder, :program_id => @program.identifier, :backlog_objective => [first_objective.id, second_objective.id]

    backlog_objectives = @program.objectives.backlog

    assert_equal 1, backlog_objectives.find_by_name('first').position
    assert_equal 2, backlog_objectives.find_by_name('second').position
  end

  def test_removes_carriage_return_character_from_value_statement_on_save
    first_objective = @program.objectives.backlog.create(:name => "first")
    xhr :put, :update, :program_id => @program.to_param, :id => first_objective.id, :objective => {:value_statement => "s\r\n  *a\r\n  *b"}
    assert_equal "s\n  *a\n  *b", first_objective.reload.value_statement

    xhr :put, :update, :program_id => @program.to_param, :id => first_objective.id, :objective => {:value_statement => ("s" * 749) + "\r\n"}
    assert_response :success
  end

  def test_should_render_program_settings_when_program_settings_are_enabled_and_user_is_admin
    MingleConfiguration.overridden_to(program_settings_enabled: true) do
      user = create_user!
      @program.add_member(user, :program_admin)
      login(user)

      get :index, :program_id => @program.identifier

      assert_select 'li.program_settings', :count => 1
    end
  end

  def test_should_render_program_settings_when_program_settings_are_enabled_and_user_is_member
    MingleConfiguration.overridden_to(program_settings_enabled: true) do
      user = create_user!
      @program.add_member(user, :program_member)
      login(user)

      get :index, :program_id => @program.identifier

      assert_select 'li.program_settings', :count => 0
    end
  end
end
