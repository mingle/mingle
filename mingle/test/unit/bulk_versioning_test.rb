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

#Tags: bulk_update
class BulkVersioningTest < ActiveSupport::TestCase
  include SqlHelper

  def setup
    @project = card_selection_project
    @project.activate
    @first_card = @project.cards.find_by_number(1)
    @card_versioning = Bulk::BulkUpdateTool.new(@project).card_versioning
    login_as_member
  end

  def test_creating_versions
    connection.execute("update #{Card.quoted_table_name} set cp_iteration = 2 where id = #{@first_card.id}")
    connection.execute("update #{Card.quoted_table_name} set version = #{@first_card.version + 1} where id = #{@first_card.id}")
    @card_versioning.create_card_versions("?.id = #{@first_card.id}", {"cp_iteration" => 2})

    @first_card.reload

    assert_equal @first_card.reload.versions.size, @first_card.version
    assert_equal "2", @first_card.versions.last.cp_iteration
  end

  def test_should_create_event_after_create_version
    connection.execute("update #{Card.quoted_table_name} set cp_iteration = 2 where id = #{@first_card.id}")
    @card_versioning.create_card_versions("?.id = #{@first_card.id}", {"cp_iteration" => 2})
    assert_event_created_from_version @first_card.reload.versions.last
  end

  def test_creating_versions_for_tag
    foo = @project.tags.create!(:name => 'foo')

    insert_columns = ['tag_id', 'taggable_id', 'taggable_type']
    select_columns = [foo.id, @first_card.id, "'Card'"]

    if @project.connection.prefetch_primary_key?(Tagging)
      select_columns.unshift(@project.connection.next_id_sql(Tagging.table_name))
      insert_columns.unshift('id')
    end

    connection.execute("insert into #{Tagging.quoted_table_name} (#{insert_columns.join(', ')}) values (#{select_columns.join(', ')}) ")
    connection.execute("update #{Card.quoted_table_name} set version = #{@first_card.version + 1} where id = #{@first_card.id}")
    assert !@first_card.reload.tags.empty?

    TemporaryIdStorage.with_session do |session_id|
      connection.execute("insert into #{TemporaryIdStorage.quoted_table_name} (session_id, id_1) VALUES ('#{session_id}', #{@first_card.id})")
      @card_versioning.create_card_versions_for_tag(session_id)
    end

    @first_card.reload
    assert_equal  @first_card.versions.size, @first_card.version
    taggings = Tagging.find_by_tag_id(foo.id)
    assert_equal [foo], @first_card.versions.last.tags
  end

  def test_should_create_event_when_creating_version_for_tag
    original_version = @first_card.versions.last.version
    foo = @project.tags.create!(:name => 'foo')

    insert_columns = ['tag_id', 'taggable_id', 'taggable_type']
    select_columns = [foo.id, @first_card.id, "'Card'"]

    if @project.connection.prefetch_primary_key?(Tagging)
      select_columns.unshift(@project.connection.next_id_sql(Tagging.table_name))
      insert_columns.unshift('id')
    end

    connection.execute("insert into #{Tagging.quoted_table_name} (#{insert_columns.join(', ')}) values (#{select_columns.join(', ')}) ")
    connection.execute("update #{Card.quoted_table_name} set version = #{@first_card.version + 1} where id = #{@first_card.id}")
    TemporaryIdStorage.with_session do |session_id|
      connection.execute("insert into #{TemporaryIdStorage.quoted_table_name} (session_id, id_1) VALUES ('#{session_id}', #{@first_card.id})")
      @card_versioning.create_card_versions_for_tag(session_id)
    end

    assert_equal original_version + 1, @first_card.reload.versions.last.version
    assert_event_created_from_version @first_card.reload.versions.last
  end

  def assert_event_created_from_version(version)
    event = version.event
    assert_not_nil event
    assert_equal version.created_by_user_id, event.created_by_user_id
    assert_equal version.project, event.project
    assert_equal version.updated_at, event.created_at
    assert_not_nil event.mingle_timestamp
  end

end
