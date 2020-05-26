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

class PivotTableMacroTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, RenderableTestHelper::Unit
  ERROR_PREFIX = 'Error in pivot-table'

  def setup
    @member = login_as_member
    @project = pivot_table_macro_project
    @project.activate
  end

  def test_can_render_pivot_table_for_non_host_project
    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>New </th>
          <th>In Progress </th>
          <th>Done </th>
          <th>Closed </th>
          <th>(not set) </th>
        </tr>
        <tr>
          <th>Dashboard </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 1 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Applications </th>
          <td> 1 </td>
          <td> 2 </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Rate calculator </th>
          <td> 3 </td>
          <td>  </td>
          <td>  </td>
          <td> 2 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Profile builder </th>
          <td>  </td>
          <td> 5 </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>User administration </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>(not set) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 5 </td>
        </tr>
        <tr>
          <th>Totals </th>
          <td> 4 </td>
          <td> 7 </td>
          <td>  </td>
          <td> 3 </td>
          <td> 5 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: true
          links: false
          project: pivot_table_macro_project
      }}
    }

    first_project.with_active_project do |active_project|
      assert template_can_be_cached?(template, active_project)
      assert_equal_ignoring_spaces expected, render(template, active_project)
    end
  end

  def test_can_render_pivot_table
    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>New </th>
          <th>In Progress </th>
          <th>Done </th>
          <th>Closed </th>
          <th>(not set) </th>
        </tr>
        <tr>
          <th>Dashboard </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 1 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Applications </th>
          <td> 1 </td>
          <td> 2 </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Rate calculator </th>
          <td> 3 </td>
          <td>  </td>
          <td>  </td>
          <td> 2 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Profile builder </th>
          <td>  </td>
          <td> 5 </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>User administration </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>(not set) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 5 </td>
        </tr>
        <tr>
          <th>Totals </th>
          <td> 4 </td>
          <td> 7 </td>
          <td>  </td>
          <td> 3 </td>
          <td> 5 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: true
          links: false
      }}
    }

    assert template_can_be_cached?(template, @project)
    assert_equal_ignoring_spaces expected, render(template, @project)
  end

  def test_should_escape_html_in_column_headers
    @member.name = '<h1>heyo</h1>'
    @member.save!

    template = %{
      {{
        pivot-table
          rows: status
          columns: owner
          aggregation: COUNT(*)
          links: false
      }}
    }

    rendered_template = render(template, @project)
    assert_match /<th>\n&lt;h1&gt;heyo&lt;\/h1&gt; \(member\)    <\/th>/, rendered_template
  end

  def test_should_escape_html_in_row_headers
    @member.name = '<h1>heyo</h1>'
    @member.save!

    template = %{
      {{
        pivot-table
          rows: owner
          columns: status
          aggregation: COUNT(*)
          links: false
      }}
    }

    rendered_template = render(template, @project)
    assert_match /<th>\n&lt;h1&gt;heyo&lt;\/h1&gt; \(member\)    <\/th>/, rendered_template
  end

  def test_can_exclude_empty_rows_and_columns
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          empty-columns: false
          empty-rows: false
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: true
          links: false
      }}
    }

    rendered = render(template, @project)

    assert_no_match /Done/, rendered
    assert_no_match /User management/, rendered
  end

  def test_renders_links_by_defaults
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: true
      }}
    }

    rendered_result = render(template, @project)

    all_statuses = @project.find_property_definition('status').values.collect(&:value)
    all_features = @project.find_property_definition('feature').values.collect(&:value)

    all_statuses.each do |status| #column heading links
      assert_mql_filter_parameter_present_in(rendered_result, "old_type = story AND Iteration = 1 AND Status = #{status.as_mql}")
    end

    all_features.each do |feature| #row heading links
      assert_mql_filter_parameter_present_in(rendered_result, "old_type = story AND Iteration = 1 AND Feature = #{feature.as_mql}")
    end

    all_statuses.each do |status|
      all_features.each do |feature|
        card_count = @project.cards.count(:conditions => "cp_old_type = 'story' AND cp_iteration = '1' AND cp_status = '#{status}' AND cp_feature = '#{feature}'")
        if card_count.to_i > 0 #cell links
          assert_mql_filter_parameter_present_in(rendered_result, "old_type = story AND Iteration = 1 AND Feature = #{feature.as_mql} AND Status = #{status.as_mql}")
        end
      end
    end
  end

  def test_render_links_should_support_from_tree
    with_three_level_tree_project do |project|
      template = %{
        {{
          pivot-table
            conditions: FROM TREE 'three level tree' WHERE type=story
            rows: size
            columns: Status
            aggregation: SUM(Size)
            totals: true
        }}
      }
      rendered_result = render(template, project)
      all_statuses = project.find_property_definition('status').values.collect(&:value)
      all_statuses.each do |status|
        assert_mql_filter_parameter_present_in(rendered_result, "FROM TREE 'three level tree' WHERE Type = story AND status = #{status}")
      end
    end
  end

  def test_render_links_should_support_from_tree_when_it_donnt_have_other_conditions
    with_three_level_tree_project do |project|
      template = %{
        {{
          pivot-table
            conditions: FROM TREE 'three level tree'
            rows: size
            columns: Status
            aggregation: SUM(Size)
            totals: true
        }}
      }
      rendered_result = render(template, project)

      all_statuses = project.find_property_definition('status').values.collect(&:value)
      all_statuses.each do |status|
        assert_mql_filter_parameter_present_in(rendered_result, "FROM TREE 'three level tree' WHERE status = #{status}")
      end
    end
  end

  def test_should_never_renders_links_for_not_set_and_totals
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: true
      }}
    }

    rendered = strip_all_except_table_and_values render(template, @project)
    expected_not_set = "<tr><th>(notset)</th><td></td><td></td><td></td><td></td><td>5</td></tr>"
    assert rendered.include?(expected_not_set)
    expected_totals = "<tr><th>Totals</th><td>4</td><td>7</td><td></td><td>3</td><td>5</td></tr>"
    assert rendered.include?(expected_totals)
  end

  #fix for bug 2628
  def test_can_render_pivot_table_without_conditions
    template = %{
      {{
        pivot-table
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
      }}
    }

    assert_not_include ERROR_PREFIX, render(template, @project)
  end

  def test_can_render_pivot_table_without_aggregation
    template = %{
      {{
        pivot-table
          rows: Feature
          columns: Status
      }}
    }

    assert_not_include ERROR_PREFIX, render(template, @project)
  end

  def test_yaml_load
    assert_equal({"conditions" => %{'flagged for release'=1}}, YAML::load(%{conditions: '''flagged for release''=1'}))
  end

  #fix for bug 1372
  def test_empty_columns_is_false
    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>New </th>
          <th>In Progress </th>
          <th>Closed </th>
          <th>(not set) </th>
        </tr>
        <tr>
          <th>Dashboard </th>
          <td>  </td>
          <td>  </td>
          <td> 1 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Applications </th>
          <td> 1 </td>
          <td> 2 </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Rate calculator </th>
          <td> 3 </td>
          <td>  </td>
          <td> 2 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Profile builder </th>
          <td>  </td>
          <td> 5 </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>User administration </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>(not set) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 5 </td>
        </tr>
        <tr>
          <th>Totals </th>
          <td> 4 </td>
          <td> 7 </td>
          <td> 3 </td>
          <td> 5 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          rows: Feature
          columns: Status
          empty-columns: false
          aggregation: SUM(Size)
          totals: true
          links: false
      }}
    }

    assert_equal_ignoring_spaces expected, render(template, @project)
  end

  #fix for bug 1372
  def test_empty_rows_is_false
    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>New </th>
          <th>In Progress </th>
          <th>Done </th>
          <th>Closed </th>
          <th>(not set) </th>
        </tr>
        <tr>
          <th>Dashboard </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 1 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Applications </th>
          <td> 1 </td>
          <td> 2 </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Rate calculator </th>
          <td> 3 </td>
          <td>  </td>
          <td>  </td>
          <td> 2 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>Profile builder </th>
          <td>  </td>
          <td> 5 </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>(not set) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 5 </td>
        </tr>
        <tr>
          <th>Totals </th>
          <td> 4 </td>
          <td> 7 </td>
          <td>  </td>
          <td> 3 </td>
          <td> 5 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1
          rows: Feature
          columns: Status
          empty-rows: false
          aggregation: SUM(Size)
          totals: true
          links: false
      }}
    }

    assert_equal_ignoring_spaces expected, render(template, @project)
  end

  #fix for bug 1236
  def test_should_escape_single_quote_after_mapping_indicator_which_can_not_be_parsed_by_yaml
    template = %{
      {{
        pivot-table
        conditions: old_type=Story AND 'flagged for release' = 1
        rows: flagged for release
        columns: status
      }}
    }
    render(template, @project)

    template = %{
      {{
        pivot-table
        conditions: 'flagged for release' = 1 AND old_type=Story
        rows: flagged for release
        columns: status
      }}

      {{
        pivot-table
        conditions: 'flagged for release' = 2 AND old_type=Story
        rows: flagged for release
        columns: status
      }}
    }
    render(template, @project)
  end

  def test_user_property_definitions
    owner_1 = create_user!
    owner_2 = create_user!
    tester_1 = create_user!
    tester_2 = create_user!
    [owner_1, owner_2, tester_1, tester_2].each do |u|
      @project.add_member(u)
    end
    create_card!(:name => 'Card #1', :owner => owner_1.id, :tester => tester_2.id )
    create_card!(:name => 'Card #2', :owner => owner_2.id, :tester => tester_2.id )
    create_card!(:name => 'Card #3', :owner => owner_2.id, :tester => tester_2.id )

    template = %{
      {{
        pivot-table
          rows: owner
          columns: tester
          links: false
      }}
    }

    render_result = render(template, @project)

    assert_include "<th>\n#{owner_1.name_and_login}    </th>", render_result
    assert_include "<th>\n#{owner_2.name_and_login}    </th>", render_result
    assert_include "<th>\n#{tester_1.name_and_login}    </th>", render_result
    assert_include "<th>\n#{tester_2.name_and_login}    </th>", render_result
    assert_include "<td>\n1    </td>", render_result
    assert_include "<td>\n2    </td>", render_result
  end

  def test_should_pivot_on_text_property_values
    create_card!(:name => 'Card #1', :freetext1 => 'one', :freetext2 => '2' )
    create_card!(:name => 'Card #2', :freetext1 => 'two', :freetext2 => '2' )
    create_card!(:name => 'Card #3', :freetext2 => '2' )

    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>2 </th>
        </tr>
        <tr>
          <th>one </th>
          <td> 1 </td>
        </tr>
        <tr>
          <th>two </th>
          <td> 1 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: freetext1 IN ('one', 'two')
          rows: freetext1
          columns: freetext2
          empty-rows: false
          empty-columns: false
          links: false
      }}
    }

    render_result = render(template, @project)
    assert_equal_ignoring_spaces expected, render_result
  end

  def test_should_pivot_on_unmanaged_numeric_property_values
    create_card!(:name => 'Card #1', :freetext1 => 'one', :numeric_free_text => '2.0' )
    create_card!(:name => 'Card #2', :freetext1 => 'two', :numeric_free_text => '2.00' )
    create_card!(:name => 'Card #3', :freetext1 => 'one', :numeric_free_text => '1' )

    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>1 </th>
          <th>2.00 </th>
        </tr>
        <tr>
          <th>one </th>
          <td> 1 </td>
          <td> 1 </td>
        </tr>
        <tr>
          <th>two </th>
          <td>  </td>
          <td> 1 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: freetext1 IN ('one', 'two')
          rows: freetext1
          columns: numeric_free_text
          links: false
          empty-columns: false
          empty-rows: false
      }}
    }

    render_result = render(template, @project)
    assert_equal_ignoring_spaces expected, render_result
  end

  def test_should_pivot_on_date_property_values
    create_card!(:name => 'Card #1', :date_created => '2007-01-01', :date_deleted => '2007-02-01' )
    create_card!(:name => 'Card #2', :date_created => '2007-01-02', :date_deleted => '2007-02-01' )
    create_card!(:name => 'Card #3', :date_deleted => '2007-02-01' )

    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>2007-02-01 </th>
        </tr>
        <tr>
          <th>2007-01-01 </th>
          <td> 1 </td>
        </tr>
        <tr>
          <th>2007-01-02 </th>
          <td> 1 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: date_created IN ('2007-01-01', '2007-01-02')
          rows: date_created
          columns: date_deleted
          empty-columns: false
          empty-rows: false
          links: false
      }}
    }

    render_result = render(template, @project)
    assert_equal_ignoring_spaces expected, render_result
  end

  def test_should_show_date_in_project_format
    create_card!(:name => 'Card #1', :date_created => '2007-01-01', :date_deleted => '2007-02-01' )
    create_card!(:name => 'Card #2', :date_created => '2007-01-01', :date_deleted => '2007-02-01' )
    create_card!(:name => 'Card #3', :date_deleted => '2007-02-01' )
    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    template = %{
      {{
        pivot-table
          conditions: date_deleted IN ('2007-02-01')
          rows: date_created
          columns: date_deleted
          links: false
      }}
    }

    render_result = render(template, @project)
    assert_not_include '2007-01-01', render_result
    assert_include '01 Jan 2007', render_result
  end

  def test_should_translate_non_equality_comparison_into_filter_links
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration < 2
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: false
          links: true
      }}
    }

    assert_mql_filter_parameter_present_in(render(template, @project), 'Iteration < 2')
  end

  def test_should_translate_less_than_or_equal_to_straightforward_mql
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration <= 1
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          totals: false
          links: true
      }}
    }

    rendered_result = render(template, @project)
    assert_mql_filter_parameter_present_in(rendered_result, 'Iteration <= 1')
  end

  def test_should_show_links_even_when_column_is_in_condition
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Status != 'Closed'
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          links: true
      }}
    }

    rendered_result = render(template, @project)

    non_closed_statuses = @project.find_property_definition('status').values.collect { |ev| ev.value if ev.value != 'Closed'}.compact
    non_closed_statuses.each do |non_closed_status|
      assert_mql_filter_parameter_present_in(rendered_result, "old_type = story AND Status != Closed AND Status = #{non_closed_status.as_mql}")
    end
  end

  def test_should_show_links_even_when_row_is_in_condition
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Status != 'Closed'
          rows: Status
          columns: Feature
          aggregation: SUM(Size)
          links: true
      }}
    }

    rendered_result = render(template, @project)

    non_closed_statuses = @project.find_property_definition('status').values.collect { |ev| ev.value if ev.value != 'Closed'}.compact
    non_closed_statuses.each do |non_closed_status|
      assert_mql_filter_parameter_present_in(rendered_result, "old_type = story AND Status != Closed AND Status = #{non_closed_status.as_mql}")
    end
  end

  def test_should_show_links_even_when_condition_is_too_complex_to_create_a_js_filter
    template = %{
      {{
        pivot-table
          conditions: old_type = story OR iteration = 1
          rows: Status
          columns: Feature
          aggregation: SUM(Size)
          links: true
      }}
    }

    rendered_result = render(template, @project)

    all_statuses = @project.find_property_definition('status').values.collect(&:value)
    all_features = @project.find_property_definition('feature').values.collect(&:value)

    all_statuses.each do |status|
      all_features.each do |feature|
        card_count = @project.cards.count(:conditions => "(cp_old_type = 'story' OR cp_iteration = '1') AND cp_status = '#{status}' AND cp_feature = '#{feature}'")
        if card_count.to_i > 0
          assert_mql_filter_parameter_present_in(rendered_result, "((old_type = story) OR (Iteration = 1)) AND Status = #{status.as_mql} AND Feature = #{feature.as_mql}")
        end
      end
    end
  end

  def test_should_show_links_when_row_and_column_are_not_in_condition
    template = %{
      {{
        pivot-table
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          links: true
      }}
    }

    assert render(template, @project).include?('a href=')
  end

  def test_should_show_links_when_not_null_is_present_in_condition
    template = %{
      {{
        pivot-table
          rows: Feature
          columns: Status
          aggregation: SUM(Size)
          links: true
          conditions: Iteration != NULL
      }}
    }

    rendered_result = render(template, @project)
    assert rendered_result.include?('a href=')
    assert_mql_filter_parameter_present_in(rendered_result, 'Iteration IS NOT NULL')
  end

  # fix for bug #2520
  def test_should_display_team_member_names_when_empty_rows_or_empty_columns_is_false
    owner_1 = create_user!
    owner_2 = create_user!
    tester_1 = create_user!
    tester_2 = create_user!

    [owner_1, owner_2, tester_1, tester_2].each do |u|
      @project.add_member(u)
    end
    create_card!(:name => 'Card #1', :owner => owner_1.id, :tester => tester_2.id )
    create_card!(:name => 'Card #2', :owner => owner_2.id, :tester => tester_2.id )
    create_card!(:name => 'Card #3', :owner => owner_2.id, :tester => tester_2.id )

    template = %{
      {{
        pivot-table
          rows: owner
          columns: tester
          links: false
          empty-rows: false
          empty-columns: false
      }}
    }

    render_result = render(template, @project)

    assert_include "<th>\n#{owner_1.name_and_login}    </th>", render_result
    assert_include "<th>\n#{owner_2.name_and_login}    </th>", render_result
    assert_not_include "<th>\n#{tester_1.name_and_login}    </th>", render_result
    assert_include "<th>\n#{tester_2.name_and_login}    </th>", render_result
    assert_not_include "<th>\n#{@member.name_and_login}    </th>", render_result

    assert_include "<td>\n1    </td>", render_result
    assert_include "<td>\n2    </td>", render_result
  end

  def test_order_of_user_property_definition_column
    user_properties = {:password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}

    owner_1 = User.create!(user_properties.merge(:login => "owner1", :name => "owner", :email => "owner1@x.com"))
    owner_2 = User.create!(user_properties.merge(:login => "a_owner2", :name => "owner", :email => "owner2@x.com"))
    owner_3 = User.create!(user_properties.merge(:login => "a_owner3", :name => "owner", :email => "owner3@x.com"))

    tester_2 = User.create!(user_properties.merge(:login => "test2", :name => "tester", :email => "tester2@x.com"))
    tester_1 = User.create!(user_properties.merge(:login => "test1", :name => "tester", :email => "tester1@x.com"))

    [owner_1, owner_2, owner_3, tester_1, tester_2].each do |u|
      @project.add_member(u)
    end

    create_card!(:name => 'Card #1', :owner => owner_1.id, :tester => tester_2.id )
    create_card!(:name => 'Card #2', :owner => owner_2.id, :tester => tester_2.id )
    create_card!(:name => 'Card #3', :owner => owner_2.id, :tester => tester_2.id )
    create_card!(:name => 'Card #4', :owner => owner_3.id, :tester => tester_1.id )

    template = %{
      {{
        pivot-table
          rows: owner
          columns: tester
          links: false
          empty-rows: false
          empty-columns: true
      }}
    }

    render_result = render(template, @project)
    assert_equal_ignoring_spaces <<-HTML, render_result
    <table><tbody><tr>
          <th> </th>
          <th>member@email.com (member) </th>
          <th>owner (a_owner2) </th>
          <th>owner (a_owner3) </th>
          <th>owner (owner1) </th>
          <th>proj_admin@email.com (proj_admin) </th>
          <th>tester (test1) </th>
          <th>tester (test2) </th>
          <th>(not set) </th>
        </tr>
        <tr>
          <th>owner (a_owner2) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 2 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>owner (a_owner3) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 1 </td>
          <td>  </td>
          <td>  </td>
        </tr>
        <tr>
          <th>owner (owner1) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 1 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>(not set) </th>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td>  </td>
          <td> 8 </td>
        </tr></tbody></table>
    HTML
  end

  # fix for bug #2546
  def test_should_create_link_with_is_not_filter_when_not_equal_to_condition_is_present
    template = %{
      {{
        pivot-table
          conditions: old_type = story AND Iteration = 1 AND Status != 'Closed'
          rows: Feature
          columns: Size
          aggregation: SUM(Size)
          totals: false
          links: true
          empty-rows: false
          empty-columns: false
      }}
    }

    render_result = render(template, @project)
    assert_mql_filter_paramter_not_present_in(render_result, 'Status = Closed')
    assert_mql_filter_parameter_present_in(render_result, 'Status != Closed')
  end

  # fix for bug #2525
  def test_pivot_table_should_support_card_type
   with_new_project do |project|
      project.card_types.create(:name => 'defect')
      project.card_types.create(:name => 'story')
      setup_property_definitions :status => ['open', 'close']
      defect = project.card_types.find_by_name('defect')
      story = project.card_types.find_by_name('story')
      status = project.find_property_definition('status')
      status.card_types = [defect, story]
      status.save
      create_card!(:name => 'I am defect 1', :card_type => defect)
      create_card!(:name => 'I am story 1', :card_type => story)
      template = %{
         {{
           pivot-table
             conditions: Type in (story, defect)
             rows: Type
             columns: status
             empty-rows: false
             empty-columns: false
             totals: true
         }}
      }

     render_result = render(template, project)
     assert_not_include 'Error in pivot-table', render_result
   end
  end

  # fix for bug #2622
  def test_pivot_table_should_work_when_column_or_row_has_apostrophe
    with_new_project do |project|
      setup_property_definitions(:foo => ["bar's", 'barbar', 'foobar'], :status => ["relax'd", 'anxious'])

      card_type = project.card_types.find_by_name('Card')
      create_card!(:name => 'timmy', :card_type => card_type, :status => "relax'd")
      create_card!(:name => 'jimmy', :card_type => card_type, :status => "anxious")

      template = %{
          {{
            pivot-table
              conditions: type = Card
              rows: foo
              columns: status
              empty-rows: true
              empty-columns: false
              totals: true
          }}
      }

      render_result = render(template, project)
      assert_not_include ERROR_PREFIX, render_result
    end
  end

  # sign-off issue for story #2613
  def test_should_be_able_to_aggregate_the_same_column_as_the_column_property
    Card.destroy_all
    create_card!(:name => 'low nil', :priority => 'low', :size => nil)
    create_card!(:name => 'low nil', :priority => 'low', :size => nil)
    (1..3).each do |size|
      create_card!(:name => "high #{size}", :priority => 'high', :size => size)
      create_card!(:name => "high #{size}", :priority => 'high', :size => size)
    end

    template = %{
      {{
        pivot-table:
          conditions:
          rows: priority
          columns: 'size'
          empty-columns: false
          empty-rows: false
          aggregation: Sum('size')
          totals: true
      }}
    }

    render_result = strip_all_except_table_and_values(render(template, @project))

    assert_include "<th>1</th>", render_result
    assert_include "<th>2</th>", render_result
    assert_include "<th>3</th>", render_result
    assert_include "<th>high</th>", render_result
    assert_include "<th>low</th>", render_result
    assert_include "<th>Totals</th>", render_result
    assert_include '<td>0</td>', render_result
    assert_include '<td>2</td>', render_result
    assert_include '<td>4</td>', render_result
    assert_include '<td>6</td>', render_result
  end

  def test_should_be_able_to_pivot_on_a_formula_property
    template = %{
      {{
        pivot-table:
          rows: 'size'
          columns: 'half'
          empty-columns: true
          empty-rows: true
      }}
    }

    render_result = render(template, @project)
    assert_mql_filter_parameter_present_in(render_result, 'Size = 5 AND half = \'2.5\'')
  end

  def test_should_be_able_use_numerics_with_trailing_zeros_in_conditions
    create_card!(:name => 'I am card 1', :size => '9.00')
    template1 = %{
      {{
        pivot-table:
          conditions: size = '9.00'
          rows: status
          columns: size
          empty-columns: true
          empty-rows: true
      }}
    }

    render_result = strip_all_except_table_and_values render(template1, @project)
    assert render_result.include?("<td>1</td>")
  end

  def test_should_be_the_same_results_when_pivot_table_rows_and_columns_are_transposed_for_numeric_properties
    create_card!(:name => 'I am card 1', :size => '9.00')
    template1 = %{
      {{
        pivot-table:
          conditions: size = 9
          rows: 'size'
          columns: 'status'
          empty-columns: true
          empty-rows: true
      }}
    }

    render_result = strip_all_except_table_and_values render(template1, @project)
    assert render_result.include?("<td>1</td>")

    template2 = %{
      {{
        pivot-table:
          conditions: size = 9
          rows: 'status'
          columns: 'size'
          empty-columns: true
          empty-rows: true
      }}
    }
    render_result = strip_all_except_table_and_values render(template2, @project)
    assert render_result.include?("<td>1</td>")
  end

  def test_should_maintain_project_precision_in_header_rows_when_performing_aggregation
    create_card!(:name => 'I am card 7', :size => '7.0')
    create_card!(:name => 'I am card 8', :size => '8.000', :status => 'open')
    create_card!(:name => 'I am card 1', :size => '9.00', :status => 'open')
    create_card!(:name => 'I am card 2', :size => '9.01', :status => 'open')
    create_card!(:name => 'I am card 2', :size => '9.125', :status => 'open')
    template1 = %{
      {{
        pivot-table:
          conditions:
          aggregation: SUM(SIZE)
          rows: Size
          columns: Status
          empty-rows: false
          empty-columns: false
          totals: true
      }}
    }
    render_result =  strip_all_except_table_and_values render(template1, @project)
    assert render_result.include?("<th>7.0</th>")
    assert render_result.include?("<th>8.00</th>")
    assert render_result.include?("<th>9.00</th>")
    assert render_result.include?("<th>9.01</th>")
    assert render_result.include?("<th>9.13</th>")
  end

  def test_should_maintain_project_precision_in_header_columns_when_performing_aggregation
    create_card!(:name => 'I am card 7', :size => '7.0')
    create_card!(:name => 'I am card 8', :size => '8.000', :status => 'open')
    create_card!(:name => 'I am card 1', :size => '9.00', :status => 'open')
    create_card!(:name => 'I am card 2', :size => '9.01', :status => 'open')
    create_card!(:name => 'I am card 2', :size => '9.125', :status => 'open')
    template1 = %{
      {{
        pivot-table:
          conditions:
          aggregation: SUM(SIZE)
          rows: Status
          columns: Size
          empty-rows: false
          empty-columns: false
          totals: true
      }}
    }
    render_result =  strip_all_except_table_and_values render(template1, @project)
    assert render_result.include?("<th>7.0</th>")
    assert render_result.include?("<th>8.00</th>")
    assert render_result.include?("<th>9.00</th>")
    assert render_result.include?("<th>9.01</th>")
    assert render_result.include?("<th>9.13</th>")

    template2 = %{
      {{
        pivot-table:
          conditions:
          aggregation: SUM(SIZE)
          rows: Status
          columns: Size
          empty-rows: false
          empty-columns: false
          totals: true
      }}
    }
    render_result =  strip_all_except_table_and_values render(template2, @project)
    assert render_result.include?("<th>7.0</th>")
    assert render_result.include?("<th>8.00</th>")
    assert render_result.include?("<th>9.00</th>")
    assert render_result.include?("<th>9.01</th>")
    assert render_result.include?("<th>9.13</th>")
  end

  def test_should_produce_correct_pivot_table_when_performing_aggregation_with_numeric_columns
    template1 = %{
      {{
        pivot-table:
          conditions:
          aggregation: SUM(SIZE)
          rows: Status
          columns: Size
          empty-rows: false
          empty-columns: false
          totals: true
      }}
    }

    expected = <<-HTML
      <table><tbody><tr>
          <th></th>
          <th>1</th>
          <th>2</th>
          <th>3</th>
          <th>5</th>
        </tr>
        <tr>
          <th>New</th>
          <td>1</td>
          <td></td>
          <td>3</td>
          <td></td>
        </tr>
        <tr>
          <th>InProgress</th>
          <td></td>
          <td>2</td>
          <td></td>
          <td>5</td>
        </tr>
        <tr>
          <th>Closed</th>
          <td>1</td>
          <td>2</td>
          <td></td>
          <td></td>
        </tr>
        <tr>
          <th>(notset)</th>
          <td></td>
          <td></td>
          <td></td>
          <td>10</td>
        </tr>
        <tr>
          <th>Totals</th>
          <td>2</td>
          <td>4</td>
          <td>3</td>
          <td>15</td>
        </tr></tbody></table>
    HTML
    render_result =  render(template1, @project)
    assert_equal strip_all_except_table_and_values(expected), strip_all_except_table_and_values(render_result)
  end

  def test_for_bug_2982
    template = %{
      {{
        pivot-table:
          aggregation:
          rows: Status
          columns: Size
      }}
    }
    render_result = render(template, @project)
    assert !render_result.include?("Could not parse query")
  end

  # bug 2966.
  def test_should_not_lose_totals_on_numerics_with_zeros_after_decimal
    Card.destroy_all
    create_card!(:name => 'I am card', :size => '0.0', :status => 'open')
    create_card!(:name => 'I am card', :size => '2', :status => 'open')
    create_card!(:name => 'I am card', :size => '8.0', :status => 'open')
    create_card!(:name => 'I am card', :size => '16.00', :status => 'open')
    create_card!(:name => 'I am card', :size => '17.10', :status => 'open')
    template = %{
      {{
        pivot-table:
          conditions:
          aggregation: SUM(SIZE)
          rows: Status
          columns: Size
          empty-rows: false
          empty-columns: false
          totals: true
      }}
    }

    expected_result = <<-HTML
      <table><tbody><tr>
          <th></th>
          <th>0.0</th>
          <th>2</th>
          <th>8.0</th>
          <th>16.00</th>
          <th>17.10</th>
        </tr>
        <tr>
          <th>open</th>
          <td>0</td>
          <td>2</td>
          <td>8</td>
          <td>16</td>
          <td>17.1</td>
        </tr>
        <tr>
          <th>Totals</th>
          <td>0</td>
          <td>2</td>
          <td>8</td>
          <td>16</td>
          <td>17.1</td>
        </tr></tbody></table>
    HTML
    render_result = strip_all_except_table_and_values render(template, @project)
    assert_equal_ignoring_spaces expected_result, render_result
  end

  # Bug 2974.
  def test_should_work_with_hidden_properties
    with_new_project do |project|
      setup_property_definitions(:size => ['1', '2'], :status => ['open'])
      ['size', 'status'].each { |property_name| project.find_property_definition(property_name).update_attribute(:hidden, true) }

      card_type = project.card_types.find_by_name('Card')
      create_card!(:name => 'timmy', :card_type => card_type, :status => 'open', :size => '1')
      create_card!(:name => 'jimmy', :card_type => card_type, :status => 'open', :size => '2')

      template = %{
          {{
            pivot-table
              conditions: type = Card
              rows: size
              columns: status
              empty-rows: true
              empty-columns: false
              totals: true
          }}
      }

      render_result = render(template, project)
      assert_not_include ERROR_PREFIX, render_result
    end
  end

  # Bug 3101.
  # TODO the assertion does not make sense for the test name
  def test_should_display_links_for_not_set_columns_and_rows
    Card.destroy_all
    create_card!(:name => 'tiny tim',            :size => '1', :feature => 'Dashboard')
    create_card!(:name => 'jumbo jim',           :size => '1',                          :status => 'New')
    create_card!(:name => 'mini mim',            :size => '1', :feature => 'Dashboard', :status => 'New')
    create_card!(:name => 'kind-of-average kim', :size => '1')
    template = %{
      {{
        pivot-table:
          conditions:
          aggregation: SUM(size)
          rows: status
          columns: feature
          empty-rows: false
          empty-columns: false
          totals: true
      }}
    }

    render_result = render(template, @project)
    assert_not_include "<td>\n1    </td>", render_result
    assert_include "<td>\n2    </td>", render_result
  end

  def test_should_be_able_to_use_relationship_properties
    with_new_project do |project|
      project.add_member(User.find_by_login('member'))
      init_planning_tree_types
      create_three_level_tree

      template = %{
        {{
          pivot-table:
            conditions:
            aggregation: COUNT(*)
            rows: Planning release
            columns: Planning iteration
            empty-rows: true
            empty-columns: true
            links: false
            totals: true
        }}
      }

      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      release1 = project.cards.find_by_name('release1')

      expected = <<-HTML
        <table><tbody><tr>
           <th> </th>
           <th><a href="/projects/#{@project.identifier}/cards/#{iteration1.number}" class="card-link-#{iteration1.number}">##{iteration1.number}</a> #{iteration1.name} </th>
           <th><a href="/projects/#{@project.identifier}/cards/#{iteration2.number}" class="card-link-#{iteration2.number}">##{iteration2.number}</a> #{iteration2.name} </th>
           <th>(not set) </th>
         </tr>
         <tr>
           <th><a href="/projects/#{@project.identifier}/cards/#{release1.number}" class="card-link-#{release1.number}">##{release1.number}</a> #{release1.name} </th>
           <td> 2 </td>
           <td>  </td>
           <td> 2 </td>
         </tr>
         <tr>
           <th>(not set) </th>
           <td>  </td>
           <td>  </td>
           <td> 1 </td>
         </tr>
         <tr>
           <th>Totals </th>
           <td> 2 </td>
           <td>  </td>
           <td> 3 </td>
         </tr></tbody></table>
      HTML

      render_result = render(template, project)
      assert_equal_ignoring_spaces strip_all_except_table_and_values(expected), strip_all_except_table_and_values(render_result)
    end
  end

  # bug 3632
  def test_should_be_able_to_use_relationship_properties_and_set_empty_rows_to_false_without_it_blowing_up
    with_new_project do |project|
      project.add_member(User.find_by_login('member'))
      init_planning_tree_types
      create_three_level_tree

      template = %{
        {{
          pivot-table:
            conditions:
            aggregation: COUNT(*)
            rows: "Planning release"
            columns: 'Planning iteration'
            empty-rows: false
            empty-columns: true
            links: false
            totals: true
        }}
      }

      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      release1 = project.cards.find_by_name('release1')

      expected = <<-HTML
        <table><tbody><tr>
            <th> </th>
            <th><a href="/projects/#{@project.identifier}/cards/#{iteration1.number}" class="card-link-#{iteration1.number}">##{iteration1.number}</a> #{iteration1.name} </th>
            <th><a href="/projects/#{@project.identifier}/cards/#{iteration2.number}" class="card-link-#{iteration2.number}">##{iteration2.number}</a> #{iteration2.name} </th>
            <th>(not set) </th>
          </tr>
          <tr>
            <th><a href="/projects/#{@project.identifier}/cards/#{release1.number}" class="card-link-#{release1.number}">##{release1.number}</a> #{release1.name} </th>
            <td> 2 </td>
            <td>  </td>
            <td> 2 </td>
          </tr>
          <tr>
            <th>(not set) </th>
            <td>  </td>
            <td>  </td>
            <td> 1 </td>
          </tr>
          <tr>
            <th>Totals </th>
            <td> 2 </td>
            <td>  </td>
            <td> 3 </td>
          </tr></tbody></table>
      HTML

      render_result = render(template, project)
      assert_equal_ignoring_spaces strip_all_except_table_and_values(expected), strip_all_except_table_and_values(render_result)
    end
  end

  def test_bug3357
    with_new_project do |project|
      project.add_member(User.find_by_login('member'))
      setup_numeric_text_property_definition('any_number_size')
      setup_numeric_property_definition('managed_number_size', [3, 8])

      card_type = project.card_types.find_by_name('Card')
      create_card!(:name => 'card1', :card_type => card_type, :any_number_size => '4.0', :managed_number_size => '3')
      create_card!(:name => 'card2', :card_type => card_type, :any_number_size => '4', :managed_number_size => '8')
      create_card!(:name => 'card3', :card_type => card_type, :any_number_size => '4.00', :managed_number_size => '8')

      template = %{
          {{
            pivot-table:
              conditions: Type = Card
              aggregation: SUM(managed_number_size)
              rows: managed_number_size
              columns: any_number_size
              empty-rows: true
              empty-columns: true
              totals: true
          }}
      }

      render_result = render(template, project)
      assert render_result.include?("19")
    end
  end

  #Bug 2646.
  def test_should_have_links_for_not_set_column
    template = %{
        {{
          pivot-table:
            conditions: Name = "Blah 6"
            rows: feature
            columns: status
            empty-rows: false
            empty-columns: false
            totals: false
        }}
    }

    rendered_result = render(template, @project)
    assert_mql_filter_parameter_present_in(rendered_result, "Name = 'Blah 6' AND Feature IS NULL")
    assert_mql_filter_parameter_present_in(rendered_result, "Name = 'Blah 6' AND Status IS NULL")
  end

  def test_can_use_this_card_with_pivot_table_macro
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')

    [[1, 'new'], [1, 'open'], [2, 'new']].each do |size, status|
      card = @project.cards.create!(:name => "#{status} #{size} - with related card", :cp_size => size, :cp_status => status, :card_type_name => 'Card')
      related_card_property_definition.update_card(card, this_card)
      card.save!
      @project.cards.create!(:name => "#{status} #{size} - without related card", :cp_size => size, :cp_status => status, :card_type_name => 'Card')
    end

    expected = <<-HTML
      <table><tbody><tr>
          <th> </th>
          <th>1 </th>
          <th>2 </th>
        </tr>
        <tr>
          <th>open </th>
          <td> 1 </td>
          <td>  </td>
        </tr>
        <tr>
          <th>New </th>
          <td> 1 </td>
          <td> 1 </td>
        </tr>
        <tr>
          <th>Totals </th>
          <td> 2 </td>
          <td> 1 </td>
        </tr></tbody></table>
    HTML

    template = %{
      {{
        pivot-table
          conditions: 'related card' = THIS CARD
          rows: status
          columns: size
          aggregation: count(*)
          empty-rows: false
          empty-columns: false
          totals: true
          links: true
      }}
    }

    rendered_result = render(template, @project, :this_card => this_card)
    assert_equal_ignoring_spaces expected, strip_all_except_table_and_values(rendered_result)

    related_card_bound_to_this_card = "'related card' = NUMBER #{this_card.number}"
    sizes = ['1', '2']
    sizes.each do |size| #column heading links
      assert_mql_filter_parameter_present_in(rendered_result, "#{related_card_bound_to_this_card} AND Size = #{size}")
    end

    statuses = ['open', 'New']
    statuses.each do |status| #row heading links
      assert_mql_filter_parameter_present_in(rendered_result, "#{related_card_bound_to_this_card} AND Status = #{status}")
    end
    sizes.each do |size|
      statuses.each do |status|
        unless (size == '2' && status == 'open')
          assert_mql_filter_parameter_present_in(rendered_result, "#{related_card_bound_to_this_card} AND Status = #{status} AND Size = #{size}")
        end
      end
    end

  end

  def test_this_card_alert_message_should_appear_when_content_provider_is_card_defaults
    card_defaults = @project.card_types.first.card_defaults
    related_card_property_definition = @project.find_property_definition('related card')

    [[1, 'new'], [1, 'open'], [2, 'new']].each do |size, status|
      @project.cards.create!(:name => "#{status} #{size} - without related card", :cp_size => size, :cp_status => status, :card_type_name => 'Card')
    end

    template = %{
      {{
        pivot-table
          conditions: 'related card' = THIS CARD
          rows: status
          columns: size
          aggregation: count(*)
          empty-rows: false
          empty-columns: false
          totals: true
          links: true
      }}
    }

    rendered_result = render(template, @project, :this_card => card_defaults)
    assert_match(/Macros using .*THIS CARD.* will be rendered when card is created using this card default/, rendered_result)
  end

  # bug 4829; note -- the issue that this tests is to do with all our tables, not just pivot table
  def test_error_in_second_pivot_table_should_not_prevent_first_pivot_table_from_rendering_correctly
    with_filtering_tree_project do |project|

      expected = <<-HTML
        <table><tbody><tr>
            <th> </th>
            <th>#3 iteration1 </th>
            <th>#4 iteration2 </th>
            <th>#5 iteration3 </th>
            <th>#6 iteration4 </th>
            <th>(not set) </th>
          </tr>
          <tr>
            <th>open </th>
            <td>  </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
          </tr>
          <tr>
            <th>closed </th>
            <td>  </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
          </tr>
          <tr>
            <th>(not set) </th>
            <td> 1 </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
          </tr>
          <tr>
            <th>Totals </th>
            <td> 1 </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
            <td>  </td>
          </tr></tbody></table>
      HTML

      expected_error = %{
        <div contenteditable="false" class="error macro">Error in pivot-table macro: parse error on value &quot;IN&quot; (IN). You may have a project variable, property, or tag with a name shared by a MQL keyword.  If this is the case, you will need to surround the variable, property, or tags with quotes.</div>
}
      # the problem that needs to remain in this template is that the second table has spaces before the opening braces
      template = %{
        {{
          pivot-table
            conditions: type = 'Story' and 'Planning iteration' = 'iteration1'
            rows: status
            columns: 'Planning iteration'
            empty-rows: true
            empty-columns: true
            totals: true
            links: false
        }}

        {{
          pivot-table
            conditions: type = 'Story' and 'Planning iteration' = 'Planning iteration' IN ('iteration1', 'iteration2')
            rows: 'Planning iteration'
            columns: size
            empty-rows: false
            empty-columns: false
            totals: true
            links: false
        }}
      }
      rendered_result = Nokogiri::HTML::DocumentFragment.parse(render(template, project))
      tables = rendered_result.search('table')
      assert_equal 1, tables.size
      rows = tables.search('tr')
      space_char = Nokogiri::HTML::DocumentFragment.parse('&nbsp;').text

      assert_equal [space_char, '#3 iteration1', '#4 iteration2', '#5 iteration3', '#6 iteration4', '(not set)'], rows.first.search('th').map(&:inner_text).map(&:strip)

      assert_equal ["open"], rows[1].search('th').map(&:inner_text).map(&:strip)
      assert_equal [space_char, space_char, space_char, space_char, space_char], rows[1].search('td').map(&:inner_text).map(&:strip)

      assert_equal ["closed"], rows[2].search('th').map(&:inner_text).map(&:strip)
      assert_equal [space_char, space_char, space_char, space_char, space_char], rows[2].search('td').map(&:inner_text).map(&:strip)

      assert_equal ["(not set)"], rows[3].search('th').map(&:inner_text).map(&:strip)
      assert_equal ["1", space_char, space_char, space_char, space_char], rows[3].search('td').map(&:inner_text).map(&:strip)

      assert_equal ["Totals"], rows[4].search('th').map(&:inner_text).map(&:strip)
      assert_equal ["1", space_char, space_char, space_char, space_char], rows[4].search('td').map(&:inner_text).map(&:strip)

      div_with_error = rendered_result.search("div.error")
      assert_equal 1, div_with_error.length
      assert_equal "Error in pivot-table macro: parse error on value \"IN\" (IN). You may have a project variable, property, or tag with a name shared by a MQL keyword.  If this is the case, you will need to surround the variable, property, or tags with quotes.", div_with_error.inner_text.gsub(/[\n\r]/, '')
    end
  end

  def test_can_use_plv
    create_plv!(@project, :name => 'my_rows'       , :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Feature')
    create_plv!(@project, :name => 'my_columns'    , :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Status')
    create_plv!(@project, :name => 'my_aggregation', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'SUM(Size)')
    create_plv!(@project, :name => 'my_totals'     , :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'true')
    create_plv!(@project, :name => 'my_links'      , :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'false')
    create_plv!(@project, :name => 'my_conditions' , :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'old_type = story AND Iteration = 1')

    template = %{
      {{
        pivot-table
          conditions: (my_conditions)
          rows: (my_rows)
          columns: (my_columns)
          aggregation: (my_aggregation)
          totals: (my_totals)
          links: (my_links)
      }}
    }

    render_result = render(template, @project)

    # titles
    assert_include_ignoring_spaces "<th></th>", render_result
    assert_include_ignoring_spaces "<th>New</th>", render_result
    assert_include_ignoring_spaces "<th>In Progress</th>", render_result
    assert_include_ignoring_spaces "<th>Done</th>", render_result
    assert_include_ignoring_spaces "<th>Closed</th>", render_result
    assert_include_ignoring_spaces "<th>(not set)</th>", render_result

    # totals
    assert_include_ignoring_spaces "<th>Totals</th>", render_result
    assert_include_ignoring_spaces "<td>4</td>", render_result
    assert_include_ignoring_spaces "<td>7</td>", render_result
    assert_include_ignoring_spaces "<td></td>", render_result
    assert_include_ignoring_spaces "<td>3</td>", render_result
    assert_include_ignoring_spaces "<td>5</td>", render_result
  end

  # Bug 7057
  def test_formula_rows_and_columns_should_work_with_no_links
    template = %{
      {{
        pivot-table:
          rows: 'size'
          columns: 'half'
          empty-columns: true
          empty-rows: true
          links: false
      }}
    }

    expected_column_headers = <<-HTML
      <tr>
        <th> </th>
        <th>0.5 </th>
        <th>1 </th>
        <th>1.5 </th>
        <th>2.5 </th>
        <th>(not set) </th>
      </tr>
    HTML

    render_result = render(template, @project)
    assert_include_ignoring_spaces expected_column_headers, render_result
  end

  # Bug 6158
  def test_name_and_number_should_not_be_added_as_column_when_linking_from_pivot_table
    template = %{
      {{
        pivot-table:
          rows: name
          columns: number
          totals: false
          empty-rows: false
          empty-columns: false
      }}
    }

    render_result = render(template, @project)
    assert_not render_result.include?('columns=')
  end

  # Bug 6158
  def test_should_include_columns_that_are_not_name_or_number
    template = %{
      {{
        pivot-table:
          rows: size
          columns: half
          totals: false
          empty-rows: false
          empty-columns: false
      }}
    }

    render_result = render(template, @project)
    assert render_result.include?('columns=')
  end

  private

  def query_params_for_saved_view(*filters)
    result = CardListView.construct_from_params(@project, :filters => filters).add_column('Feature').add_column('Status')
    url_options = {:project_id => @project.identifier, :controller => 'cards', :action => 'list'}.merge(result.to_params)
    view_helper.url_for(url_options)
  end


  def strip_all_except_table_and_values(html)
    [/<a .*\">/, /<a .*\'>/, /<\/a>/].inject(html) { |html, remove_regex| html.gsub(remove_regex, '')}.strip_all
  end

  def assert_mql_filter_parameter_present_in(rendered_content, mql_string)
    assert rendered_content =~ mql_filter_matching_pattern_for(mql_string), "regex: #{mql_filter_matching_pattern_for(mql_string).inspect}\ndoes not match:\n#{rendered_content}"
  end

  def assert_mql_filter_paramter_not_present_in(rendered_content, mql_string)
    assert rendered_content !~ mql_filter_matching_pattern_for(mql_string), "regex: #{mql_filter_matching_pattern_for(mql_string).inspect}\nmatch:\n#{rendered_content}"
  end

  def mql_filter_matching_pattern_for(mql_string)
    query_param_boundry = "&amp;"
    mql_filter_param_name = Regexp::escape(CGI.escape("filters[mql]")) + '='
    a_group_of_non_query_param_boundary_characters = "([^&]*)"
    search_string = Regexp::escape(CGI.escape(mql_string))

    regexp_pattern_string = [query_param_boundry, mql_filter_param_name, a_group_of_non_query_param_boundary_characters, search_string, a_group_of_non_query_param_boundary_characters, query_param_boundry].join
    Regexp::new(regexp_pattern_string)
  end
end
