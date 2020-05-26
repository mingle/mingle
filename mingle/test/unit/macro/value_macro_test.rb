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

class ValueMacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    @member = login_as_member
    @project = value_macro_test_project
    @project.activate
  end

  def test_can_render_value_for_non_host_project
    @project.add_member(User.find_by_login('member'))
    first_project.with_active_project do |host_project|
      assert_equal_ignoring_spaces '15',
        render(%{
          {{ value
               query: SELECT SUM(Size) WHERE Iteration IN (2, 3)
               project: #{@project.identifier}
          }}
        }, host_project)
    end
  end

  def test_should_render_in_edit_mode
    @project.add_member(User.find_by_login('member'))
    template = %{
      {{ value
           query: SELECT count(*)
      }}
    }
    expected = Nokogiri::HTML::DocumentFragment.parse("<span contenteditable=\"false\" raw_text=\"#{URI.escape(template.strip)}\" class=\"macro\">10</span>").to_xhtml
    assert_equal expected, render(template, @project, {}, :formatted_content_editor).strip
  end

  #bug 3835
  def test_query_non_number_result
    assert_equal_ignoring_spaces 'blah',
      render('{{ value query: SELECT NAME WHERE Name="blah" }}', @project)
  end

  def test_can_sum_values
    assert_equal_ignoring_spaces '15',
      render('{{ value query: SELECT SUM(Size) WHERE Iteration IN (2, 3) }}', @project)
  end

  def test_should_display_2_decimal_places
    assert_equal_ignoring_spaces '14',
      render('{{ value query: SELECT SUM(Size) WHERE Name IN ("Blah") }}', @project)
  end

  def test_can_be_cached
    assert template_can_be_cached?('{{ value query: SELECT SUM(Size) WHERE Iteration IN (2, 3) }}', @project)
    assert !template_can_be_cached?('{{ value query: SELECT SUM(Size) WHERE Iteration IN (2, 3) AND Owner IS CURRENT USER }}', @project)
    assert !template_can_be_cached?('{{ value query: SELECT SUM(Size) }}{{ value query: SELECT SUM(Size) WHERE Owner IS CURRENT USER }}', @project)
  end

  def test_for_empty_query
    assert_equal_ignoring_spaces '0',
      render('{{ value query: SELECT SUM(Size) WHERE Iteration IN (4, 5) }}', @project)
  end

  def test_can_have_text_property_in_where_clause
    assert_equal_ignoring_spaces '15',
      render('{{ value query: SELECT SUM(Size) WHERE freetext IN ("two", "three") }}', @project)
  end

  def test_cannot_sum_on_non_numeric_text_property
    render_result = render('{{ value query: SELECT SUM(freetext) WHERE Iteration IN (2, 3) }}', @project)
    error_message = "Error in value macro using #{@project.name} project: Property #{'freetext'.bold} is not numeric, only numeric properties can be aggregated."
    assert render_result.include?(error_message)
  end

  def test_should_follow_project_precision
    card1 = create_card!(:name => 'I am card 3', :size => '1.511', :status => 'open')
    card2 = create_card!(:name => 'I am card 4', :size => '1.524', :status => 'open')
    assert_equal_ignoring_spaces '3.03',
      render("{{ value query: SELECT SUM(Size) WHERE number in (#{card1.number}, #{card2.number}) }}", @project)
  end

  def test_can_sum_on_text_property_if_all_values_are_numeric
    assert_equal_ignoring_spaces '15',
      render('{{ value query: SELECT SUM(freesize) WHERE Iteration IN (2, 3) }}', @project)
  end

  def test_can_have_date_property_in_where_clause
    assert_equal_ignoring_spaces '15',
      render('{{ value query: SELECT SUM(Size) WHERE date_created IN ("2007-01-02", "2007-01-03") }}', @project)
  end

  def test_can_count_star_over_date_properties
    assert_equal_ignoring_spaces '5',
      render('{{ value query: SELECT COUNT(*) WHERE date_created IN ("2007-01-02", "2007-01-03") }}', @project)
  end

  def test_cannot_count_directly_using_date_property
    render_result = render('{{ value query: SELECT COUNT(date_created) WHERE Iteration IN (2, 3) }}', @project)
    error_message = "Error in value macro using #{@project.name} project: Property #{'date_created'.bold} is not numeric, only numeric properties can be aggregated."
    assert render_result.include?(error_message)
  end

  def test_should_support_tree
    with_three_level_tree_project do |project|

      template = '{{ value query: SELECT COUNT(*) FROM TREE "three level tree" }}'

      render_result = render(template, project)
      assert_include project.cards.length.to_s, render_result

      not_in_tree = create_card!(:name => 'card not in tree', :number => 10)
      render_result = render(template, project)
      assert_include (project.cards.length-1).to_s , render_result
    end
  end

  def test_cannot_sum_over_date_property
    render_result = render('{{ value query: SELECT SUM(date_created) WHERE Iteration IN (2, 3) }}', @project)
    error_message = "Error in value macro using #{@project.name} project: Property #{'date_created'.bold} is not numeric, only numeric properties can be aggregated."
    assert render_result.include?(error_message)
  end

  def test_this_card
    with_card_query_project do |project|
      this_card = project.cards.first
      related_card_property_definition = project.find_property_definition('related card')
      another_card = project.cards.create!(:name => 'another card', :card_type_name => 'Card')
      related_card_property_definition.update_card(another_card, this_card)
      another_card.save!
      assert_equal_ignoring_spaces 'another card', render("{{ value query: SELECT name WHERE 'related card' = THIS CARD }}", project, {:this_card => this_card})
    end
  end

  def test_show_user_display_name_when_select_user_property
    @project.cards.find_by_number(1).update_attribute(:cp_owner, @member)
    assert_equal_ignoring_spaces 'member@email.com (member)',
      render('{{ value query: SELECT owner where number = 1 }}', @project)
  end

  def test_should_render_callback_for_non_preview_mod_on_page_when_async_value_macro_is_enabled
    MingleConfiguration.overridden_to(async_macro_enabled_for: 'value') do
      expected = %{
     <div id="value-macro-test_id-1"></div>
    <script type="text/javascript">
      (function renderAsyncMacro(bindTo, dataUrl) {
        var spinner = $j('<img>', {src: '/images/spinner.gif', class: 'async-macro-loader'});
        $j(bindTo).append(spinner);
        $j.get(dataUrl, function( data ) {
            $j(bindTo).replaceWith( data );
        });
      })('#value-macro-test_id-1', '/projects/#{@project.identifier}/wiki/Dashboard/async_macro_data/1/value' )
    </script>
    }
      actual = render('{{ value query: SELECT NAME WHERE Name="blah" }}', @project)
      assert_equal_ignoring_spaces(expected, actual)
    end
  end

  def test_should_not_render_callback_for_preview_mod_on_page_when_async_value_macro_is_enabled
    MingleConfiguration.overridden_to(async_macro_enabled_for: 'value') do
      expected = 'Blah'
      actual = render('{{ value query: SELECT NAME WHERE Name="blah" }}', @project, {preview: true})
      assert_equal_ignoring_spaces(expected, actual)
    end
  end

  def test_should_render_callback_for_non_preview_mod_on_card_when_async_value_macro_is_enabled
    MingleConfiguration.overridden_to(async_macro_enabled_for: 'value') do
      card = @project.cards.first
      expected = %{
     <div id="value-macro-#{card.id}-1"></div>
    <script type="text/javascript">
      (function renderAsyncMacro(bindTo, dataUrl) {
        var spinner = $j('<img>', {src: '/images/spinner.gif', class: 'async-macro-loader'});
        $j(bindTo).append(spinner);
        $j.get(dataUrl, function( data ) {
            $j(bindTo).replaceWith( data );
        });
      })('#value-macro-#{card.id}-1', '/projects/#{@project.identifier}/cards/async_macro_data/#{card.id}?position=1&type=value' )
    </script>
    }
      actual = render('{{ value query: SELECT NAME WHERE Name="blah" }}', @project, {this_card: card})
      assert_equal_ignoring_spaces(expected, actual)
    end
  end

  def test_should_not_render_callback_for_preview_mod_on_card_when_async_value_macro_is_enabled
    MingleConfiguration.overridden_to(async_macro_enabled_for: 'value') do
      card = @project.cards.first
      expected = 'Blah'
      actual = render('{{ value query: SELECT NAME WHERE Name="blah" }}', @project, {this_card: card, preview: true})
      assert_equal_ignoring_spaces(expected, actual)
    end
  end

  def test_should_not_render_callback_when_column_name_is_number_and_async_value_macro_is_enabled
    MingleConfiguration.overridden_to(async_macro_enabled_for: 'value') do
      card = @project.cards.first
      actual = render("{{ value query: SELECT number WHERE number in (#{card.number}) }}", @project)
      assert_equal(card.number, actual.to_i)
    end
  end
end
