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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
ElasticSearch.disable

module ProjectImportExportTestHelper
  include Zipper, TreeFixtures::PlanningTree, SqlHelper

  def teardown
    Clock.reset_fake
    FileUtils.rm_f(@export_file) if @export_file

    # we are in a transaction, commit it and start a new one
    Project.connection.commit_db_transaction
    Project.connection.begin_db_transaction
  end

  def setup_round_trip_test_project
    unique_name = unique_project_name
    project = Project.create!(:name => unique_name, :identifier => unique_name, :icon => sample_attachment("1.png"))
    setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]

    tag = project.tags.create!(:name => 'Exported Tag')
    card = create_card!(:name => 'Exported Card').tag_with(['Exported Tag', 'Another Tag'])
    card.attach_files(sample_attachment)
    card.save!

    page = project.pages.create!(:name => 'Exported Page')
    page.attach_files(sample_attachment)
    page.save!

    assert_equal 1, card.attachments.size
    member = User.find_by_login("member")
    project.add_member(member)
    [project, card, tag]
  end


  def pretend_smtp_configuration_is_not_loaded
    SmtpConfiguration.class_eval do
      def self.load_with_always_disabled(file_name=SMTP_CONFIG_YML)
        return false
      end

      class << self
        alias_method_chain :load, :always_disabled
      end
    end
  end

  def reenable_smtp_configuration_load_method
    SmtpConfiguration.class_eval do
      class << self
        alias_method "load", "load_without_always_disabled"
      end
    end
  end

  def export_and_reimport(project, import_options={})
    @export_file = create_project_exporter!(project, @user, :template => !!import_options[:template]).export
    @project_importer = create_project_importer!(User.current, @export_file)
    @project_importer.process!(import_options)
  end

  def destroy_user(login)
    if user=User.find_by_login(login)
      user.destroy_without_callbacks
    end
  end

  def change_user_id(new_id, old_id)
    ActiveRecord::Base.connection.execute(SqlHelper.sanitize_sql("UPDATE users SET id = ? WHERE id = ?", new_id, old_id))
  end
end
