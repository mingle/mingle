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

class Symbol
  def to_proc
    Proc.new { |*args| args.shift.__send__(self, *args) }
  end
end

module TaggedTests
  class TestSet
    def initialize(files = [])
      @tests = []
      add_files(files)
      yield(self) if block_given?
    end
    
    def add_files(files)
      add_all(files.to_a.collect{|f| Test.new(f)})
    end
    
    def <<(test)
      @tests << test
    end
    
    def add_all(tests)
      @tests.concat(tests)
    end
    
    def size
      to_a.size
    end
    
    def to_a
      @tests
    end
    
    def query(query, only_include_files = [])
      TestSet.new do |result|
        @tests.each do |t|
          result << t if t.satisfies?(query, only_include_files)
        end
      end
    end
    
    def delete_all(tests)
      tests.to_a.each{|t| @tests.delete(t)}
    end
    
    def tags
      @tests.collect(&:tags).flatten.uniq.sort
    end
    
    def dump_debug
      tags.each do |tag|
        tests_with_tag = query(tag)
        size = tests_with_tag.size
        puts "#{tag} #{size}"
        if size <= 2
          puts "(#{tests_with_tag.to_a.collect(&:file).join(', ')})"
        end
      end
      without_tags = @tests.select{|t| t.tags.empty?}
      puts "Tests without tags (#{without_tags.size}): #{without_tags.collect(&:file).join(', ')}" unless without_tags.empty?
    end
  end
  
  class Test
    attr_accessor :tags
    attr_accessor :file
    
    def initialize(file)
      self.file = file
      if file
        File.open(file) do |io|
          io.each_line do |line|
            if line =~ /Tags\: (.*)/
              self.tags = $1.split(',').collect{|t| t.strip}.uniq.delete_if{|t| t =~ /^#/ }
              self.tags.delete(nil)
              break
            end
          end
        end
      end
      self.tags ||= []
    end
    
    def satisfies?(query, only_include_files = [])
      tags.include?(query) && (only_include_files == [] || only_include_files.include?(file))
    end
  end
  
  class TestTaskDefiner
    attr_reader :test_tasks
    
    def initialize(&proc)
      @tests = TestSet.new
      @test_task_class = Rake::TestTask
      @test_tasks = {}
      self.instance_eval(&proc)
    end
    
    def prefix(prefix)
      @prefix = prefix
    end
    
    def test_task_class(task)
      @test_task_class = task
    end
    
    def include_tests(tests)
      @tests.add_all(tests)
    end
    
    def include_files(files)
      @tests.add_files(files)
    end
    
    # Defines a test task including tests with the specified tags (defaults
    # to the name of the test task itself). Removes the tests from the test
    # set so tests defined later on don't run the same tests.
    def define(name, query=name, only_include_files=[])
      require 'rake/testtask'
      new_test_task(name) do |t|
        t.libs << "test"
        my_tests = @tests.query(query, only_include_files)
        @tests.delete_all(my_tests)
        @test_tasks[name] = my_tests
        puts "#{name} #{my_tests.size}" if defined?(@verbose) && @verbose
        t.test_files = my_tests.to_a.collect(&:file)
        t.verbose = true
      end
    end
    
    def define_rest(name, only_include_files = [])
      require 'rake/testtask'
      new_test_task(name) do |t|
        t.libs << "test"
        @test_tasks[name] = @tests
        puts "#{name} #{@tests.size} (#{@tests.tags.join(',')})" if defined?(@verbose) && @verbose
        test_files = @tests.to_a.collect(&:file)
        t.test_files = only_include_files == [] ? test_files : test_files.select { |f| only_include_files.include?(f) }
        t.verbose = true
      end
    end
    
    def verbose_on
      @verbose = true
    end
    
    private 
    def new_test_task(name, &block)
      @test_task_class.new("#{@prefix}#{name}") { |t| yield(t)  }
    end
  end
  
  def define_test_tasks(&proc)
    TestTaskDefiner.new(&proc)
  end
  module_function :define_test_tasks
end
