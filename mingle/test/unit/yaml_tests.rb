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

require 'test/unit'
require 'yaml'

if RUBY_PLATFORM =~ /java/
  # we've been having a lot of trouble with YAML in both JRuby and MRI
  class TestYamlRoundTrips < ActiveSupport::TestCase
  
    def test_leading_space
      assert_round_trip <<-YAML
   ActiveRecord::StatementInvalid in ProjectsController#confirm_delete
  RuntimeError: ERROR	C23503	Mupdate or delete on "projects" violates foreign 
  YAML
    end 
  
    def test_leading_space_with_blank_lines
      assert_round_trip <<-YAML

   A version number on a card subscription email on 'View this version' is not correct.

  !version.jpg!
  YAML
    end   
  
    def test_xoom_payment_processing_project_problem_when_round_tripping_randomly_indented_wiki_content
      assert_round_trip <<-YAML

                 {% dashboard-panel %}

      h3. Overall Card Types
  
  YAML
    end
  
    def test_nesting
      innermost = {'kind' => 'human'}
      middle = {:first => 'something', :second_params => innermost}
      outer = {:exciting_and_interesting_key => middle.to_yaml}
      assert_equal middle, YAML.load(YAML.load(outer.to_yaml)[:exciting_and_interesting_key])
    end
  
    # this one should be breaking ... see ImportExportTest.
    def test_more_nesting
      innermost = {'status' => 'open'}
      middle = {:style => 'list', :columns => 'status,iteration', :filter_properties => innermost}
      outer = {:x => middle.to_yaml}
      assert_equal middle, YAML.load(YAML.load(outer.to_yaml)[:x])
    end
  
    def test_stack_bar_chart_macro
      text = <<-YAML
  stack-bar-chart
    conditions: 'Release' in (R1) and not 'Iteration Scheduled' = null
    labels: SELECT DISTINCT 'Iteration Scheduled' ORDER BY 'Iteration Scheduled'
    cumulative: true
    series:
    - label: New
      color: green
      data: SELECT 'Iteration Scheduled', COUNT(*) WHERE Status = 'New'
      combine: overlay-bottom
    - label: Open
      color: pink
      data: SELECT 'Iteration Scheduled', COUNT(*) WHERE Status = 'Open'
      combine: overlay-bottom
    - label: Ready for Development
      color: yellow
      data: SELECT 'Iteration Scheduled', COUNT(*) WHERE Status = 'Ready for Development'
      combine: overlay-bottom
    - label: Complete
      color: blue
      data: SELECT 'Iteration Scheduled', COUNT(*) WHERE Status = 'Complete'
      combine: overlay-bottom
    - label: Other statuses
      color: red
      data: SELECT 'Iteration Scheduled', COUNT(*)
      combine: total
  YAML
    
      assert_equal text, YAML.load(YAML.dump(text))
    end
  
    #JIRA-1270 @ http://jira.codehaus.org/browse/JRUBY-1270
    def test_stack_bar_chart_macro_redux
      text = <<-YAML
  outer
    property1: value1
    additional:
    - property2: value2
      color: green
      data: SELECT 'xxxxxxxxxxxxxxxxxxx', COUNT(*) WHERE xyzabc = 'unk'
      combine: overlay-bottom
  YAML

      assert_equal text, YAML.load(YAML.dump(text))
    end
  
  
    def test_pivot_table_macro
      assert_round_trip <<-YAML
  pivot-table
    conditions: not Status = New and not 'Functional area' = '(not set)'
    columns: Status
    rows: Functional area 
    aggregation: count (*)
    totals: true
    empty-columns: true
    empty-rows: false      
  YAML
    end
  
    def test_pie_chart
      assert_round_trip <<-YAML
  pie-chart
    data: SELECT 'Priority', count(*)      
  YAML
    end
    
    def test_leading_dashes_in_content
      assert_round_trip File.read(File.join(Rails.root, 'test/data/yaml_test_1.yml'))
    end

    def assert_round_trip(text)
      assert_equal text, YAML.load(YAML.dump(text))
    end
  
  end
end

