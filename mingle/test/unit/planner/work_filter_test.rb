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

class WorkFilterTest < ActiveSupport::TestCase

  def test_group_filters_by_attribute
    array = [new_filter('a', '1'), new_filter('b', '2')]
    result = Work::Filter.group_by(:attribute, array)
    expected = {'a' => [new_filter('a', '1')], 'b' => [new_filter('b', '2')]}
    assert_equal expected, result
  end

  def test_to_filter_hash
    expected = { :property => 'attribute', :operator => 'op', :value => 'value', :valueValue => ['value', 'value']}
    assert_equal(expected, new_filter('attribute', 'op', 'value').to_filter_hash)
  end

  def test_decode
    assert_equal [], Work::Filter.decode(nil)
    assert_equal [], Work::Filter.decode([])
    assert_equal [new_filter('status', 'is', 'new')], Work::Filter.decode(['[status][is][new]'])
    assert_equal [new_filter('status', 'is', 'new')], Work::Filter.decode(['[status][is][new]', 'something is wrong'])
  end

  def test_filter_attributes
    plan = program('simple_program').plan
    expected = [
      {
        'name' => 'Project',
        'tooltip' => 'Project',
        'operators' => [['is', 'is'], ['is not', 'is not']],
        'nameValuePairs' => plan.program.projects.smart_sort_by(&:name).collect{|project| [project.name, project.name]},
        'appendedActions' => [],
        'options' => {}
      },
      {
        'name' => 'Status',
        'tooltip' => 'Status',
        'operators' => [['is', 'is'], ['is not', 'is not']],
        'nameValuePairs' => [['Done', 'done'], ['Not Done', 'not done'], ['("Done" status not defined for project)', 'not mapped']],
        'appendedActions' => [],
        'options' => {}
      }
    ]
    assert_equal expected, Work::Filter.filter_attributes(plan)
  end

  def test_convert_filter_attribute_value
    assert_equal true,            new_filter('status', 'is', 'done').db_identifier
    assert_equal false,           new_filter('status', 'is', 'not done').db_identifier
    assert_equal nil,             new_filter('status', 'is', 'not mapped').db_identifier
    assert_equal nil,             new_filter('status', 'is', 'something wrong').db_identifier
    assert_equal 'project name',  new_filter('project', 'is', 'project name').db_identifier
    assert_equal 'objective name',   new_filter('objective', 'is', 'objective name').db_identifier
  end

  def test_encode_filters
    assert_equal ['[objective][is][objective a]'], Work::Filter.encode(:objective => Objective.new(:name => 'objective a'))
    assert_equal ['[status][is][done]'], Work::Filter.encode(:status => 'done')
    assert_equal ['[status][is][done]', '[objective][is][objective a]'].sort, Work::Filter.encode(:status => 'done', :objective => Objective.new(:name => 'objective a')).sort 
  end

  def test_encode_filters_have_is_not_operator
    assert_equal ['[status][is not][done]'], Work::Filter.encode(:status => ['is not', 'done'])
  end

  def new_filter(attribute, op, value=nil)
    Work::Filter.new(attribute, op, value)
  end
end
