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
class Rake::TestTask
  attr_accessor :include_tagged_with

  def file_list_with_tag_filtering
    candidates = file_list_without_tag_filtering
    include_tagged_with = self.include_tagged_with || (ENV['TAG'] ? ENV['TAG'].split(',') : nil)
    return candidates unless include_tagged_with

    candidates.select do |file|
      include_tagged_with.any? do |tag|
        file_tagged_with?(file, tag)
      end
    end
  end
  alias_method :file_list_without_tag_filtering, :file_list
  alias_method :file_list, :file_list_with_tag_filtering

  def file_tagged_with?(file, tag)
    File.open(file) do |io|
      io.each_line do |line|
        return true if line =~ /Tags:.*#{tag}/m
      end
    end
    false
  end
end

namespace :test do
  require 'vendor/plugins/tagged_tests/lib/tagged_tests'

  @tagged_test_definer = TaggedTests.define_test_tasks do
    test_task_class SeleniumRcHelper::AcceptanceTestTask
    prefix 'acceptance_'
    include_files FileList['test/acceptance/**/*_test.rb']
    define 'non_transactional_units', 'non-transactional-units'
    define 'multitenancy'
    define 'license'
    define 'cross_project'
    define 'maximized_view'
    define 'userproperty', 'user-property'
    define 'svn'
    define 'api_version_1'
    define 'api_version_2'
    define 'attachment'
    define 'excel_import'
    define 'excel_export'
    define 'excel'
    define 'import_export', 'import-export'
    define 'tree_filters', 'tree-filters'
    define 'navigation'
    define 'ranking'
    define 'gridview'
    define 'card_page_history','card-page-history'
    define 'history'
    define 'tagging'
    define 'search'
    define 'template'
    define 'defaults'
    define 'defaults_2'
    define 'cardtype', 'card-type'
    define 'enumproperty', 'enum-property'
    define 'mingle_admin', 'mingle-admin'
    define 'new_user_role'
    define 'profile'
    define 'group'
    define 'user', 'user'
    define 'bulk'
    define 'project_variable_usage', 'project-variable-usage'
    define 'project_variable', 'project-variable'
    define 'filters'
    define 'tabs'
    define 'cardlist', 'card-list'
    define 'relationship_properties', 'relationship-properties'
    define 'aggregate_properties', 'aggregate-properties'
    define 'tree_configuration', 'tree-configuration'
    define 'transition_crud', 'transition-crud'
    define 'transitions'
    define 'tree_view', 'tree-view'
    define 'tree_usage', 'tree-usage'
    define 'dateproperty', 'date-property'
    define 'freetextproperty', 'freetext-property'
    define 'card_properties', 'card-properties'
    define 'formula'
    define 'wiki'
    define 'wiki_2'
    define 'cards'
    define 'project'
    define 'numeric_properties', 'numeric-properties'
    define 'properties'
    define 'murmurs'
    define 'chart'
    define 'average_query'
    define 'value_query'
    define 'table_query'
    define 'pivot_table'
    define 'macro'
    define 'help'
    define 'quarantine'
    define 'wysiwyg'
    define_rest 'other'
  end

  SeleniumRcHelper::AcceptanceTestTask.new(:acceptance_scm) do |t|
    t.libs << 'test'
    t.test_files = FileList['test/acceptance/scenarios/scm/**/*_test.rb']
    t.verbose = true
  end


  namespace :acceptance do
    task :show_suites do
      test_list = []
      test_set = {}
      @tagged_test_definer.test_tasks.keys.sort.each do |tag|
        task = @tagged_test_definer.test_tasks[tag]
        tests = task.instance_variable_get('@tests')
        puts "\nSuite: #{tag} #{tests.size} tests\n  --------------------\n"
        tests.each do |test|
          test_list << test
          test_set[test] = test
          puts "  #{test.file}"
        end
        puts "  --------------------"
      end

      puts "WARNING: IT LOOKS LIKE TEST SUITES CONTAIN DUPLICATES!!!!" if test_list.size > test_set.size
      puts "\nTotal test count: #{test_list.size}\n\n"
    end
  end

  namespace :tags do
    desc "Show all acceptance tests' scenario tags."
    task :show do
      TaggedTests::TestSet.new(FileList['test/acceptance/**/*_test.rb']).dump_debug
    end
  end
end
