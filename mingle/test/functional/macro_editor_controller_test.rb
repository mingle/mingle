# -*- coding: utf-8 -*-

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
require File.expand_path(File.dirname(__FILE__) + '/../documentation_test_helper')

class MacroEditorControllerTest < ActionController::TestCase
  include ActionController::Assertions::MacroContentAssertionHelpers
  include DocumentationTestHelper

  def setup
    @controller = create_controller MacroEditorController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  test 'should_show_table_query_macro_editor' do
    xhr :get, :show, :project_id => @project.identifier, :macro_type => 'table-query',:content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :success
    assert_include '[table-query][query]', @response.body
  end

  test 'should_generate_macro_content_for_table_query' do
    xhr :post, :generate, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
      :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :success
    assert_include 'table', @response.body
    end

  test 'generate_should_remove_html_tags_from_macro' do
    xhr :post, :generate, :project_id => @project.identifier,
      :macro_type => 'table-view',
      :macro_editor => {'table-view' => {:view => "invalid view name }} <script>alert('you got xss')</script>"}},
      :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :unprocessable_entity
    assert_not_include"<script>alert('you got xss')</script>", @response.body
  end

  test 'should_store_macro_content_in_session_for_new_renderables' do
    xhr :post, :generate, :project_id => @project.identifier,
        :macro_type => 'table-query',
        :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
        :content_provider => {:provider_type => 'Card', :redcloth => false }

    assert_response :success
    assert_include 'table', @response.body
    assert_not_nil session[:renderable_preview_content]
  end

  test 'should_generate_macro_content_with_unicode_characters_and_encode_them' do
    login_as_admin
    with_new_project do |project|
      # Tests would fail for property with name property with name
      failing_property_name = 'öäå ഏകദേശ അളവ്'

      property_name = 'öäå ഏകദേശ 尺寸'
      project.cards.create!(:name => 'Nice Card', :description => 'card content', :card_type_name => 'Card')
      project.create_any_text_definition!(:name => property_name, :is_numeric  =>  false)
      xhr :post, :generate, :project_id => project.identifier,
        :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => "SELECT \"#{property_name}\""}},
        :content_provider => MacroEditor::ContentProvider.to_params(project.cards.first)

      assert_response :success
      assert_not_include "SELECT \"#{property_name}\"", @response.body

      doc = Nokogiri::HTML::DocumentFragment.parse(@response.body)
      raw_text = doc.xpath('//table').first['raw_text']
      assert_include "SELECT \"#{property_name}\"", URI.decode(raw_text)
    end
  end

  test 'should_update_preview_content_when_request_macro_preview' do
    xhr :post, :preview, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
      :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)

    assert_response :success
    assert_include @project.cards.first.name, @response.body
  end

  test 'should_record_render_content_into_session_for_chart_preview' do
    xhr :post, :preview, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
      :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_not_nil session[:renderable_preview_content]
  end

  test 'new_series_editor_should_support_data_series_chart' do
    xhr :get, :new_series_editor, :macroType => 'data-series-chart', :project_id => @project.identifier, :seriesNumber => 0
    assert_response :success
    assert_match /data-series-chart_series-container-0/, @response.body
    assert_match /data-series-chart_series_0_data-point-symbol_parameter_container/, @response.body
  end

  test 'new_series_editor_should_support_daily_history_chart' do
    xhr :get, :new_series_editor, :macroType => 'daily-history-chart', :project_id => @project.identifier, :seriesNumber => 1
    assert_response :success
    assert_match /daily-history-chart_series-container-1/, @response.body
    assert_match /daily-history-chart_series_1_conditions_parameter_container/, @response.body
  end

  # bug 8812
  test 'should_not_include_a_remove_parameter_button_if_there_is_only_one_parameter' do
    remove_parameter_class = 'remove-optional-parameter'

    # you should be able to remove some of the parameters on the pivot table
    xhr :get, :show, :project_id => @project.identifier, :macro_type => 'pivot-table', :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_match /#{remove_parameter_class}/, @response.body

    # project macro only has one parameter and therefore you should not be able to remove it
    xhr :get, :show, :project_id => @project.identifier, :macro_type => 'project', :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_no_match /#{remove_parameter_class}/, @response.body
  end

  test 'should_render_macro_editor_for_wysiwyg' do
    card = @project.cards.create!(:name => 'wikiwyg', :card_type_name => 'Card')
    xhr :get, :show, :project_id => @project.identifier, :macro_type => 'average', :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_no_match /InputingContexts\.update/, @response.body
    assert_match /<h3>Chart level options<\/h3>/, @response.body
  end

  test 'should_render_macro_editor_for_unsaved_wysiwyg' do
    card = @project.cards.new
    xhr :get, :show, :project_id => @project.identifier, :macro_type => 'average', :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_no_match /InputingContexts\.update/, @response.body
    assert_match /<h3>Chart level options<\/h3>/, @response.body
  end

  test 'should_render_preview_for_wysiwyg' do
    card = @project.cards.create!(:name => 'wikiwyg', :card_type_name => 'Card')
    xhr :post, :preview, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
      :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_no_match /InputingContexts\.update/, @response.body
    assert_match /<table>/, @response.body
  end

  test 'should_generate_macro_for_wysiwyg' do
    card = @project.cards.create!(:name => 'wikiwyg', :card_type_name => 'Card')
    xhr :post, :generate, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
      :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_no_match /InputingContexts\.feed/, @response.body
    assert_match /raw_text/, @response.body
  end

  test 'should_generate_macro_correctly_for_unsaved_wysiwyg' do
    card = Card.new
    xhr :post, :generate, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => 'SELECT number, name'}},
      :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_no_match /InputingContexts\.feed/, @response.body
    assert_match /raw_text/, @response.body
  end

  test 'generate_with_syntax_error_should_return_422_status_and_error_message' do
    card = Card.new
    xhr :post, :generate, :project_id => @project.identifier,
      :macro_type => 'table-query',
      :macro_editor => {'table-query' => {:query => "Oops this isn't even MQL"}},
      :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_response 422
    assert_match /Card property .*Oops.* does not exist!/, @response.body
    assert_match /<b>/, @response.body
  end

  test 'render_macro_replaces_macro_content_for_project_macro' do
    card = @project.cards.first
    get :render_macro, :project_id => @project.identifier, :macro => '{{ project }}', :id => card.id, :type => 'Card'
    assert_response :success
    assert_equal_ignoring_container_element @project.identifier, @response.body
  end

  test 'render_macro_replaces_macro_content_for_value_macro' do
    card = @project.cards.second
    get :render_macro, :project_id => @project.identifier,
        :macro => "{{ value query: select number where number=#{card.number} }}", :id => card.id, :type => 'Card'
    assert_response :success
    assert_equal_ignoring_container_element card.number.to_s, @response.body
  end

  test 'render_macro_replaces_macro_content_for_table_macro' do
    card = @project.cards.second
    get :render_macro, :project_id => @project.identifier, :macro => "{{ table query: select number where number=#{card.number}}}", :id => card.id, :type => 'Card'
    assert_response :success
  end

  test 'render_macro_without_macro_leaves_text_unchanged' do
    get :render_macro, :project_id => @project.identifier, :macro => 'Hi', :id => @project.cards.first.id, :type => 'Card'
    assert_response :success
    assert_equal 'Hi', @response.body
  end

  test 'render_macro_with_project_macro_substitutes_properly' do
    get :render_macro, :project_id => @project.identifier, :macro => 'blah blah {{ project }} blah', :id => @project.cards.first.id, :type => 'Card'
    assert_response :success
    assert_equal_ignoring_container_element "blah blah #{@project.identifier} blah", @response.body
  end

  test 'render_macro_with_error_should_respond_with_422' do
    get :render_macro, :project_id => @project.identifier, :macro => '{{ nonexistent }}', :id => @project.cards.first.id, :type => 'Card'

    assert_response 422
    assert /No such macro: \<b\>nonexistent.*/ =~ @response.body
  end

  test 'should_render_this_card_macro_on_saved_card' do
    get :render_macro, :project_id => @project.identifier, :macro => '{{ value query: select name where number = THIS CARD.number }}', :id => @project.cards.first.id, :type => 'Card'
    assert_equal_ignoring_container_element @project.cards.first.name, @response.body
  end

  test 'should_render_macro_for_new_unsaved_card' do
    get :render_macro, :project_id => @project.identifier, :macro => '{{
      pie-chart
        data: SELECT Name, Count(*) WHERE Type = Card
    }}', :type => 'Card'
    assert /Your pie chart will display upon saving/  =~ @response.body
  end

  test 'should_render_macro_for_unsaved_page' do
    get :render_macro, :project_id => @project.identifier, :macro => '{{ project }}', :type => 'Page'
    assert_equal_ignoring_container_element @project.identifier, @response.body
  end

  test 'should_render_macro_for_saved_page' do
    get :render_macro, :project_id => @project.identifier, :macro => '{{ project }}', :id => @project.pages.first.id, :type => 'Page'
    assert_equal_ignoring_container_element @project.identifier, @response.body
  end

  test 'show_should_render_old_macro_partial_on_show' do
    get :show, :project_id => @project.identifier, :macro_type => 'pivot-table', :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)

    assert_response :success
    assert_include 'id="preview_panel_container"', @response.body
  end

  test 'macro_preview_should_generate_preview_when_macro_format_param_is_set_to_mql' do
    card = @project.cards.first
    xhr :post, :preview, :project_id => @project.identifier,
        :macro_type => 'pie-chart',
        :macro_format => 'mql',
        :macro_editor => "{{pie-chart:\n    data: SELECT status, count(*) where type='Card'}}",
        :content_provider => MacroEditor::ContentProvider.to_params(card)
    assert_response :success
    assert_include "id=\"piechart-Card-#{card.id}-1-preview\"", @response.body
  end

  test 'macro_preview_should_return_error_status_when_macro_value_is_invalid' do
    xhr :post, :preview, :project_id => @project.identifier,
        :macro_type => 'pie-chart',
        :macro_format => 'mql',
        :macro_editor => "{{    pie-chart:\n    data: SELECT invalid_property, count(*) where type='Card'}}",
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response 422
    assert_include '<div class="error macro"', @response.body
  end

  test 'macro_generate_should_generate_chart_when_macro_format_param_is_set_to_mql' do
    xhr :post, :generate, :project_id => @project.identifier,
        :macro_type => 'pie-chart',
        :macro_format => 'mql',
        :macro_editor => "{{\tpie-chart:\n    data: SELECT status, count(*) where type='Card'}}",
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :success
    assert_include 'Your pie chart will display upon saving', @response.body
  end

  test 'macro_generate_should_return_error_status_when_macro_value_is_invalid' do
    xhr :post, :generate, :project_id => @project.identifier,
        :macro_type => 'pie-chart',
        :macro_format => 'mql',
        :macro_editor => "{{\tpie-chart:\n    data: SELECT invalid_property, count(*) where type='Card'}}",
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response 422
    assert_include '<div class="error macro"', @response.body
  end

  test 'macro_generate_should_return_error_when_macro_type_is_not_present_in_macro_editor_params' do
    xhr :post, :generate, :project_id => @project.identifier,
        :macro_type => 'pie-chart',
        :macro_format => 'mql',
        :macro_editor => "{{\tinvalid-chart:\n    data: SELECT invalid_property, count(*) where type='Card'}}",
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :unprocessable_entity

    xhr :post, :generate, :project_id => @project.identifier, :macro_type => 'some'
    assert_response :unprocessable_entity
  end

  test 'macro_preview_should_return_error_when_macro_type_is_not_present_in_macro_editor_params' do
    xhr :post, :preview, :project_id => @project.identifier,
        :macro_type => 'pie-chart',
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :unprocessable_entity

    xhr :post, :preview, :project_id => @project.identifier, :macro_type => 'some'
    assert_response :unprocessable_entity

    xhr :post, :preview, :project_id => @project.identifier,
        :macro_type => 'a-chart',
        :macro_format => 'mql',
        :macro_editor => "{{\tinvalid-chart:\n    data: SELECT invalid_property, count(*) where type='Card'}}",
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :unprocessable_entity
    assert_equal MacroEditorController::INVALID_MACRO_PARAM_ERROR, @response.body
  end

  test 'should_give_error_response_when_yaml_syntax_is_incorrect' do
    xhr :post, :preview, :project_id => @project.identifier,
        :macro_type => 'a-chart',
        :macro_format => 'mql',
        :macro_editor => "{{\tinvalid-yaml\ninvalid-yaml\nsjsjsj}}",
        :content_provider => MacroEditor::ContentProvider.to_params(@project.cards.first)
    assert_response :unprocessable_entity
    assert_equal MacroEditorController::INVALID_MACRO_PARAM_ERROR, @response.body
  end

  test 'chart_edit_params_should_render_supported_as_false_when_easy_charts_macro_editor_enabled_for_is_toggled_off' do
    MingleConfiguration.overridden_to(easy_charts_macro_editor_enabled_for: '') do
      xhr :get, :chart_edit_params, :project_id => @project.identifier,
          :macro => %Q{
          {{
            pie-chart
              data: 'Select Size, count(*) Where Type = "Card" AND Size < 10 AND TAGGED WITH "blah"'
          }}
          }

      assert_response :ok
      assert_equal({'supportedInEasyCharts' => false}, JSON.parse(@response.body))
    end
  end

  test 'chart_edit_params_should_render_supported_as_false_when_project_is_invalid' do
    expected_json_response = {'supportedInEasyCharts' => false,
                              'chartData' =>
                                  {'project' => 'random_project_blah',
                                   'chartSize' => nil,
                                   'labelType' => nil,
                                   'legendPosition' => nil,
                                   'chartTitle' => nil},
                              'contentProvider' => nil,
                              'macroHelpUrls' =>
                                  {'pie-chart' =>
                                       build_help_link('ec_pie_charts.html'),
                                   'ratio-bar-chart' =>
                                       build_help_link('ec_ratiobar_chart.html')},
                              'initialProject' => 'first_project'}

    MingleConfiguration.overridden_to(easy_charts_macro_editor_enabled_for: 'pie-chart') do
      xhr :get, :chart_edit_params, :project_id => @project.identifier,
          :macro => %Q{
          {{
            pie-chart
              data: 'Select Size, count(*) Where Type = "Card" AND Size < 10 AND TAGGED WITH "blah"'
              project: random_project_blah
          }}
          }

      assert_response :ok
      assert_equal(expected_json_response, JSON.parse(@response.body))
    end
  end

  test 'chart_edit_params_should_render_supported_as_true_when_easy_charts_macro_editor_enabled_for_is_toggled_on' do
    expected_edit_chart_params = {
        'supportedInEasyCharts' => true,
        'chartData' => {
            'project' => @project.identifier,
            'chartSize' => nil,
            'chartTitle' => nil,
            'labelType' => nil,
            'legendPosition' => nil,
            'tagsFilter' => ['blah'],
            'property' => 'Status',
            'cardFilters' => [
                {'values' => [%w(Card Card)], 'property' => 'Type', 'operator' => 'is'},
                {'values' => [%w(medium medium), %w(high high)], 'property' => 'Priority', 'operator' => 'is'}
            ],
            'aggregate' => 'count',
            'aggregateProperty' => nil
        },
        'contentProvider' => {'id' => 1, 'type' => 'Card'},
        'macroHelpUrls' => {'pie-chart' => build_help_link('ec_pie_charts.html'),
                            'ratio-bar-chart' => build_help_link('ec_ratiobar_chart.html')},
        'initialProject' => 'first_project'
    }
    MingleConfiguration.overridden_to(easy_charts_macro_editor_enabled_for: 'pie-chart') do
      xhr :get, :chart_edit_params, project_id: @project.identifier,
          content_provider: {id: 1, type: 'Card'}, macro: %Q{
          {{
            pie-chart
              data: 'Select Status, count(*) Where Type = "Card" AND Priority IN ("medium", "high") AND TAGGED WITH "blah"'
          }}
          }

      assert_response :ok
      assert_equal(expected_edit_chart_params, JSON.parse(@response.body))
    end
  end
end
