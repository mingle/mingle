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

class MqlGenerationTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end

  def test_generate_mql_from_in_condition
    with_three_level_tree_project do |project|
      assert_equal "'Planning iteration'  IN (SELECT NUMBER WHERE status IS NULL)", regenerate("'Planning iteration' IN (SELECT name WHERE 'status' is NULL)")
      assert_equal "'Planning iteration'  IN (SELECT NUMBER WHERE status IS NULL)", regenerate("'Planning iteration' IN (SELECT number WHERE 'status' is NULL)")
    end
  end

  def test_should_has_surrounded_brackets_when_generating_or_conditions
    assert_equal "((Feature = Applications) OR (Feature = Dashboard))", regenerate("Feature = Applications OR Feature = 'Dashboard'")
  end

  def test_parsing_out_project_variable_containing_quote
    assert_equal "Iteration = \"'R1511RB\\\"\"", regenerate(%Q{WHERE iteration = 'R1511RB"})
  end

  def test_should_handle_slash_in_value
    property = @project.find_property_definition('Feature')
    create_plv!(@project, :name => 'Sprint A/B', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [property.id.to_s])
    assert_equal "Feature = (Sprint A/B)", regenerate("Feature = (Sprint A/B)")
  end

  def test_should_bind_this_card
    this_card = @project.cards.first
    assert_equal("'related card' = NUMBER #{this_card.number}", regenerate("'related card' = ThIs CaRd", :content_provider => this_card))
  end
  
  def test_should_bind_this_card_property_to_a_text_property
    this_card = create_card! :name => 'bub', :priority => 'low'
    assert_equal("Priority = low", regenerate("priority = ThIs CaRd.priority", :content_provider => this_card))
  end
  
  def test_should_bind_this_card_property_to_a_date_property
    this_card = create_card! :name => 'bub', :date_created => '02 Jan 2008'
    assert_equal("date_created = '02 Jan 2008'", regenerate("date_created = this card.date_created", :content_provider => this_card))
  end
  
  def test_should_bind_this_card_property_to_a_numeric_property
    this_card = create_card! :name => 'bub', :numeric_free_text => 23
    assert_equal("numeric_free_text = 23", regenerate("numeric_free_text = this card.numeric_free_text", :content_provider => this_card))
  end
  
  def test_should_bind_this_card_property_to_a_user_property
    this_card = create_card! :name => 'bub', :owner => User.current.id
    assert_equal("owner = member", regenerate("owner = this card.owner", :content_provider => this_card))
  end
  
  def test_this_card_property_bound_to_a_nil_value_should_show_null_in_the_generated_mql
    this_card = create_card! :name => 'bub', :priority => nil
    assert_equal("Priority IS NULL", regenerate("priority = THIS CARD.priority", :content_provider => this_card))
  end
  
  def test_should_bind_this_card_property_to_a_card_relationship_property
    some_other_card = create_card! :name => 'henri'
    this_card = create_card! :name => 'bub', :'related card' => some_other_card.id
    assert_equal("'related card' = NUMBER #{some_other_card.number}", regenerate("'related card' = this card.'related card'", :content_provider => this_card))
  end
  
  def test_should_be_able_to_bind_this_card_properties_in_IN_clauses
    this_card = create_card! :name => 'bub', :priority => 'low'
    assert_equal("Priority IN (high, low)", regenerate("priority IN (high, ThIs CaRd.priority)", :content_provider => this_card))
  end
  
  def test_should_bind_this_card_text_property
    this_card = create_card! :name => 'replaced', :priority => 'low'
    assert_equal("Priority = low", regenerate("priority = ThIs CaRd.priority", :content_provider => this_card))
  end
  
  def test_mql_generation_should_support_from_tree_with_where
    with_three_level_tree_project do |project|
      assert_equal "SELECT Number FROM TREE 'three level tree' WHERE status = open", regenerate("SELECT Number FROM TREE 'three level tree' WHERE status = open")
    end  
  end
  
  def test_mql_generation_should_support_from_tree
    with_three_level_tree_project do |project|
      assert_equal "FROM TREE 'three level tree'", regenerate("FROM TREE 'three level tree'")
    end  
  end
  
  def test_execute_should_support_from_tree_with_conditions
    with_three_level_tree_project do |project|
      assert_equal "FROM TREE 'three level tree' WHERE status = open", regenerate("FROM TREE 'three level tree' WHERE status=open")
    end
  end
  
  def test_mql_generation_should_support_count
    assert_equal "SELECT COUNT(*)", regenerate("select count(*)")
  end
  
  def test_mql_generation_should_support_as_of
    assert_equal "AS OF '2009-05-14'", regenerate("AS OF \"2009-05-14\"")
  end
  
  # Bug 6413
  def test_should_quote_values_that_are_mql_keywords
    with_new_project do |project|
      by_first_admin_within(project) do
        iteration_type = project.card_types.create!(:name => 'OR')
        project.reload
        assert_equal "Type = 'OR'", regenerate("Type = 'OR'")
      end  
    end
  end
  
  def test_should_quote_values_that_have_spaces
    with_new_project do |project|
      by_first_admin_within(project) do
        iteration_type = project.card_types.create!(:name => 'Original Requirement')
        project.reload
        assert_equal "Type = 'Original Requirement'", regenerate("Type = 'Original Requirement'")
      end  
    end
  end
  
  protected
  
  def regenerate(mql, binding_options={})
    CardQuery::MqlGeneration.new(CardQuery.parse(mql, binding_options)).execute
  end
end
