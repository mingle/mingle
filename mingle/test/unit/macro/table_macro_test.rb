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

class TableMacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    login_as_member
    @member = User.find_by_login('member')
    @project = table_macro_test_project
    @project.activate
  end

  # bug 9079
  def test_should_provide_property_not_exist_message_when_preview_content_including_invalid_property_name
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    card_defaults.description = "{{ table query: SELECT name, number WHERE number = this card.number and name = this card.property_not_exists }}"

    assert_dom_content "Error in table macro using table_macro_test_project project: Card property '#{'property_not_exists'.bold}' does not exist!", card_defaults.formatted_content_preview(self)
  end

  def test_render_text_field_for_unmanaged_numeric_properties
    template = %{{{
    table
      query: SELECT number, numeric_free_text
      edit-any-number-property: true
    }}}
    assert Nokogiri::HTML::DocumentFragment.parse(render(template, @project, :preview => true)).css("input[type='text']").size > 0
  end

  def test_render_should_show_error_when_non_boolean_value_given_to_edit_any_number_property
    template = %{{{
    table
      query: SELECT number, numeric_free_text
      edit-any-number-property: 'boo'
    }}}
    assert_match /Error in table macro: #{'edit-any-number-property'.bold} only accepts boolean \(true, false, yes, no\) values./, render(template, @project, :preview => true)
  end

  def test_only_card_number_and_name_should_be_links_in_table_query_when_number_is_part_of_the_query
    card = create_card! :name => "One", :number => 8, :size => 4
    another = create_card! :name => "Two", :number => 10, :size => 3
    template = "{{ table query: SELECT number, name, size, 'created on' WHERE number IN (#{card.number}, #{another.number}) ORDER BY number }}"
    expected = %{
      <table><tbody><tr>
            <th>Number</th>
            <th>Name</th>
            <th>Size </th>
            <th>Created on </th>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/#{card.number}">#{card.number}</a></td>
            <td><a href="/projects/table_macro_test_project/cards/#{card.number}">#{card.name}</a></td>
            <td>4</td>
            <td>#{@project.format_date(card.created_on)}</td>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/#{another.number}">#{another.number}</a></td>
            <td><a href="/projects/table_macro_test_project/cards/#{another.number}">#{another.name}</a></td>
            <td>3</td>
            <td>#{@project.format_date(card.created_on)}</td>
          </tr></tbody></table>
    }
    assert_include_ignoring_spaces expected, render(template, @project, :preview => true)
  end
  def test_name_should_not_be_link_if_number_is_not_part_of_the_query
    card = create_card! :name => "One", :number => 8, :size => 4
    template = "{{ table query: SELECT name, size WHERE number=#{card.number} }}"
    expected = %{
      <table><tbody><tr>
            <th>Name</th>
            <th>Size </th>
          </tr>
          <tr>
            <td>#{card.name}</td>
            <td>4</td>
          </tr></tbody></table>
    }
    assert_include_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_card_information_should_be_html_escaped
    card = create_card! :name => "<b>hello</b>", :number => 8
    template = "{{ table query: SELECT name WHERE Number = #{card.number} }}"
    expected = %{
      <table><tbody><tr>
          <th>Name </th>
        </tr>
        <tr>
          <td>&lt;b&gt;hello&lt;/b&gt;</td>
        </tr></tbody></table>
    }
    assert_include_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_empty_cell_values_should_not_be_html_escaped
    card = create_card! :name => "<b>eight</b>", :number => 8
    template = "{{ table query: SELECT number, name, 'Related Card' WHERE Number IN (#{card.number}) }}"
    expected = Nokogiri::HTML::DocumentFragment.parse(%{
          <table><tbody><tr>
                <th>Number</th>
                <th>Name</th>
                <th>related card</th>
              </tr>
              <tr>
                <td><a href="/projects/table_macro_test_project/cards/8">8</a></td>
                <td><a href="/projects/table_macro_test_project/cards/8">&lt;b&gt;eight&lt;/b&gt;</a></td>
                <td>&nbsp;</td>
              </tr></tbody></table>
        }, 'utf-8').to_xhtml
    assert_equal_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_various_property_result_types_should_be_html_escaped_and_not_blow_up
    card = create_card! :name => "One", :number => 8, :size => 4
    another = create_card! :name => "Two", :number => 10, :size => 3
    template = "{{ table query: SELECT half, created_on WHERE Number IN (#{card.number}, #{another.number}) }}"
    expected = %{
      <table><tbody><tr>
            <th>half </th>
            <th>Created on </th>
          </tr>
          <tr>
            <td>1.5</td>
            <td>#{@project.format_date(card.created_on)}</td>
          </tr>
          <tr>
            <td>2</td>
            <td>#{@project.format_date(card.created_on)}</td>
          </tr></tbody></table>
    }
    assert_include_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_various_property_result_types_should_be_html_escaped_and_not_blow_up_when_rendered_as_links
    card = create_card! :name => "One", :number => 8, :size => 4
    another = create_card! :name => "Two", :number => 10, :size => 3
    template = "{{ table query: SELECT number, half, created_on WHERE Number IN (8, 10) }}"
    expected = %{
      <table><tbody><tr>
            <th>Number </th>
            <th>half </th>
            <th>Created on </th>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/10">10</a></td>
            <td>1.5</td>
            <td>#{@project.format_date(card.created_on)}</td>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/8">8</a></td>
            <td>2</td>
            <td>#{@project.format_date(card.created_on)}</td>
          </tr></tbody></table>
    }
    assert_include_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_can_render_table_for_non_host_project
    first_project.with_active_project do |host_project|
      expected = %{
        <tr>
          <td>5</td>
          <td>(not set)</td>
          <td>1</td>
        </tr>
      }

      template = %{
        {{
          table
            query: SELECT SUM(size), feature, COUNT(*)
            project: table_macro_test_project
        }}
      }

      assert_include_ignoring_spaces expected, render(template, host_project, :preview => true)
    end
  end

  def test_should_inform_that_a_view_is_not_an_existing_view
    template = "{{ table view: foo }}"
    assert_match /Error in table macro: No such view: #{'foo'.bold}/, render(template, @project, :preview => true)
  end

  def test_should_inform_that_a_personal_favorite_is_not_supported
    me = @project.users.first
    personal_view = @project.card_list_views.create_or_update(:view => {:name => 'my_view'}, :style => 'list', :user_id => me.id)
    template = "{{ table view: my_view }}"
    assert_match /Error in table macro: No such team view: #{'my_view'.bold}\. Only team views can be used with table macro\./, render(template, @project, :preview => true)
  end

  def test_multi_line_description
    expected = %{
      <table><tbody><tr>
          <th>Description </th>
        </tr>
        <tr>
          <td> this is a line.<br/> this is a new line. </td>
        </tr></tbody></table>
    }

    card = create_card!(:name => 'Blah #8', :number => 8, :size => '10', :old_type => 'story', :description => "this is a line.\n this is a new line.")
    template = %{
      {{ table query: SELECT Description WHERE description is not null }}
    }

    assert_equal_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_should_escape_vertical_line
    expected = %{
      <table><tbody><tr>
          <th>Description </th>
        </tr>
        <tr>
          <td>left | right </td>
        </tr></tbody></table>
    }

    card = create_card!(:name => 'Blah #8', :number => 8, :size => '10', :old_type => 'story', :description => "left | right")
    template = %{
      {{ table query: SELECT Description WHERE description is not null }}
    }

    assert_equal_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_can_render_an_aggregated_function
    expected = %{
      <table><tbody><tr>
          <th>Feature </th>
          <th>Sum Size </th>
          <th>Count </th>
        </tr>
        <tr>
          <td> Dashboard </td>
          <td> 1 </td>
          <td> 1 </td>
        </tr>
        <tr>
          <td> Applications </td>
          <td> 3 </td>
          <td> 2 </td>
        </tr>
        <tr>
          <td> Rate calculator </td>
          <td> 5 </td>
          <td> 2 </td>
        </tr>
        <tr>
          <td> Profile builder </td>
          <td> 5 </td>
          <td> 1 </td>
        </tr>
        <tr>
          <td> (not set) </td>
          <td> 5 </td>
          <td> 1 </td>
        </tr></tbody></table>
    }

    template = %{
      {{ table query: SELECT Feature, SUM(Size), COUNT(*) ORDER BY Feature }}
    }

    assert template_can_be_cached?(template, @project)

    assert_equal_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_can_render_a_saved_card_list_view
    create_name_and_status_view
    assert_name_and_status_view_result(@project, "{{ table view: Name and Status }}")
  end

  def test_can_use_quotes_around_view_name
    create_name_and_status_view
    assert_name_and_status_view_result(@project, '{{ table view: "Name and Status" }}')
    assert_name_and_status_view_result(@project, "{{ table view: 'Name and Status' }}")
  end

  # bug 5649
  def test_view_name_is_case_insensitive
    create_name_and_status_view
    assert_name_and_status_view_result(@project, "{{ table view: naMe aNd stAtus }}")
  end

  def test_view_parameter_can_be_a_plv
    create_name_and_status_view
    create_plv!(@project, :name => 'my_view', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Name and Status')
    assert_name_and_status_view_result(@project, "{{ table view: (my_view) }}")
  end

  def test_can_render_a_saved_card_list_view_for_non_host_project_using_plv
    create_name_and_status_view
    create_plv!(@project, :name => 'my_view', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'Name and Status')

    first_project.with_active_project do |host_project|
      create_plv!(host_project, :name => 'my_project', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'table_macro_test_project')

      template = %{
        {{
          table
            view: (my_view)
            project: (my_project)
        }}
      }
      assert_name_and_status_view_result(@project, template)
    end
  end

  def test_user_property_definitions
      owner_1 = create_user!
      owner_2 = create_user!
      [owner_1, owner_2].each { |u|  @project.add_member(u) }
      create_card!(:name => 'Card 1', :number => 8, :owner => owner_1.id)
      create_card!(:name => 'Card 2', :number => 9, :owner => owner_1.id)
      create_card!(:name => 'Card 3', :number => 10, :owner => owner_2.id)

      expected = %{
        <table><tbody><tr>
            <th>Number </th>
            <th>Name </th>
            <th>Owner </th>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/9">9</a></td>
            <td><a href="/projects/table_macro_test_project/cards/9">Card 2</a></td>
            <td><a href="/projects/table_macro_test_project/cards/9">#{owner_1.name_and_login}</a></td>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/8">8</a></td>
            <td><a href="/projects/table_macro_test_project/cards/8">Card 1</a></td>
            <td><a href="/projects/table_macro_test_project/cards/8">#{owner_1.name_and_login}</a></td>
          </tr></tbody></table>
      }

      template = %{
        {{
          table query: SELECT number, name, owner WHERE owner = #{owner_1.login}
        }}
      }

      assert_equal_ignoring_spaces expected , render(template, @project, :preview => true)
  end

  def test_user_property_definitions
      owner = create_user!
      owner.update_attribute(:name, "my <b>great</b> name")

      @project.add_member(owner)
      create_card!(:name => 'Card 1', :number => 8, :owner => owner.id)

      expected = %{
        <table><tbody><tr>
            <th>Number </th>
            <th>Name </th>
            <th>Owner </th>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/8">8</a></td>
            <td><a href="/projects/table_macro_test_project/cards/8">Card 1</a></td>
            <td>#{owner.name_and_login.escape_html}</td>
          </tr></tbody></table>
      }

      template = %{
        {{
          table query: SELECT number, name, owner WHERE owner = #{owner.login}
        }}
      }

      assert_equal_ignoring_spaces expected , render(template, @project, :preview => true)
  end


  def test_text_property_definitions
    create_card!(:name => 'Name 1' , :number => 8,  :freetext1 => 'free one', :freetext2 => "free 1" )
    create_card!(:name => 'Name 2', :number => 9,  :freetext1 => 'free two', :freetext2 => "free 2" )
    create_card!(:name => 'Name 3', :number => 10, :freetext1 => 'free three', :freetext2 => "free 1" )

    expected = %{
      <table><tbody><tr>
          <th>Name </th>
          <th>freetext 1 </th>
        </tr>
        <tr>
          <td>Name 1</td>
          <td>free one</td>
        </tr>
        <tr>
          <td>Name 3</td>
          <td>free three</td>
        </tr></tbody></table>
    }

    template = %{
      {{
        table query: SELECT name, freetext1 WHERE freetext2 = 'free 1' ORDER BY freetext1
      }}
    }

    assert_equal_ignoring_spaces expected , render(template, @project, :preview => true)
  end

  def test_date_property_definitions
    create_card!(:name => 'Name 1', :number => 8,  :date_created => '2007-01-01', :date_deleted => '2007-02-01' )
    create_card!(:name => 'Name 2', :number => 9,  :date_created => '2007-01-02', :date_deleted => '2007-02-02' )
    create_card!(:name => 'Name 3', :number => 10, :date_created => '2007-01-03', :date_deleted => '2007-02-01' )

    expected = %{
      <table><tbody><tr>
          <th>Name </th>
          <th>date_created </th>
        </tr>
        <tr>
          <td>Name 1</td>
          <td>01 Jan 2007</td>
        </tr>
        <tr>
          <td>Name 3</td>
          <td>03 Jan 2007</td>
        </tr></tbody></table>
    }

    template = %{
      {{
        table query: SELECT name, date_created WHERE date_deleted = '2007-02-01' ORDER BY date_created
      }}
    }
    assert_equal_ignoring_spaces expected , render(template, @project, :preview => true)
  end

  # bug 2868.
  def test_should_show_not_set_when_the_group_by_column_is_null_even_if_it_is_not_the_first_column
    expected = %{
      <tr>
        <td>5</td>
        <td>(not set)</td>
        <td>1</td>
      </tr>
    }

    template = %{
      {{
        table query: SELECT SUM(size), feature, COUNT(*)
      }}
    }

    assert_include_ignoring_spaces expected, render(template, @project, :preview => true)
  end

  def test_should_not_replace_textile_markup_in_links
    with_new_project({:prefix => (project_prefix = 'this__has__markup')}) do |project|
      card = project.card_types.find_by_name('Card')
      card_1 = create_card!(:name => 'I have | markup', :card_type => card)
      card_2 = create_card!(:name => 'I have __ markup', :card_type => card)
      card_3 = create_card!(:name => '|', :card_type => card)
      card_4 = create_card!(:name => '__', :card_type => card)
      template = %{
        {{
          table query: SELECT number, name WHERE type='Card'
        }}
      }

      render_result = render(template, project, :preview => true)
      assert_include project_prefix, render_result
      assert_include card_1.name, render_result
      assert_include card_2.name, render_result
      assert_include card_3.name, render_result
      assert_include card_4.name, render_result
    end
  end

  # Bug 3007.
  def test_should_only_allow_list_views
    request_params = {:filters => ['[status][is][new]'], :style => 'grid'}
    view = CardListView.find_or_construct(@project, request_params)
    view.name = 'My Grid'
    view.save!

    assert_include "Table view is only available to list views. #{view.name.bold} is not a list view.", render("{{ table view: #{view.name} }}", @project)
  end

  def test_should_show_correct_decimal_precision_for_formula_property_calculations
     with_new_project do |project|
       setup_numeric_property_definition('size', ['1', '2', '3', '12'])
       setup_formula_property_definition('three point of five', "'size' * 3.5")
       setup_formula_property_definition('one third', "'size' / 3")
       create_card!(:name => 'Name 1', :size => '1')
       create_card!(:name => 'Name 2', :size => '2.0')
       create_card!(:name => 'Name 3', :size => '3')
       create_card!(:name => 'Name 4', :size => '12')
       expected = %{
         <table><tbody><tr>
             <th>Name </th>
             <th>Size </th>
             <th>three point of five </th>
             <th>one third </th>
           </tr>
           <tr>
             <td>Name 1</td>
             <td>1 </td>
             <td>3.5 </td>
             <td>0.33 </td>
           </tr>
           <tr>
             <td>Name 2</td>
             <td>2 </td>
             <td>7 </td>
             <td>0.67 </td>
           </tr>
           <tr>
             <td>Name 3</td>
             <td>3 </td>
             <td>10.5 </td>
             <td>1 </td>
           </tr>
           <tr>
             <td>Name 4</td>
             <td>12 </td>
             <td>42 </td>
             <td>4 </td>
           </tr></tbody></table>
       }

       template = %{
         {{
           table query: SELECT name, size, 'three point of five', 'one third' order by name
         }}
       }
       assert_equal_ignoring_spaces expected , render(template, project, :preview => true)
     end
  end

  # bug 4128
  def test_should_raise_numeric_property_error_message_when_trying_to_campare_two_numeric_property
    template = %{{{
      table
        query: SELECT size WHERE type = card AND size > iteration
    }}}
    expected = %{Error in table macro using #{@project.name} project: Property #{'Size'.bold} is numeric, and value #{'iteration'.bold} is not numeric. Only numeric values can be compared with #{'Size'.bold}. Value #{'iteration'.bold} is a property, please use #{'PROPERTY iteration'.bold}.}

    assert_dom_content expected, render(template, @project, :preview => true)
  end

  def test_should_be_able_to_restrict_with_this_card
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')

    card_a, card_b = [['A', 100], ['B', 101]].collect do |card_name, number|
      card = @project.cards.create!(:name => card_name, :number => number, :card_type_name => 'Card')
      related_card_property_definition.update_card(card, this_card)
      card.save!
      card
    end

    expected = %{
      <table><tbody><tr>
          <th>Name </th>
          <th>Number </th>
        </tr>
        <tr>
          <td><a href="/projects/#{@project.identifier}/cards/#{card_a.number}">A</a></td>
          <td><a href="/projects/#{@project.identifier}/cards/#{card_a.number}">100</a></td>
        </tr>
        <tr>
          <td><a href="/projects/#{@project.identifier}/cards/#{card_b.number}">B</a></td>
          <td><a href="/projects/#{@project.identifier}/cards/#{card_b.number}">101</a></td>
        </tr></tbody></table>
    }

    template = %{
      {{
        table query: SELECT name, number WHERE 'related card' = THIS CARD ORDER BY name
      }}
    }

    assert_equal_ignoring_spaces expected, render(template, @project, {:this_card => this_card, :preview => true})
  end

  def test_mql_this_card_property_errors_are_ignored_when_on_card_defaults
    with_card_query_project do |project|
      some_card_defaults = project.card_types.first.card_defaults
      template = %{
        {{
          table query: SELECT number WHERE 'size' IN (THIS CARD.size)
        }}
      }
      assert_match(/Macros using .*THIS CARD.* will be rendered when card is created using this card default./, render(template, project, { :this_card => some_card_defaults }))
    end
  end

  def test_table_macro_on_card_defaults_page_displays_this_card_message_when_there_are_no_other_errors
    with_three_level_tree_project do |project|
      iteration_card_defaults = project.card_types.find_by_name('iteration').card_defaults

      template = %{
        {{
          table query: SELECT name, jimmy WHERE 'Planning iteration' = THIS CARD
        }}
      }
      assert_match(/Error in table macro using #{project.name} project: Card property .*jimmy.* does not exist!/, render(template, project, {:this_card => iteration_card_defaults}))

      template = %{
        {{
          table query: SELECT number, name WHERE 'Planning iteration' = THIS CARD
        }}
      }
      assert_match(/Macros using .*THIS CARD.* will be rendered when card is created using this card default./, render(template, project, {:this_card => iteration_card_defaults}))
    end
  end

  def test_table_view_macro_should_not_be_cached_when_the_view_contains_today
    create_card!(:name => 'I am card 1', :number => 10, :date_created => Time.now)
    create_card!(:name => 'I am card 2', :number => 11, :date_created => Time.now)
    view = CardListView.find_or_construct(@project, {:filters => ["[date_created][is][(today)]"]})
    view.name = 'I am a list'
    view.save!

    template = %{
      {{
        table view: 'I am a list'
      }}
    }
    assert_false template_can_be_cached?(template, @project)
  end

  def test_table_query_macro_should_support_tree
    with_three_level_tree_project do |project|

      template = %{
        {{
          table query: SELECT number, name FROM TREE 'three level tree'
        }}
      }
      not_in_tree = create_card!(:name => 'card not in tree', :number => 10)
      render_result = render(template, project, :preview => true)

      project.tree_configurations.first.tree_belongings.collect(&:card).each do |card|
        assert_include card.name, render_result
      end
      assert_not_include not_in_tree.name, render_result
    end
  end

  def test_limit_records_loaded_into_memory
    MingleConfiguration.with_macro_records_limit_overridden_to(1) do
      template = "{{ table query: SELECT number order by number}}"
      card = @project.cards.find(:all, :order => 'number').first
      expected = %{
        <table><tbody><tr>
            <th>Number </th>
          </tr>
          <tr>
            <td><a href="/projects/#{@project.identifier}/cards/#{card.number}">#{card.number}</a></td>
          </tr>
          <tr>
            <td class="too-many-records" colspan="1">Only first 1 (of #{@project.cards.count}) records loaded.</td>
          </tr></tbody></table>
      }

      assert_include_ignoring_spaces expected, render(template, @project, :this_card => card, :preview => true)
    end
  end

  def test_should_render_callback_for_non_preview_mod_when_async_table_macro_is_enabled
    MingleConfiguration.overridden_to(async_macro_enabled_for: 'table' ) do
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')

    [['A', 100], ['B', 101]].collect do |card_name, number|
      card = @project.cards.create!(:name => card_name, :number => number, :card_type_name => 'Card')
      related_card_property_definition.update_card(card, this_card)
      card.save!
      card
    end

    expected = %{
     <div id="table-macro-#{this_card.id}-1"></div>
    <script type="text/javascript">
      (function renderAsyncMacro(bindTo, dataUrl) {
        var spinner = $j('<img>', {src: '/images/spinner.gif', class: 'async-macro-loader'});
        $j(bindTo).append(spinner);
        $j.get(dataUrl, function( data ) {
            $j(bindTo).replaceWith( data );
        });
      })('#table-macro-#{this_card.id}-1', '/projects/#{@project.identifier}/cards/async_macro_data/#{this_card.id}?position=1&type=table' )
    </script>
    }

    template = %{
      {{
        table query: SELECT name, number WHERE 'related card' = THIS CARD ORDER BY name
      }}
    }

    assert_equal_ignoring_spaces expected, render(template, @project, {:this_card => this_card})
      end
  end

  def create_name_and_status_view
    request_params = {:filters => ['[status][is][new]', "[assigned to][is][#{@member.login}]"], :sort => 'iteration', :order => 'asc', :page => '1', :columns => 'status'}
    view = CardListView.find_or_construct(@project, request_params)
    view.name = 'Name and Status'
    view.save!
  end

  def assert_name_and_status_view_result(project, template)
    expected = %{
      <table>
        <tbody>
          <tr>
            <th>Number </th>
            <th>Name </th>
            <th>Status </th>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/4">4</a></td>
            <td><a href="/projects/table_macro_test_project/cards/4">Blah #4</a></td>
            <td>New</td>
          </tr>
          <tr>
            <td><a href="/projects/table_macro_test_project/cards/2">2</a></td>
            <td><a href="/projects/table_macro_test_project/cards/2">Blah #2</a></td>
            <td>New</td>
          </tr>
        </tbody>
      </table>
    }
    assert_equal_ignoring_spaces expected, render(template, project, :preview => true)
  end
end
