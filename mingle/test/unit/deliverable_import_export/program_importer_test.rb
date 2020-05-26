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
require File.expand_path(File.dirname(__FILE__) + '/../../messaging/messaging_test_helper')

class ProgramImporterTest < ActiveSupport::TestCase

  include MessagingTestHelper

  def setup
    @user = login_as_admin
    @project = create_project
    @project.with_active_project do |project|
      @card = project.cards.create!(:name => "baby's first card", :card_type => project.card_types.first)
    end
    @program = create_program
    @program.assign(@project)
  end

  def test_should_import_program
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    assert Program.find_by_name(@program.name)
  end

  def test_should_invalidate_cache_after_program_import
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    imported_program = Program.find_by_name(@program.name)
    assert imported_program
    cache_key = CacheKey.find_by_deliverable_id(imported_program.id)
    assert_not_nil cache_key.feed_key
  end

  def test_should_import_backlog_objectives
    backlog_objective = @program.objectives.backlog.create(:name => 'objective')
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    imported_program = Program.find_by_name(@program.name)
    assert_equal backlog_objective.name, imported_program.objectives.backlog.first.name
    assert_equal backlog_objective.position, imported_program.objectives.backlog.first.position
  end

  def test_should_remove_the_newly_created_default_objective_type_for_program_and_import_objective_types
    objective_type = @program.objective_types.create(:name => 'objective_type', :value_statement => 'statement')

    assert_equal(2, @program.objective_types.size)

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    imported_program = Program.find_by_name(@program.name)
    assert_equal 2, imported_program.objective_types.size
    assert_equal objective_type.value_statement , imported_program.objective_types.find_by_name('objective_type').value_statement
  end

  def test_should_create_plan_with_unique_identifier_instead_of_the_identifier_in_the_file
    export_file = create_program_exporter!(@program, @user).process!
    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    assert Program.find_by_identifier("#{@program.identifier}1")
  end

  def test_should_not_destroy_program_with_identifier_from_file_upon_upgrade_failure
    export_file = create_program_exporter!(@program, @user).process!
    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    importer = DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message)
    def importer.upgrade_if_needed
      raise "[forced failure for test] Catastrophe!"
    end
    assert_nil importer.process!
    assert_equal "completed failed", asynch_request.progress.status
    assert Program.find_by_identifier("#{@program.identifier}")
    assert_nil Program.find_by_identifier("#{@program.identifier}1")
  end

  def test_should_not_destroy_program_with_identifier_from_file_upon_misc_import_failure
    export_file = create_program_exporter!(@program, @user).process!
    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    importer = DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message)
    def importer.grant_program_access_to_members
      raise "[forced failure for test] unable to grant_program_access_to_members"
    end
    assert_nil importer.process!
    assert_equal "completed failed", asynch_request.progress.status
    assert Program.find_by_identifier("#{@program.identifier}")
    assert_nil Program.find_by_identifier("#{@program.identifier}1")
  end


  def test_should_import_plan_dates
    @program.plan.update_attributes :start_at => Clock.today - 10, :end_at => Clock.today + 10
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    imported_program = Program.find_by_identifier(@program.identifier)
    assert_equal @program.plan.start_at, imported_program.plan.start_at
    assert_equal @program.plan.end_at, imported_program.plan.end_at
  end

  def test_should_import_objectives
    objective = @program.objectives.planned.create!(:name => 'objective name', :start_at => Date.today, :end_at => (Date.today + 1), :vertical_position => 2)
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal 1, imported_program.objectives.planned.size
    imported_objective = imported_program.objectives.planned.first
    assert_equal objective.name, imported_objective.name
    assert_equal objective.start_at, imported_objective.start_at
    assert_equal objective.end_at, imported_objective.end_at
    assert_equal objective.vertical_position, imported_objective.vertical_position
    assert_equal objective.identifier, imported_objective.identifier
  end

  def test_should_import_objective_filters
    objective = @program.objectives.planned.create!(:name => 'objective name', :start_at => Date.today, :end_at => (Date.today + 1), :vertical_position => 2)
    @project.with_active_project { |project| setup_property_definitions('status' => ['old', 'new']) }
    filter = objective.filters.create!(:project => @project, :params => {:filters => ["[status][is][new]"]})
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy

    new_project = Project.create!(:identifier => @project.identifier, :name => @project.name)

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    imported_filter = imported_program.objectives.planned.find_by_name(objective.name).filters.first
    assert_equal ["[status][is][new]"], imported_filter.params[:filters]
    assert_equal new_project, imported_filter.project
  end

  def test_should_trigger_objective_filter_sync
    auto_sync_objective = @program.objectives.planned.create!(:name => 'autosync objective name', :start_at => Date.today, :end_at => (Date.today + 1), :vertical_position => 2)
    manual_objective = @program.objectives.planned.create!(:name => 'manual objective name', :start_at => Date.today, :end_at => (Date.today + 1), :vertical_position => 3)
    @project.with_active_project { |project| setup_property_definitions('status' => ['old', 'new']) }
    assign_project_cards(auto_sync_objective, @project)
    filter = auto_sync_objective.filters.create!(:project => @project, :params => {:filters => ["[status][is][new]"]})
    export_file = create_program_exporter!(@program, @user).process!

    @program.destroy

    clear_message_queue(SyncObjectiveWorkProcessor::QUEUE)

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)

    msgs = all_messages_from_queue(SyncObjectiveWorkProcessor::QUEUE)
    assert_equal 1, msgs.size
  end

  def test_should_import_program_projects
    second_project = create_project
    @program.assign(second_project)
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal 2, imported_program.projects.size
    assert_equal [@project.id, second_project.id].sort, imported_program.projects.collect(&:id).sort
  end

  def test_should_import_plan_objectives_work
    objective = @program.objectives.planned.create!(:name => 'objective name', :start_at => Date.today, :end_at => (Date.today + 1), :vertical_position => 2)
    @program.plan.assign_cards(@program.projects.first, @card.number, objective)
    work = objective.works.first

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal 1, imported_program.objectives.planned.size
    assert_equal 1, imported_program.objectives.planned.first.works.size

    imported_work = imported_program.objectives.planned.first.works.first
    assert_equal work.card_number, imported_work.card_number
    assert_equal work.completed, imported_work.completed
    assert_equal work.name, imported_work.name
  end

  def test_should_import_program_memberships
    member = User.find_by_login('member')
    @program.add_member member
    @program.save

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal 2, imported_program.users.size
  end

  def test_should_import_program_memberships_and_map_by_user_login
    zulu = create_user!(:login => "zulu", :name => "first zulu")
    @program.add_member zulu
    @program.save

    export_file = create_program_exporter!(@program, @user).process!
    privilege_level = zulu.privilege_level(@program)
    @program.destroy
    zulu.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }

    new_zulu = create_user!(:login => "zulu", :name => "next zulu")
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    imported_user = imported_program.users.find_by_login('zulu')
    assert_equal "zulu", imported_user.login
    assert_equal "next zulu", imported_user.name
    assert_equal privilege_level, imported_user.privilege_level(imported_program)
  end

  def test_should_assign_default_role_for_new_users
    zulu = create_user!(:login => "zulu", :name => "first zulu")
    @program.add_member zulu
    @program.save

    export_file = create_program_exporter!(@program, @user).process!
    privilege_level = zulu.privilege_level(@program)

    @program.destroy
    zulu.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    imported_user = imported_program.users.find_by_login('zulu')
    assert_equal privilege_level, imported_user.privilege_level(imported_program)
  end

  def test_should_create_missing_users_who_are_members_of_exported_plan
    icon = sample_attachment('user_icon.png')
    fighter = create_user!(:login => "fighter", :name => "vinay", :icon => icon)
    @program.add_member fighter
    @program.save

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    fighter.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }

    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    imported_user = imported_program.users.find_by_login("fighter")
    assert_equal "fighter", imported_user.login
    assert_equal "vinay", imported_user.name
    assert File.exists? File.join(Rails.root, 'public', imported_user.icon_path[1..-1])
  end

  def test_should_import_program_projects_when_project_with_same_identifer_exists
    status_property_definition = nil
    @project.with_active_project do |project|
      setup_property_definitions('status' => ['new', 'closed'])
      status_property_definition = project.find_property_definition('status')
    end
    @program.program_projects.first.update_attributes(:status_property => status_property_definition, :done_status => status_property_definition.find_enumeration_value('closed'))
    export_file = create_program_exporter!(@program, @user).process!

    @program.destroy
    @project.destroy

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)
    new_status_property_definition = nil
    new_project.with_active_project do |project|
      setup_property_definitions({'status' => ['new', 'closed']}, {:hidden => true})
      new_status_property_definition = project.find_property_definition('status', {:with_hidden => true})
    end
    new_done_value = new_status_property_definition.find_enumeration_value('closed')

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal 1, imported_program.projects.size
    assert_equal new_project, imported_program.projects.first
    assert_equal new_status_property_definition, imported_program.program_projects.first.status_property
    assert_equal new_done_value, imported_program.program_projects.first.done_status
  end

  def test_should_import_program_projects_correctly_even_when_missing_done_status_mapping
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)
    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal new_project, imported_program.projects.first
    assert_nil imported_program.program_projects.first.status_property
  end

  def test_should_import_program_projects_correctly_even_when_missing_done_status_value
    status_property_definition = nil
    @project.with_active_project do |project|
      setup_property_definitions('status' => ['xyz'])
      status_property_definition = project.find_property_definition('status')
    end
    @program.program_projects.first.update_attributes(:status_property => status_property_definition, :done_status => nil)

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_program = Program.find_by_name(@program.name)
    assert_equal new_project, imported_program.projects.first
    assert_nil imported_program.program_projects.first.status_property
  end

  def test_should_import_work_assigned_to_correct_project_when_same_identifier
    objective = @program.objectives.planned.create!(:name => 'o1', :start_at => 20.days.ago, :end_at => Time.now)
    @program.plan.assign_cards(@project, @card.number, objective)
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)
    new_project.with_active_project do |project|
      project.cards.create!(:name => @card.name, :card_type_name => 'Card')
    end

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    imported_objective = Program.find_by_name(@program.name).objectives.find_by_name('o1')
    assert_equal new_project, imported_objective.works.first.project
  end

  def test_should_fail_to_import_when_work_card_number_does_not_existing_project
    objective = @program.objectives.planned.create!(:name => 'o1', :start_at => 20.days.ago, :end_at => Time.now)
    @program.plan.assign_cards(@project, @card.number, objective)
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    assert_equal "completed failed", asynch_request.progress.status
    assert asynch_request.progress_msg =~ /Project #{@project.name.bold} has been updated after the plan was exported/
    assert_nil Program.find_by_identifier(@program.identifier)
  end

  def test_should_fail_to_import_when_card_name_does_not_match
    objective = @program.objectives.planned.create!(:name => 'o1', :start_at => 20.days.ago, :end_at => Time.now)
    @program.plan.assign_cards(@project, @card.number, objective)
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)
    new_project.with_active_project do |project|
      project.cards.create!(:name => "this is not the card you're looking for", :card_type_name => 'Card')
    end

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    assert_equal "completed failed", asynch_request.progress.status
    assert asynch_request.progress_msg =~ /Project #{@project.name.bold} has been updated after the plan was exported/
    assert_nil Program.find_by_identifier(@program.identifier)
  end

  def test_should_upgrade_old_export
    assert_nil Program.find_by_identifier('old_plan')
    project_that_needs_to_be_there = create_project(:name => 'part_of_old_export', :identifier => 'part_of_old_export')
    project_that_needs_to_be_there.with_active_project do |project|
      setup_property_definitions 'Done?' => ['Yes', 'No']
      project.cards.create!(:name => 'Big Story', :card_type_name => 'Card')
      project.cards.create!(:name => 'Little Story', :card_type_name => 'Card')
    end
    old_export_file = export_file('old_plan.plan')
    swap_folder = SwapDir::SwapFileProxy.new.pathname
    FileUtils.cp(old_export_file, swap_folder)
    asynch_request = @user.asynch_requests.create_program_import_asynch_request('old_plan', uploaded_file(old_export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    program = Program.find_by_identifier('old_plan')
    assert_equal 2, program.objectives.planned.count
    assert_equal 'Yes', program.program_projects.first.done_status.name

    objective = program.objectives.planned.create!(:name => 'o1', :start_at => 20.days.ago, :end_at => Time.now)
    objective_number = program.objectives.planned.select{|obj| obj.number == 1}
    assert_equal 1, objective_number.size
    assert_equal 3, objective.number
  end

  def test_should_upgrade_old_export_and_retain_backlog_objective_numbers
    assert_nil Program.find_by_identifier('old_plan_with_backlogs')
    old_export_file = export_file('old_plan_with_backlogs.program')
    swap_folder = SwapDir::SwapFileProxy.new.pathname
    FileUtils.cp(old_export_file, swap_folder)
    asynch_request = @user.asynch_requests.create_program_import_asynch_request('old_plan_with_backlogs', uploaded_file(old_export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    program = Program.find_by_identifier('old_plan_with_backlogs')
    assert_equal 2, program.objectives.count

    assert_equal 1, program.objectives.backlog.find_by_name('first').number
    assert_equal 2, program.objectives.backlog.find_by_name('second').number

    third_backlog = program.objectives.backlog.create(name: 'third')
    assert_equal 3, third_backlog.number
  end

  def test_should_upgrade_old_export_and_add_new_program_ids_to_the_objective
    assert_nil Program.find_by_identifier('old_plan_with_backlogs')
    old_export_file = export_file('old_plan_with_backlogs.program')
    swap_folder = SwapDir::SwapFileProxy.new.pathname
    FileUtils.cp(old_export_file, swap_folder)
    asynch_request = @user.asynch_requests.create_program_import_asynch_request('old_plan_with_backlogs', uploaded_file(old_export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    program = Program.find_by_identifier('old_plan_with_backlogs')

    assert_equal program.id, program.objectives.find_by_name('first').program_id
    assert_equal program.id, program.objectives.find_by_name('second').program_id
  end

  def test_should_upgrade_old_export_and_add_all_backlog_objectives_to_objectives_table_with_backlog_status
    assert_nil Program.find_by_identifier('old_plan_with_backlogs')
    old_export_file = export_file('old_plan_with_backlogs.program')
    swap_folder = SwapDir::SwapFileProxy.new.pathname
    FileUtils.cp(old_export_file, swap_folder)
    asynch_request = @user.asynch_requests.create_program_import_asynch_request('old_plan_with_backlogs', uploaded_file(old_export_file))
    message = { :request_id => asynch_request.id }
    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    program = Program.find_by_identifier('old_plan_with_backlogs')

    assert_equal Objective::Status::BACKLOG, program.objectives.find_by_name('first').status
    assert_equal Objective::Status::BACKLOG, program.objectives.find_by_name('second').status
  end

  def test_should_fail_cleanly_when_referenced_project_does_not_exist
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy
    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    importer = DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message)
    newly_created_plan = importer.process!
    assert_equal "completed failed", asynch_request.progress.status
    assert asynch_request.progress_msg =~ /Unable to locate the following projects. Make sure you have already migrated all projects to the new instance./
    assert_nil newly_created_plan
  end

  def test_should_fail_cleanly_when_referenced_done_property_does_not_exist
    status_property_definition = nil
    @project.with_active_project do |project|
      setup_property_definitions('status' => ['new', 'closed'])
      status_property_definition = project.find_property_definition('status')
    end
    @program.program_projects.first.update_attributes(:status_property => status_property_definition, :done_status => status_property_definition.find_enumeration_value('closed'))
    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    status_property_definition.delete

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    assert_nil DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    assert_equal "completed failed", asynch_request.progress.status
    assert asynch_request.progress_msg =~ /No such property: #{'status'.bold} in #{@project.name}/
    assert_nil Program.find_by_identifier(@program.identifier)
  end

  def test_should_fail_cleanly_when_referenced_done_property_value_does_not_exist
    status_property_definition = nil
    @project.with_active_project do |project|
      setup_property_definitions('status' => ['new', 'closed'])
      status_property_definition = project.find_property_definition('status')
    end
    @program.program_projects.first.update_attributes(:status_property => status_property_definition, :done_status => status_property_definition.find_enumeration_value('closed'))
    export_file = create_program_exporter!(@program, @user).process!

    @program.destroy
    status_property_definition.find_enumeration_value('closed').value = 'fragged'

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }
    assert_nil DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    assert_equal "completed failed", asynch_request.progress.status
    assert asynch_request.progress_msg =~ /Property #{'status'.bold} does not have value #{'closed'.bold} in #{@project.name}/
    assert_nil Program.find_by_identifier(@program.identifier)
  end

  def test_should_take_snapshot_for_objectives_of_imported_plan
    objective = @program.objectives.planned.create!(:name => 'o1', :start_at => 20.days.ago, :end_at => Time.now)
    @program.plan.assign_cards(@project, @card.number, objective)
    export_file = create_program_exporter!(@program, @user).process!

    @program.destroy
    @project.destroy
    clear_message_queue(ObjectiveSnapshotProcessor::QUEUE)

    new_project = Project.create!(:name => @project.name, :identifier => @project.identifier)
    new_project.with_active_project do |project|
      project.cards.create!(:name => @card.name, :card_type_name => 'Card')
    end

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }

    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    ObjectiveSnapshotProcessor.run_once(:batch_size => 1000)
    imported_objective = Program.find_by_name(@program.name).objectives.find_by_name('o1')
    assert imported_objective.objective_snapshots.any?
  end

  def test_that_it_recalculates_if_work_is_done_after_import_based_on_card_current_done_status_value
    unchanged_card = @project.cards.create!(:name => "Unchanged Card", :card_type => @project.card_types.first)
    unchanged_card.update_properties(:status => 'new')
    unchanged_card.save

    status_property_definition = nil
    @project.with_active_project do |project|
      setup_property_definitions('status' => ['new', 'closed'])
      status_property_definition = project.find_property_definition('status')
      project.card_types.first.property_definitions << status_property_definition
    end

    @program.program_projects.first.update_attributes(:status_property => status_property_definition, :done_status => status_property_definition.find_enumeration_value('closed'))

    objective = @program.objectives.planned.create!(:name => 'objective name', :start_at => Date.today, :end_at => (Date.today + 1))
    @program.plan.assign_cards(@project, [@card.number, unchanged_card.number], objective)

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    @project.with_active_project do |project|
      card = @project.cards.first
      card.update_properties(:status => 'closed')
      card.save
    end

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }

    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    imported_program = Program.find_by_name(@program.name)
    objective = imported_program.objectives.planned.first
    assert !objective.works.find_by_card_number(unchanged_card.number).completed
    assert objective.works.find_by_card_number(@card.number).completed
  end

  def test_skip_recalculating_work_done_status_if_done_status_is_not_set
    objective = @program.objectives.planned.create!(:name => 'objective name', :start_at => Date.today, :end_at => (Date.today + 1))
    @program.plan.assign_cards(@project, @card.number, objective)

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }

    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!
    imported_program = Program.find_by_name(@program.name)

    objective = imported_program.objectives.planned.first
    # if recalculation occurs all completed values would be set to false, make sure it is still nil
    assert_nil objective.works.find_by_card_number(@card.number).completed
  end

  def test_should_check_for_existance_of_projects_before_processing
    another_project = create_project(:name => 'another_project', :identifier => 'another_project')
    @program.assign(another_project)

    export_file = create_program_exporter!(@program, @user).process!
    @program.destroy
    @project.destroy
    another_project.destroy

    program_count = Program.count

    asynch_request = @user.asynch_requests.create_program_import_asynch_request(@program.identifier, uploaded_file(export_file))
    message = { :request_id => asynch_request.id }

    DeliverableImportExport::ProgramImporter.fromActiveMQMessage(message).process!

    assert_equal "Unable to locate the following projects. Make sure you have already migrated all projects to the new instance." +
       "<ul>" +
          "<li><b>#{@project.name}</b></li>" +
          "<li><b>#{another_project.name}</b></li>" +
       "</ul>", asynch_request.reload.error_details.first
    assert_nil Program.find_by_name(@program.name)
    assert_equal program_count, Program.count
  end


end
