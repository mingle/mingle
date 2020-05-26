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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class ProgramDependencyViewTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = create_program
    @program.add_member User.find_by_login("member")
    login_as_member
  end

  def test_serialize_and_load_params
    view = @program.dependency_views.create!(:user => User.current)
    assert_equal({}, view.params)
    assert_equal({}, view.reload.params)

    view.params[:filter] = "resolving"
    view.save!
    view.reload
    assert_equal({:filter => "resolving"}, view.reload.params)
  end

  def test_update_params
    view = @program.dependency_views.current
    view.update_params(:filter => 'raising')
    view.reload
    assert_equal 'raising', view.filter
  end

  def test_update_project_ids
    project1 = create_project
    project2 = create_project
    project3 = create_project
    @program.program_projects.create!(:project_id => project1.id)
    @program.program_projects.create!(:project_id => project2.id)

    view = @program.dependency_views.current
    assert_equal [project1, project2].map(&:id).sort, view.reload.projects.map(&:id).sort

    view.update_params(:project_ids => [project1.id.to_s])
    assert_equal [project1.id], view.params[:project_ids]
    assert_equal [project1.id], view.reload.projects.map(&:id)

    view.update_params(:project_ids => [project1.id, project2.id].map(&:to_s))
    assert_equal [project1, project2].map(&:id).sort, view.reload.projects.map(&:id).sort

    view.update_params(:project_ids => [project2.id, project3.id].map(&:to_s))
    assert_equal [project2.id], view.reload.projects.map(&:id)

    # when project_ids param value is blank
    view.update_params(:project_ids => [])
    assert_equal [project2.id], view.reload.projects.map(&:id)
    view.update_params({:something => :else})
    assert_equal [project2.id], view.reload.projects.map(&:id)

    # when project is removed from program
    view.update_params(:project_ids => [project1.id, project2.id])
    @program.program_projects.first.destroy
    assert_equal [project2.id], view.reload.projects.map(&:id)

    @program.program_projects.last.destroy
    assert_equal [], view.reload.projects.map(&:id)
  end

  def test_ignore_invalid_value_for_params
    view = @program.dependency_views.create!(:user => User.current)
    view.update_params(:filter => 'abc')
    view.reload
    assert_equal 'resolving', view.filter
  end

  def test_current_dependency_view_for_anonymous_user_should_be_default
    logout_as_nil
    view = @program.dependency_views.current
    assert_nil view.id
    assert_equal 'resolving', view.filter
  end

  def test_current_dependency_view_for_user_and_program
    assert_equal 0, @program.dependency_views.count
    view = @program.dependency_views.current
    assert_equal 1, @program.dependency_views.count

    view.update_params(:filter => 'raising')
    current_view = @program.dependency_views.current
    assert_equal view, current_view
    assert_equal 'raising', current_view.filter
  end

  def test_should_init_params_if_it_is_nil_on_creation
    view1 = @program.dependency_views.create!(:user => User.current)
    assert_equal({}, view1.params)

    view2 = @program.dependency_views.create!(:user => User.find_by_login('bob'), :params => {:filter => 'raising'})
    assert_equal({:filter => 'raising'}, view2.params)
  end

  def test_one_dependency_view_for_program_per_user
    @program.dependency_views.create!(:user => User.current)
    view = @program.dependency_views.create(:user => User.current)
    assert_false view.valid?
  end

  def test_dependencies_for_project_and_status
    view = @program.dependency_views.create!(:user => User.current, :params => {:filter => 'raising'})
    project2 = create_project
    @program.program_projects.create!(:project_id => project2.id)
    card = project2.cards.create!(:name => "card", :card_type_name => "Card")

    project1 = create_project
    @program.program_projects.create!(:project_id => project1.id)
    raising_card = project1.cards.create!(:name => "raising card", :card_type_name => 'Card')
    dep1 = project1.raised_dependencies.create!(:name => 'Dep1', :desired_end_date => '12/07/2015', :resolving_project_id => project2.id, :raising_card_number => raising_card.number)
    dep2 = project1.raised_dependencies.create!(:name => 'Dep2', :desired_end_date => '12/07/2015', :resolving_project_id => project2.id, :raising_card_number => raising_card.number)
    dep2.link_resolving_cards([card])

    project1_new_deps = view.dependencies_for(project1, Dependency::NEW)
    assert_equal 1, project1_new_deps.count
    assert project1_new_deps.include? dep1

    project1_accepted_deps = view.dependencies_for(project1, Dependency::ACCEPTED)
    assert_equal 1, project1_accepted_deps.count
    assert project1_accepted_deps.include? dep2
  end
end
