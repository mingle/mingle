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

class DependencyViewTest < ActiveSupport::TestCase
  def test_serialize_and_load_params
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.current)
      assert_equal({}, view.params)
      assert_equal({}, view.reload.params)

      view.update_params(:filter => "resolving")
      view.reload
      assert_equal({:filter => "resolving"}, view.reload.params)
    end
  end

  def test_should_return_correct_default_columns_based_on_filter
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.current)
      assert_equal DependencyView::COLUMNS[:default][:resolving], view.columns

      view.update_params(:filter => 'raising')
      view.reload
      assert_equal DependencyView::COLUMNS[:default][:raising], view.columns
    end
  end

  def test_should_get_different_columns_based_on_filter
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.current)
      view.update_params(:columns => { :resolving => ['raising_user'] })
      view.reload
      assert_equal ['raising_user'], view.columns

      view.update_params(:filter => 'raising')
      view.reload
      assert_equal DependencyView::COLUMNS[:default][:raising], view.columns
    end
  end

  def test_update_params
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.current)
      view.update_params(:filter => 'raising', :sort => 'name', :dir => 'desc')
      view.reload
      assert_equal 'raising', view.filter
      assert_equal 'name', view.sort
      assert_equal 'desc', view.dir
    end
  end

  def test_empty_columns_returns_db_value
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.current)
      view.update_params(:columns => { :resolving => ["desired_end_date"] })
      view.update_params(:filter => 'raising', :columns => { :raising => ['resolving_project'] })
      view.update_params(:filter => 'resolving', :columns => { :raising => ['resolving_project'] })
      view.reload
      assert_equal ['desired_end_date'], view.columns
    end
  end

  def test_ignore_invalid_value_for_params
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.current)
      view.update_params(:filter => 'abc', :sort => 'def', :dir => 'g', :columns => { :abc => ['raising_user'], :resolving => ["desired_end_date", "resolving_project", "foo"] })
      view.reload
      assert_equal 'resolving', view.filter
      assert_equal 'number', view.sort
      assert_equal 'asc', view.dir
      assert_equal ["desired_end_date", "resolving_project"], view.columns
    end
  end

  def test_sort_column_params_toggles_direction_if_given_column_is_same_with_sort_column
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.current
      view.update_params(:sort => 'number')
      params = view.sort_column_params('number')
      assert_equal 'desc', params[:dir]
      assert_equal 'number', params[:sort]
      params = view.sort_column_params('name')
      assert_equal 'asc', params[:dir]
      assert_equal 'name', params[:sort]
    end
  end

  def test_should_filter_out_invalid_columns_stored_in_the_db
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.current
      view.params[:columns] = { :resolving => [ 'raising_user', 'fake' ] }
      view.save
      view.reload
      assert_equal ['raising_user'], view.columns
    end
  end

  def test_should_return_nil_if_given_column_is_not_sortable
    login_as_member
    with_first_project do |proj|
      view = proj.dependency_views.current
      assert_nil view.sort_column_params('fake')
      assert_nil view.sort_column_params('resolving_cards')
    end
  end

  def test_current_dependency_view_for_anonymous_user_should_be_default
    logout_as_nil
    with_first_project do |proj|
      view = proj.dependency_views.current
      assert_nil view.id
      assert_equal 'asc', view.dir
      assert_equal 'number', view.sort
      assert_equal 'resolving', view.filter
      assert_equal DependencyView::COLUMNS[:default][:resolving], view.columns

      view.update_params(:dir => 'desc')
      assert_equal 'desc', view.dir
    end
  end

  def test_current_dependency_view_for_user_and_project
    login_as_member
    with_first_project do |proj|
      assert_equal 0, proj.dependency_views.count
      view = proj.dependency_views.current
      assert_equal 1, proj.dependency_views.count

      view.update_params(:sort => 'name')
      current_view = proj.dependency_views.current
      assert_equal view, current_view
      assert_equal 'name', current_view.sort
    end
  end

  def test_should_init_params_if_it_is_nil_on_creation
    login_as_member
    with_first_project do |proj|
      view1 = proj.dependency_views.create!(:user => User.current)
      assert_equal({}, view1.params)

      view2 = proj.dependency_views.create!(:user => User.find_by_login('bob'), :params => {:filter => 'raising'})
      assert_equal({:filter => 'raising'}, view2.params)
    end
  end

  def test_one_dependency_view_for_project_per_user
    login_as_member
    with_first_project do |proj|
      proj.dependency_views.create!(:user => User.current)
      view = proj.dependency_views.create(:user => User.current)
      assert_false view.valid?
    end
  end

  def test_dependencies_by_status
    login_as_member
    resolving_project = project_without_cards
    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:name => "new dep", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      card.raise_dependency(:name => "accepted dep", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      card.raise_dependency(:name => "resolved dep", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
    end
    resolving_project.reload.with_active_project do |proj|
      card = proj.cards.create!(:name => 'card1', :card_type_name => "Card")
      accepted_dep = proj.resolving_dependencies.find_by_name("accepted dep")
      accepted_dep.link_resolving_cards([card])
      resolved_dep = proj.resolving_dependencies.find_by_name("resolved dep")
      resolved_dep.link_resolving_cards([card])
      resolved_dep.toggle_resolved_status

      view = proj.dependency_views.current
      assert_equal ['new dep'], view.dependencies_with_status(Dependency::NEW).map(&:name)
      assert_equal ['accepted dep'], view.dependencies_with_status(Dependency::ACCEPTED).map(&:name)
      assert_equal ['resolved dep'], view.dependencies_with_status(Dependency::RESOLVED).map(&:name)
    end
  end

  def test_dependencies_by_status_should_sort_by_view_params
    login_as_member
    resolving_project = project_without_cards
    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:number => 1, :name => "hello", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      card.raise_dependency(:number => 2, :name => "foo", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      card.raise_dependency(:number => 3, :name => "bar", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      card.raise_dependency(:number => 4, :name => "baz", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!

      view = proj.dependency_views.current.update_params(:filter => 'raising')
      assert_equal ['hello', 'foo', 'bar', 'baz'], view.dependencies_with_status(Dependency::NEW).map(&:name)

      view.update_params(:dir => 'desc')
      assert_equal ['baz', 'bar', 'foo', 'hello'], view.dependencies_with_status(Dependency::NEW).map(&:name)

      view.update_params(:sort => 'name', :dir => 'asc')
      assert_equal ['bar', 'baz', 'foo', 'hello'], view.dependencies_with_status(Dependency::NEW).map(&:name)
    end
  end

  def test_dependencies_by_status_should_sort_by_view_params_from_join_tables
    login_as_member
    resolving_project1 = Project.create(:name => 'resolving1', :identifier => 'resolving1')
    resolving_project2 = Project.create(:name => 'resolving2', :identifier => 'resolving2')
    resolving_project3 = Project.create(:name => 'resolving3', :identifier => 'resolving3')

    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:number => 1, :name => "dep-X", :desired_end_date => '10/1/2017', :resolving_project => resolving_project1).save!
      card.raise_dependency(:number => 2, :name => "dep-Y", :desired_end_date => '10/1/2017', :resolving_project => resolving_project2).save!
      card.raise_dependency(:number => 3, :name => "dep-Z", :desired_end_date => '10/1/2017', :resolving_project => resolving_project3).save!
      view = proj.dependency_views.current.update_params(:filter => 'raising', :sort => 'resolving_project', :dir => 'desc')
      assert_equal ['dep-Z', 'dep-Y', 'dep-X'], view.reload.dependencies_with_status(Dependency::NEW).map(&:name)

      view.update_params(:dir => 'asc')
      assert_equal ['dep-X'], view.dependencies_with_status(Dependency::NEW, :limit => 1).map(&:name)
    end
  end

  # Member name = member@email.com
  # Project admin name = proj_admin@email.com"
  # Admin name = admin@email.com"
  def test_dependencies_by_status_should_sort_by_raising_user
    login_as_member
    resolving_project = project_without_cards

    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:number => 1, :name => "dep-X", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      login_as_proj_admin
      card.raise_dependency(:number => 2, :name => "dep-Y", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      login_as_admin
      card.raise_dependency(:number => 3, :name => "dep-Z", :desired_end_date => '10/1/2017', :resolving_project => resolving_project).save!
      view = proj.dependency_views.current.update_params(:filter => 'raising', :sort => 'raising_user')
      assert_equal [3, 1, 2], view.reload.dependencies_with_status(Dependency::NEW).map(&:number)

      view.update_params(:filter => 'raising', :sort => 'raising_user', :dir => 'desc')
      assert_equal [2, 1], view.reload.dependencies_with_status(Dependency::NEW, :limit => 2).map(&:number)

      view.update_params(:filter => 'raising', :sort => 'raising_user', :dir => 'desc')
      assert_equal [1, 3], view.reload.dependencies_with_status(Dependency::NEW, :limit => 2, :after_id => Dependency.find_by_number(2).id).map(&:number)
    end
  end

  def test_dependencies_by_status_should_limit_number_of_dependencies
    login_as_member
    resolving_project = project_without_cards
    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:number => 1, :name => "dep-a", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 2, :name => "dep-b", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 3, :name => "dep-c", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 4, :name => "dep-d", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 5, :name => "dep-e", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 6, :name => "dep-f", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
    end
    resolving_project.activate
    view = resolving_project.dependency_views.current
    resolved_deps = view.dependencies_with_status(Dependency::RESOLVED, {:limit => 5})
    assert_equal 5, resolved_deps.size
    assert_equal ['dep-a', 'dep-b', 'dep-c', 'dep-d', 'dep-e'], resolved_deps.map(&:name)
  end


  def test_dependencies_by_status_should_return_dependencies_after_an_id
    login_as_member
    resolving_project = project_without_cards
    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:number => 1, :name => "dep-a", :desired_end_date => '10/1/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 2, :name => "dep-b", :desired_end_date => '10/2/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 3, :name => "dep-c", :desired_end_date => '10/3/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 4, :name => "dep-d", :desired_end_date => '10/4/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 5, :name => "dep-e", :desired_end_date => '10/5/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
      card.raise_dependency(:number => 6, :name => "dep-f", :desired_end_date => '10/6/2017', :resolving_project => resolving_project, :status => Dependency::RESOLVED).save!
    end
    resolving_project.activate
    view = resolving_project.dependency_views.current
    resolved_deps = view.dependencies_with_status(Dependency::RESOLVED, {:limit => 5, :after_id => Dependency.find_by_number(2).id})
    assert_equal ['dep-c', 'dep-d', 'dep-e', 'dep-f'], resolved_deps.map(&:name)

    view.update_params(:dir => 'desc')
    resolved_deps = view.reload.dependencies_with_status(Dependency::RESOLVED, {:limit => 5, :after_id => Dependency.find_by_number(3).id})
    assert_equal ['dep-b', 'dep-a'], resolved_deps.map(&:name)

    view.update_params(:dir => 'desc', :sort => 'desired_end_date')
    resolved_deps = view.reload.dependencies_with_status(Dependency::RESOLVED, {:limit => 2, :after_id => Dependency.find_by_number(4).id})
    assert_equal ['dep-c', 'dep-b'], resolved_deps.map(&:name)

    view.update_params(:dir => 'asc', :sort => 'resolving_project')
    resolved_deps = view.reload.dependencies_with_status(Dependency::RESOLVED, {:limit => 4, :after_id => Dependency.find_by_number(2).id})
    assert_equal ['dep-c', 'dep-d', 'dep-e', 'dep-f'], resolved_deps.map(&:name)
  end

  def test_dependencies_by_status_should_sort_by_resolving_project
    login_as_member
    resolving_project1 = Project.create(:name => 'first one', :identifier => 'first_one')
    resolving_project2 = Project.create(:name => 'second one', :identifier => 'second_one')
    resolving_project3 = Project.create(:name => 'third one', :identifier => 'third_one')

    with_first_project do |proj|
      card = proj.cards.first
      card.raise_dependency(:number => 1, :name => "dep-Z", :desired_end_date => '10/1/2017', :resolving_project => resolving_project1).save!
      card.raise_dependency(:number => 2, :name => "dep-X", :desired_end_date => '10/1/2017', :resolving_project => resolving_project2).save!
      card.raise_dependency(:number => 3, :name => "dep-Y", :desired_end_date => '10/1/2017', :resolving_project => resolving_project3).save!

      view = proj.dependency_views.current.update_params(:filter => 'raising', :sort => 'resolving_project')
      assert_equal ['dep-Z', 'dep-X', 'dep-Y'], view.dependencies_with_status(Dependency::NEW).map(&:name)
    end
  end

  def test_is_collapsed
    with_first_project do |proj|
      view = proj.dependency_views.create!(:user => User.find_by_login('bob'), :params => {:collapsed => ['new']})
      assert view.is_collapsed?(Dependency::NEW)
      assert_false view.is_collapsed?(Dependency::ACCEPTED)
      assert_false view.is_collapsed?(Dependency::RESOLVED)
    end
  end


end
