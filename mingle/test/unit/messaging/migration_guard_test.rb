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

class MigrationGuardTest < ActiveSupport::TestCase
  include Messaging

  class Message
    def to_sending_message
      self
    end
  end

  def setup
    @messages = [Message.new]
    @messages_processed = []
  end

  def test_guards_project_import_processor_when_db_not_migrated
    guard = MigrationGuard.new(self, OpenStruct.new(:need_migration? => true))
    guard.receive_message(ProjectImportProcessor::QUEUE) do |msg|
      @messages_processed << msg
    end

    assert_equal [], @messages_processed
    assert_equal @messages, @sending_messages
  end

  def test_guards_program_import_processor_when_db_not_migrated
    guard = MigrationGuard.new(self, OpenStruct.new(:need_migration? => true))
    guard.receive_message(ProgramImportProcessor::QUEUE) do |msg|
      @messages_processed << msg
    end

    assert_equal [], @messages_processed
    assert_equal @messages, @sending_messages
  end

  def test_continues_project_import_processor_when_db_migrated
    guard = MigrationGuard.new(self, OpenStruct.new(:need_migration? => false))
    guard.receive_message(ProjectImportProcessor::QUEUE) do |msg|
      @messages_processed << msg
    end

    assert_equal @messages, @messages_processed
    assert_nil @sending_messages
  end

  def test_allows_other_processors_when_db_not_migrated
    guard = MigrationGuard.new(self, OpenStruct.new(:need_migration? => true))
    guard.receive_message(CardImportProcessor::QUEUE) do |msg|
      @messages_processed << msg
    end

    assert_equal @messages, @messages_processed
    assert_nil @sending_messages
  end

  def send_message(queue, messages, opts={})
    @sending_messages = messages
  end

  def receive_message(queue, options={}, &block)
    @messages.each(&block)
  end
end
