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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

class ImportExportMurmursTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def test_should_not_fail_import_when_murmurs_were_pointing_at_some_deleted_cards
    @user = login_as_member
    export_file = create_export_file do |project|
      card_to_delete = create_card! :name => 'uno'
      card_to_delete.add_comment :content => 'murmur uno'
      card_to_delete.reload.destroy
    end
    imported_project = create_project_importer!(@user, export_file).process!.reload
    assert_equal 1, imported_project.murmurs.count
    murmur = imported_project.murmurs.first
    assert_nil murmur.origin_type
    assert_nil murmur.origin_id
  end

  def test_should_import_and_export_conversations
    @user = login_as_member
    export_file = create_export_file do |project|
      conversation = project.conversations.create!
      conversation.murmurs << create_murmur(:murmur => 'murmur uno', :project => project)
      conversation.murmurs << create_murmur(:murmur => 'murmur due', :project => project)
    end
    imported_project = create_project_importer!(@user, export_file).process!.reload
    assert_equal 1, imported_project.conversations.count
    assert_equal 2, imported_project.murmurs.count
    assert_equal ['murmur uno', 'murmur due'], imported_project.conversations.first.murmurs.map(&:murmur)
  end
end
