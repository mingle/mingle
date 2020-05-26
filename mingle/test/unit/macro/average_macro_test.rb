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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class AverageMacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit  
  def setup
    login_as_member
    @project = average_macro_test_project
    @project.activate
  end
  
  def test_can_render_average_for_non_host_project
    @project.add_member(User.find_by_login('member'))
    with_first_project do |active_project|
      assert_equal_ignoring_spaces '6.52',
        render(%{
          {{ average 
               query: SELECT SUM(Size) WHERE Iteration IN (6) GROUP BY Iteration 
               project: #{@project.identifier}
          }}
        }, active_project)
    end
  end
  
  #bug 3075
  def test_should_ignore_not_set_value_while_selecting_card_column
    assert_equal_ignoring_spaces '5', 
      render('{{ average query: SELECT Size WHERE Iteration IN (3, 8)}}', @project)

    assert_equal_ignoring_spaces '10', 
      render('{{ average query: SELECT SUM(Size) WHERE Iteration IN (3, 8) GROUP BY Iteration}}', @project)
  end

  def test_can_render_average_value_using_this_card
    with_card_query_project do |project|
      this_card = create_card!(:name => 'related card')
      assert_false this_card.redcloth
      related_card_property_definition = project.find_property_definition('related card')
      ['10', '5'].each do |size|
        other_card = create_card!(:name => 'mandatory name', :size => size)
        assert_false other_card.redcloth
        related_card_property_definition.update_card(other_card, this_card)
        other_card.save!
      end

      assert_equal_ignoring_spaces '7.5',
        render("{{ average query: SELECT Size WHERE 'related card' = THIS CARD }}", project, {:this_card => this_card})
    end
  end

  def test_using_this_card_syntax_with_card_defaults_shows_notice_message
    with_card_query_project do |project|
      card_defaults = project.card_types.first.card_defaults
      related_card_property_definition = project.find_property_definition('related card')
      ['10', '5'].each { |size| create_card!(:name => 'mandatory name', :size => size) }
      assert_match(/Macros using .*THIS CARD.* will be rendered when card is created using this card default./, render("{{ average query: SELECT Size WHERE 'related card' = THIS CARD }}", project, {:this_card => card_defaults}))
    end
  end
  
  def test_should_support_from_tree
    with_three_level_tree_project do |project|
      template = '{{ average query: SELECT Size FROM TREE "three level tree" }}'

      render_result = render(template, project)
      assert_equal_ignoring_spaces '2', render_result

      not_in_tree = create_card!(:size => 10000, :name => 'card not in tree', :number => 10)
      render_result = render(template, project)   
      assert_equal_ignoring_spaces '2', render_result
    end
  end
  
  def test_can_use_project_plv
    @project.add_member(User.find_by_login('member'))
    with_first_project do |active_project|
      create_plv!(active_project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => @project.identifier)
      
      template = %{
        {{ average 
             query: SELECT SUM(Size) WHERE Iteration IN (6) GROUP BY Iteration 
             project: (my_project)
        }}
      }
      assert_equal_ignoring_spaces '6.52', render(template, active_project)
    end
  end
end
