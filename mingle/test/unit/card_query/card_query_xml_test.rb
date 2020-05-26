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

class CardQueryXmlTest < ActiveSupport::TestCase
  
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end

  def test_version_one_results_should_be_within_hash
    xml = xml_results_of_executing "SELECT Count(*) WHERE type=Card", :api_version => 'v1', :expected_result_count => 1
    assert_equal "1", xml.element_text_at("/hash/results/result/Count-")
  end

  def test_should_execute_count_query_and_return_result_as_xml
    xml = xml_results_of_executing "SELECT Count(*) WHERE type=Card"
    assert_equal "1", xml.element_text_at("/results/result/count")
  end

  def test_should_execute_select
    @project.cards.create!(:name => 'timmy', :number => 324, :card_type_name => 'Card')
    xml = xml_results_of_executing "SELECT name, number WHERE type=Card ORDER BY number DESC", :expected_result_count => 2
    assert_equal "timmy", xml.element_text_at("/results/result[1]/name")
    assert_equal "324", xml.element_text_at("/results/result[1]/number")
    assert_equal "for card query test", xml.element_text_at("/results/result[2]/name")
    assert_equal "1", xml.element_text_at("/results/result[2]/number")
  end

  def test_should_replace_spaces_in_tags_with_underscores_in_property_names
    @project.cards.first.update_attribute(:cp_analysis_done_in_iteration, 12)
    xml = xml_results_of_executing "SELECT 'analysis done in iteration' WHERE type=Card"
    assert_equal "12", xml.element_text_at("/results/result/analysis_done_in_iteration")
  end

  def test_should_replace_spaces_in_aggregate_tags
    @project.cards.first.update_attribute(:cp_size, 1)
    xml = xml_results_of_executing "SELECT sum(size) WHERE type=Card"
    assert_equal "1.00", @project.format_num(xml.element_text_at("/results/result/sum_size"))
  end

  def test_should_only_return_selected_columns_when_using_order_by
    @project.cards.first.update_attribute(:cp_status, "new")      
    xml = xml_results_of_executing "SELECT status WHERE type=Card ORDER BY status"
    assert_result_count 1, xml
  end

  def test_should_only_return_selected_columns_when_using_distinct
    @project.cards.first.update_attribute(:cp_status, "new")
    xml = xml_results_of_executing "SELECT DISTINCT status WHERE type=Card"
    assert_result_count 1, xml
  end

  def test_should_support_min
    @project.cards.first.update_attribute(:cp_size, 1)
    xml = xml_results_of_executing "SELECT min(size) WHERE type=Card"
    assert_equal "1.00", @project.format_num(xml.element_text_at("/results/result/min_size"))
  end

  def test_should_support_max
    @project.cards.first.update_attribute(:cp_size, 1)
    xml = xml_results_of_executing "SELECT max(size) WHERE type=Card" 
    assert_equal "1.00", @project.format_num(xml.element_text_at("/results/result/max_size"))
  end

  def test_should_support_avg
    @project.cards.first.update_attribute(:cp_size, 1)
    xml = xml_results_of_executing "SELECT avg(size) WHERE type=Card"
    assert_equal "1.00", @project.format_num(xml.element_text_at("/results/result/avg_size"))
  end

  def test_should_support_formula_in_v1
    @project.cards.first.update_attribute(:cp_size, 10)
    xml = xml_results_of_executing "SELECT half WHERE type=Card", :expected_result_count => 1, :api_version => 'v1'
    assert_equal "5", xml.element_text_at("/hash/results/result/half")
  end

  def test_should_support_cleaned_up_formulae_in_v2
    @project.cards.first.update_attribute(:cp_size, 10)
    xml = xml_results_of_executing("SELECT half WHERE type=Card")
    assert_equal "5", xml.element_text_at("/results/result/half")
  end

  def test_should_support_unmanged_numeric_in_v1
    @project.cards.first.update_attribute(:cp_numeric_free_text, "10")
    xml = xml_results_of_executing "SELECT \"numeric_free_text\" WHERE type=Card", :expected_result_count => 1, :api_version => 'v1'
    assert_equal "10", xml.element_text_at("/hash/results/result/numeric_free_text")
    assert_equal "10.00", @project.format_num(xml.element_text_at("/hash/results/result/numeric_free_text"))
  end

  def test_should_support_cleaned_up_unmanged_numeric_properties_in_v2
    @project.cards.first.update_attribute(:cp_numeric_free_text, "10")
    xml = xml_results_of_executing "SELECT \"numeric_free_text\" WHERE type=Card"
    assert_equal "10", xml.element_text_at("/results/result/numeric_free_text")
  end

  def test_should_annotate_results_as_an_array
    @project.cards.first.update_attribute(:cp_numeric_free_text, "10")
    xml = xml_results_of_executing "SELECT COUNT(*) WHERE type=Card"
    assert_equal "array", xml.attribute_value_at("/results/@type")
  end

  private
  def xml_results_of_executing(mql, options = {:expected_result_count => 1, :api_version => 'v2'})
    result = REXML::Document.new(CardQuery.parse(mql).values_as_xml(options))
    assert_equal options[:expected_result_count], REXML::XPath.first(result, "count(//result)")
    result
  end

  def assert_result_count(expected_count, xml)
    assert_equal expected_count, REXML::XPath.first(xml, "count(//result)")
  end
end
