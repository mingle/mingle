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

class ObjectiveFilterTest < ActiveSupport::TestCase
  def setup
    @program = program('simple_program')
    @plan = @program.plan
    @objective_a = @program.objectives.find_by_name('objective a')
    @project = sp_first_project
  end
  
  def test_create_objective_filter
    filter = @objective_a.filters.create!(:project => @project, :params => {:filters => ["[status][is][new]"]})
    filter.reload
    assert filter
    assert_equal @project, filter.project
    assert_equal @objective_a, filter.objective
    assert_equal({:filters => ["[status][is][new]"]}, filter.params)
  end

  def test_objective_filter_uniqueness    
    @objective_a.filters.create!(:project => @project, :params => {:filters => ["[status][is][new]"]})
    f = @objective_a.filters.create(:project => @project, :params => {:filters => ["[status][is][new]"]})
    assert !f.valid?
  end

  def test_remove_work_items_mismatching_filter
    @plan.assign_cards(@project, [1, 2], @objective_a)
    filter = @objective_a.filters.create!(:project => @project, :params => {:filters => ["[number][is][1]"]})
    @project.with_active_project do
      filter.sync_work
    end
    assert_equal 1, @objective_a.reload.works.size
    assert_equal 1, @objective_a.works.first.card_number
  end

  def test_remove_work_items_mismatching_a_mql_filter
    @plan.assign_cards(@project, [1, 2], @objective_a)
    filter = @objective_a.filters.create!(:project => @project, :params => {:mql => "number is 1"})
    @project.with_active_project do
      filter.sync_work
    end
    assert_equal 1, @objective_a.reload.works.size
    assert_equal 1, @objective_a.works.first.card_number
  end

  def test_add_cards_matching_filter
    filter = @objective_a.filters.create!(:project => @project, :params => {:filters => ["[number][is][1]"]})
    @project.with_active_project do
      filter.sync_work
    end
    assert_equal 1, @objective_a.reload.works.size
    assert_equal 1, @objective_a.works.first.card_number
  end

  def test_add_cards_matching_filter_and_also_are_work_of_another_objective
    @objective_a = @program.objectives.find_by_name('objective a')
    @objective_b = @program.objectives.find_by_name('objective b')
    @project = sp_first_project
    filter_a = @objective_a.filters.create!(:project => @project, :params => {:filters => ["[number][is][1]"]})
    filter_b = @objective_b.filters.create!(:project => @project, :params => {:filters => ["[number][is][1]"]})
    @project.with_active_project do
      filter_a.sync_work
      filter_b.sync_work
    end
    assert_equal 1, @objective_a.reload.works.size
    assert_equal 1, @objective_a.works.first.card_number

    assert_equal 1, @objective_b.reload.works.size
    assert_equal 1, @objective_b.works.first.card_number
  end

  def test_sync_should_only_sync_work_for_filters_in_scope
    objective_a = @program.objectives.find_by_name('objective a')
    first_project = @plan.program.projects.first
    second_project = @plan.program.projects.second

    @plan.assign_cards(first_project, [1], objective_a)
    @plan.assign_cards(second_project, [1], objective_a)
    
    assert_equal [1], objective_a.works.created_from(first_project).map(&:card_number)
    assert_equal [1], objective_a.works.created_from(second_project).map(&:card_number)

    objective_a.filters.create!(:project => first_project, :params => {:filters => ["[number][is][2]"]})
    objective_a.filters.create!(:project => second_project, :params => {:filters => ["[number][is][2]"]})
    
    first_project.with_active_project do
      ObjectiveFilter.for_project(first_project).sync
    end

    assert_equal [2], objective_a.works.created_from(first_project).map(&:card_number)
    assert_equal [1], objective_a.works.created_from(second_project).map(&:card_number)
  end

  def test_sync_should_skip_invalid_filters
    login_as_admin

    program = create_program
    plan = program.plan
    objective_a = program.objectives.planned.create!({:name => 'objective a', :start_at => "20 Feb 2011", :end_at => "1 Mar 2011"})
    vanilla = create_project
    program.projects << vanilla
    prop = vanilla.with_active_project do
      setup_managed_text_definition('scheduled for', ['Mar 5'])
    end
    objective_a.filters.create!(:project => vanilla, :params => {:filters => ["[scheduled for][is][Mar 5]"]})
    prop.enumeration_values.first.update_attribute :value, 'Mar 6'

    assert_nothing_raised do
      vanilla.with_active_project do
        ObjectiveFilter.for_project(vanilla).sync
      end
    end
  end

  def test_should_do_nothing_for_removing_mismatched_work_when_filter_is_not_valid
    @plan.assign_cards(@project, [1, 2], @objective_a)
    filter = @objective_a.filters.new(:project => @project, :params => {:filters => ["[unexisting][is][new]"]})
    filter.save(false)
    @project.with_active_project do
      assert !filter.card_filter.valid?
      filter.sync_work
    end
    assert_equal 2, @objective_a.works.count
  end

  def test_should_do_nothing_for_adding_matching_cards_when_filter_is_not_valid
    filter = @objective_a.filters.new(:project => @project, :params => {:filters => ["[unexisting][is][new]"]})
    filter.save(false)
    @project.with_active_project do
      assert !filter.card_filter.valid?
      filter.sync_work
    end
    assert_equal 0, @objective_a.works.count
  end

  def test_should_be_invalid_if_card_filter_is_not_valid
    filter = @objective_a.filters.create(:project => @project, :params => {:filters => ["[unexisting][is][new]"]})
    assert !filter.valid?
  end

  def test_create_filter_without_params
    assert @objective_a.filters.create!(:project => @project)
  end

  def test_url_params
    filter = @objective_a.filters.new(:project => @project, :params => {:filters => ["[number][is][2]"]})
    assert_equal({:project_id => @project.identifier, :objective_id => @objective_a.to_param, :filters => ["[number][is][2]"]}, filter.url_params)
  end

  def test_url_params_should_merge_in_options
    filter = @objective_a.filters.new(:project => @project, :params => {:filters => ["[number][is][2]"]})
    assert_equal({:project_id => @project.identifier, :objective_id => @objective_a.to_param, :filters => ["[number][is][2]"], :foo => :bar}, filter.url_params(:foo => :bar))
  end

  def test_url_params_should_not_contain_invalid_filters
    filter = @objective_a.filters.new(:project => @project, :params => {:filters => ["[invalid][is][2]"]})
    assert_equal({:project_id => @project.identifier, :objective_id => @objective_a.to_param}, filter.url_params)
  end

  def test_filter_should_not_be_synced_on_creation
    filter = @objective_a.filters.create(:project => @project, :params => {:filters => ["[number][is][2]"]})
    assert_equal false, filter.synced?
  end
  
  def test_filter_should_mark_synced_on_sync
    filter = @objective_a.filters.create!(:project => @project, :params => {:filters => ["[number][is][2]"]})

    @project.with_active_project do |project|
      filter.sync_work
    end

    assert filter.synced?
  end
end
