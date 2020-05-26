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

class DupEventChangesTest < ActiveSupport::TestCase
  does_not_work_without_jruby

  class CreateEventInTransaction
    attr_accessor :errors
    def initialize(project, event, counter)
      @project = project
      @event = Event.find_by_id(event.id) #call find_by_id once, so that no jruby error
      @counter = counter
      @errors = []
    end

    def execute
      @project.with_active_project do |project|
        @counter.inc
        @counter.sync_thread_as_count(2)

        Event.lock_and_generate_changes!(@event.id)
      end
      Project.connection.commit_db_transaction
    rescue => e
      puts e
      puts e.backtrace.join("\n")
      @errors << e
    end
  end

  class ThreadSafeCounter
    def initialize
      @count = 0
      @mutex = Monitor.new
      @cond = @mutex.new_cond
    end

    def inc
      @mutex.synchronize { @count += 1 }
    end

    def sync_thread_as_count(number)
      @mutex.synchronize do
        if @count == number
          @cond.signal
        else
          @cond.wait
        end
      end
    end
  end

  def teardown
    ActiveRecord::Base.clear_active_connections!
  end

  # do not run multi-threads test :(
  def xtest_should_only_generate_one_copy_of_changes_for_event_in_multi_threads
    login_as_member
    create_a_project_has_card_version_and_event

    counter = ThreadSafeCounter.new

    job1 = CreateEventInTransaction.new(@project, @event, counter)
    thread1 = Thread.start(job1) do |job1|
      login_as_member
      job1.execute
    end
    
    job2 = CreateEventInTransaction.new(@project, @event, counter)
    thread2 = Thread.start(job2) do |job2|
      login_as_member
      job2.execute
    end

    thread1.join
    thread2.join

    assert_equal [], job1.errors.collect(&:message)
    assert_equal [], job2.errors.collect(&:message)
    @project.activate
    @event = Event.find(@event.id)
    assert_equal ["Description changed"], @event.changes.collect(&:describe)
  end

  # leave this test here, may need some day
  def xtest_generate_changes_in_multi_transactions
    login_as_member
    create_a_project_has_card_version_and_event
    mutex = Monitor.new
    thread1_start_transaction = false
    thread2_start_transaction = false
    thread1_updated_history_generated = false
    thread1 = Thread.start do
      login_as_member
      event = Event.find_by_id(@event.id)
      begin
        @project.with_active_project do |project|
          mutex.synchronize { thread1_start_transaction = true }
          loop do
            break if mutex.synchronize { thread2_start_transaction }
          end
          event.reload(:lock => true)
          puts "thread1 start transaction"
          Event.transaction do
            puts "thread1 update history_generated"
            @event.update_attribute(:history_generated, true)
            mutex.synchronize do
              thread1_updated_history_generated = true
            end
            puts "thread1 do_generate_changes"
            @event.do_generate_changes
            puts "thread1 do_generate_changes done"
          end
          puts "thread1 committed"
        end
        Project.connection.commit_db_transaction
      rescue => e
        puts e
        puts e.backtrace.join("\n")
      end
    end

    thread2 = Thread.start do
      login_as_member
      event = Event.find_by_id(@event.id)
      begin
        @project.with_active_project do |project|
          mutex.synchronize { thread2_start_transaction = true }
          loop do
            break if mutex.synchronize { thread1_start_transaction }
          end
          
          loop do
            break if mutex.synchronize { thread1_updated_history_generated }
          end
          event.reload(:lock => true)
          puts "thread2 start transaction"
          Event.transaction do
            puts "thread2 update history_generated"
            @event.update_attribute(:history_generated, true)
            puts "thread2 do_generate_changes"
            @event.do_generate_changes
            puts "thread2 do_generate_changes done"
          end
          puts "thread2 committed"
        end
        Project.connection.commit_db_transaction
      rescue => e
        puts e
        puts e.backtrace.join("\n")
      end
    end

    thread1.join
    thread2.join

    @project.activate
    @event = Event.find(@event.id)
    assert_equal ["Description changed"], @event.changes.collect(&:describe)
  end

  def create_a_project_has_card_version_and_event
    @project = with_new_project do |project|
      card = create_card!(:name => 'story')
      card.description = "new story"
      card.save!
      version = card.versions.last
      @event = version.event
      project
    end
    Project.connection.commit_db_transaction
  end

end
