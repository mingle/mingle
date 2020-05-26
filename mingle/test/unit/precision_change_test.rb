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

class PrecisionChangeTest < ActiveSupport::TestCase
  
  def test_managed_numeric_values_that_get_aliased_on_precision_reduction_should_be_deleted
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ["1.00", "1.01", "0.99", "2.000", "3"])

      old_precision = project.precision
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      assert_equal 3, size.reload.values.size
      assert_equal ["1.0", "2.0", "3"], size.values.sort_by(&:position).collect(&:value)
      assert_equal [1, 2, 3], size.values.sort_by(&:position).collect(&:position) # ensure new positions do not have gaps
    end
  end
  
  # this fake type of precision "decrease" happens in migrations when we use the precision code to remove duplicate values
  def test_managed_numeric_values_that_get_aliased_on_fake_precision_reduction_should_be_deleted
    with_new_project do |project|
      login_as_proj_admin
      setup_property_definitions :size => ['1.00', '1.01', '0.99', '2.000', '3', '1.0']
      size = project.find_property_definition('size')
      
      sql = SqlHelper.sanitize_sql("UPDATE #{PropertyDefinition.table_name} SET is_numeric = ? WHERE id = #{size.id}", true)
      ActiveRecord::Base.connection.execute(sql)

      card_one = project.cards.create!(:name => "c1", :card_type => project.card_types.first, :cp_size => "1.00")
            
      old_precision = 10
      new_precision = 10
      
      project.reload      
      PrecisionChange::Decrease.new(project, old_precision, new_precision).run
      
      assert_equal 5, size.reload.values.size
      assert_equal ["1.0", "1.01", "0.99", "2.000", "3"], size.values.sort_by(&:position).collect(&:value)
      assert_equal [1, 2, 3, 4, 5], size.values.sort_by(&:position).collect(&:position) # ensure new positions do not have gaps
      assert_equal "1.0", card_one.reload.cp_size
    end
  end
  
  def test_managed_numeric_values_are_not_lost_on_precision_increase
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ["1.00", "1.01", "0.99", "2.00"])
      
      old_precision = project.precision
      assert_equal 2, old_precision
      new_precision = 4
      PrecisionChange.create_change(project, old_precision, new_precision).run
      assert_equal 4, size.reload.values.size
      assert_equal ["1.00", "1.01", "0.99", "2.00"], size.values.sort_by(&:position).collect(&:value)
      assert_equal [1, 2, 3, 4], size.values.sort_by(&:position).collect(&:position)
    end
  end  
  
  def test_that_existing_views_that_used_old_values_will_point_to_new_values_on_precision_decrease
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ["1.00", "1.01", "0.99", "2.0"])
      other_size = setup_numeric_property_definition('other size', ["1.00", "1.01", "0.99", "2.0"])
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      size_is_1_01 = project.card_list_views.create_or_update(:view => {:name => "size is 1.01"}, :filters => ["[Type][is][Card]", "[size][is][1.01]"])
      other_size_is_0_99 = project.card_list_views.create_or_update(:view => {:name => "other size is 0.99"}, :filters => ["[Type][is][Card]", "[other size][is][0.99]"])
      view_with_no_change = project.card_list_views.create_or_update(:view => {:name => "no change"}, :filters => ["[Type][is][Card]", "[size][is][2.0]"])
      view_with_no_filters = project.card_list_views.create_or_update(:view => {:name => "no filters"}, :tagged_with => 'hello')
      
      new_precision = 1
      PrecisionChange.create_change(project.reload, old_precision, new_precision).run
      
      assert_equal "[Type][is][Card]\\n[size][is][1.0]", project.card_list_views.find_by_name('size is 1.01').filters.to_s
      assert_equal "[Type][is][Card]\\n[other size][is][1.0]", project.card_list_views.find_by_name('other size is 0.99').filters.to_s
      assert_equal "[Type][is][Card]\\n[size][is][2.0]", project.card_list_views.find_by_name('no change').filters.to_s
      assert_equal 4, project.card_list_views.count
    end
  end
  
  def test_that_increase_in_precision_will_not_change_values_used_in_transitions
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ["1.00", "2.03", "3"])
      other_size = setup_numeric_property_definition('other_size', ["1.00", "2.03", "3"])
      transition = create_transition(project, 'set to two and a bit', :required_properties => {:size => '3'}, :set_properties => {:other_size => '2.03'})
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 4
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "3", transition.prerequisites.first.reload.value
      assert_equal "2.03", transition.actions.first.reload.value
    end
  end
  
  def test_that_decrease_in_precision_will_change_managed_values_used_in_transitions
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ["1.00", "2.03", "3"])
      other_size = setup_numeric_property_definition('other_size', ["1.00", "2.03", "3"])
      transition = create_transition(project, 'set to two and a bit', :required_properties => {:size => '1.00'}, :set_properties => {:other_size => '2.09'})
      transition_2 = create_transition(project, 'set to three', :required_properties => {:size => '1.00'}, :set_properties => {:other_size => '3'})
      transition_3 = create_transition(project, '3 to 2.03', :required_properties => {:size => '3'}, :set_properties => {:other_size => '2.03'})
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1.0", transition.prerequisites.first.reload.value
      assert_equal "2.1", transition.actions.first.reload.value
      
      assert_equal "1.0", transition_2.prerequisites.first.reload.value
      assert_equal "3", transition_2.actions.first.reload.value
      
      assert_equal "3", transition_3.prerequisites.first.reload.value
      assert_equal "2.0", transition_3.actions.first.reload.value
      
      old_precision = 1
      new_precision = 0
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1", transition.prerequisites.first.reload.value
      assert_equal "2", transition.actions.first.reload.value
      
      assert_equal "1", transition_2.prerequisites.first.reload.value
      assert_equal "3", transition_2.actions.first.reload.value
      
      assert_equal "3", transition_3.prerequisites.first.reload.value
      assert_equal "2", transition_3.actions.first.reload.value
    end
  end
  
  def test_that_decrease_in_precision_will_change_unmanaged_values_used_in_transitions
    with_new_project do |project|
      size = setup_numeric_text_property_definition('size')
      other_size = setup_numeric_text_property_definition('other_size')
      transition = create_transition(project, 'set to two and a bit', :required_properties => {:size => '1.00'}, :set_properties => {:other_size => '2.09'})
      transition_2 = create_transition(project, 'set to three', :required_properties => {:size => '1.00'}, :set_properties => {:other_size => '3'})
      transition_3 = create_transition(project, '3 to 2.03', :required_properties => {:size => '3'}, :set_properties => {:other_size => '2.03'})
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1.0", transition.prerequisites.first.reload.value
      assert_equal "2.1", transition.actions.first.reload.value
      
      assert_equal "1.0", transition_2.prerequisites.first.reload.value
      assert_equal "3", transition_2.actions.first.reload.value
      
      assert_equal "3", transition_3.prerequisites.first.reload.value
      assert_equal "2.0", transition_3.actions.first.reload.value
    end
  end
  
  def test_that_history_subscriptions_using_old_values_will_point_to_new_values_on_precision_decrease
    with_new_project(:admins => [User.find_by_login('proj_admin')]) do |project|
      size = setup_numeric_property_definition('size', ["1.00", "1.01", "0.99", "2.0"])
      
      filter_user = project.users.first
      hash_params = {'involved_filter_properties' => {"size" => "1.01"},
                     'acquired_filter_properties'  =>  {"size" => "0.99"},
                     'filter_user' => filter_user.id.to_s
                    }
      history_subscription = project.create_history_subscription(filter_user, HistoryFilterParams.new(hash_params).serialize)
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1.0", history_subscription.reload.to_history_filter_params.involved_filter_properties['size']
      assert_equal "1.0", history_subscription.reload.to_history_filter_params.acquired_filter_properties['size']
    end
  end
  
  def test_history_subscriptions_using_values_with_acceptable_precision_will_not_change_on_precision_decrease
    with_new_project(:admins => [User.find_by_login('proj_admin')]) do |project|
      size = setup_numeric_property_definition('size', ["1.00", "1.01", "0.99", "2.0"])
      
      filter_user = project.users.first
      hash_params = {'involved_filter_properties' => {"size" => "1.01"},
                     'acquired_filter_properties'  =>  {"size" => "2.0"},
                     'filter_user' => filter_user.id.to_s
                    }
      history_subscription = project.create_history_subscription(filter_user, HistoryFilterParams.new(hash_params).serialize)
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1.0", history_subscription.reload.to_history_filter_params.involved_filter_properties['size']
      assert_equal "2.0", history_subscription.reload.to_history_filter_params.acquired_filter_properties['size']
    end
  end
  
  def test_card_defaults_managed_properties_change_appropriately_when_project_precision_is_decreased
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ["1.00", "1.01", "0.99", "2.0"])
      card_type = project.card_types.first
      card_defaults = card_type.card_defaults
      
      card_defaults.update_properties :size => "1.01"
      card_defaults.save!
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1.0", card_defaults.actions.reload.first.value
    end
  end
  
  def test_cards_are_updated_when_project_precision_is_decreased
    with_new_project do |project|
      login_as_proj_admin
      
      managed_size = setup_numeric_property_definition('managedsize', ["1.00", "1.01", "0.99", "2.0"])
      unmanaged_size = setup_numeric_text_property_definition('unmanagedsize')
      
      card_one = project.cards.create!(:name => 'card one', :card_type => project.card_types.first, :cp_managedsize => "0.99", :cp_unmanagedsize => "5.67")
      card_two = project.cards.create!(:name => 'card two', :card_type => project.card_types.first, :cp_managedsize => "2.0", :cp_unmanagedsize => nil)
      
      old_precision = project.precision
      assert_equal 2, old_precision
      
      new_precision = 1
      PrecisionChange.create_change(project, old_precision, new_precision).run
      
      assert_equal "1.0", card_one.reload.cp_managedsize
      assert_equal "5.7", card_one.cp_unmanagedsize
      
      assert_equal "2.0", card_two.reload.cp_managedsize
      assert_equal nil, card_two.cp_unmanagedsize
    end
  end
  
  def test_should_allow_mql_filter_to_ajust_precision_change_to_card_list_view
    with_filtering_tree_project do |project|
      login_as_proj_admin
      view = CardListView.construct_from_params(project, {:style => 'list', :filters => {:mql => 'type = story'}} )
      view.name = 'mql filtered view'
      view.save!
      
      view = CardListView.construct_from_params(project, {:tree_name => 'filtering tree', :style => 'grid', :tab => 'All', :excluded => ['release']} )
      view.name = 'tree filtered view'
      view.save!
      
      old_precision = project.precision
      new_precision = old_precision - 1

      assert_nothing_raised do 
        PrecisionChange.create_change(project, old_precision, new_precision).run
      end
    end
  end
  
  # Bug 7258
  def test_numeric_plvs_are_updated_when_project_precision_is_changed
    with_new_project do |project|
      plv = create_plv!(project, :name => 'timmy', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '2.33', :property_definition_ids => [])
      PrecisionChange.create_change(project, 2, 1).run
      assert_equal '2.3', plv.reload.value
      PrecisionChange.create_change(project, 1, 2).run
      assert_equal '2.3', plv.reload.value
      PrecisionChange.create_change(project, 1, 0).run
      assert_equal '2', plv.reload.value
    end
  end
  
  # Bug 7258
  def test_nonnumeric_plvs_are_not_updated_when_project_precision_is_changed
    with_new_project do |project|
      plv = create_plv!(project, :name => 'timmy', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '2.33', :property_definition_ids => [])
      PrecisionChange.create_change(project, 2, 1).run
      assert_equal '2.33', plv.reload.value
      PrecisionChange.create_change(project, 2, 3).run
      assert_equal '2.33', plv.reload.value
    end
  end
  
  # Bug 7258
  def test_should_not_change_precision_of_other_projects_when_project_precision_is_changed
    other_project_plv = nil
    other_project = with_new_project do |project|
      other_project_plv = create_plv!(project, :name => 'unrelated', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '2.33', :property_definition_ids => [])
    end
    with_new_project do |project|
      PrecisionChange.create_change(project, 2, 1).run
    end
    assert_equal '2.33', other_project_plv.reload.value
  end
  
end
