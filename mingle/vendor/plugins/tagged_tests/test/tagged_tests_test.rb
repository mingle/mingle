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

require 'test/unit'
require 'tagged_tests'

# Tags: tag1, tag2, tag3
class TaggedTestsTest < Test::Unit::TestCase
  def test_can_parse_tags
    assert_equal ['tag1', 'tag2', 'tag3'], TaggedTests::Test.new(__FILE__).tags
  end
  
  def test_can_retrieve_all_tests_from_file_list
    tests = TaggedTests::TestSet.new(FileList[File.dirname(__FILE__) + '/**/*_test.rb'])
    
    assert_equal [File.expand_path(__FILE__)], tests.to_a.collect{|t| File.expand_path(t.file)}
    assert_equal [['tag1', 'tag2', 'tag3']], tests.to_a.collect(&:tags)
  end
  
  def test_can_create_subset_based_on_query
    tests = TaggedTests::TestSet.new
    tests << tagged_test('A', 'shared tagA')
    tests << tagged_test('B', 'shared tagB')
    assert_equal ['A'], tests.query('tagA').to_a.collect(&:file)
    assert_equal ['B'], tests.query('tagB').to_a.collect(&:file)
    assert_equal ['A', 'B'], tests.query('shared').to_a.collect(&:file)
  end
  
  def test_can_define_consecutive_test_tasks
    tests = [
      tagged_test('cards'), 
      tagged_test('cards2', 'cards, dummy'), 
      tagged_test('wiki'), 
      tagged_test('other')
    ]
    definer = TaggedTests.define_test_tasks do
      prefix 'func_test_'
      include_tests tests
      define 'cards'
      define 'wiki'
      define_rest 'other'
    end
    assert_not_nil Rake::Task['func_test_cards']
    assert_equal ['cards', 'cards2'], definer.test_tasks['cards'].to_a.collect(&:file)
    assert_equal ['wiki'], definer.test_tasks['wiki'].to_a.collect(&:file)
    assert_equal ['other'], definer.test_tasks['other'].to_a.collect(&:file)
  end
  
  private
  
  def tagged_test(name, tags = name)
    test = TaggedTests::Test.new(nil)
    test.file = name
    test.tags = tags
    test
  end
end

require 'rubygems'
require 'rake'
