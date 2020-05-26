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

class ProgramExporterTest < ActiveSupport::TestCase
  include Zipper

  def setup
    @user = login_as_admin
    @program = program('simple_program')
    @project = sp_first_project
    setup_unexported_plan_with_objectives_and_work
  end

  def setup_unexported_plan_with_objectives_and_work
    @unexported_program = create_program
    @unexported_plan = @unexported_program.plan
    @unexported_program.assign(@project)
    objective = @unexported_program.objectives.planned.create(:name => 'great things', :start_at => '2011-1-1', :end_at => '2011-2-1')
    objective.save!
    objective.filters.create!(:project => @project, :params => {:filters => ["[status][is][new]"]})

    @unexported_plan.assign_cards(@project, 1, objective)
    @unexported_plan.assign_cards(@project, 2, objective)
  end

  def test_should_mark_queued_after_created_project_export
    assert_equal "queued", create_program_exporter!(@program, User.current).status
  end

  def test_plan_export_should_contain_schema_migrations
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_migrations = YAML.load_file(File.join(dir, 'schema_migrations_0.yml'))
      assert exported_migrations.size > 0
    end
  end

  def test_export_should_contain_plan_information
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_plans = YAML.load_file(File.join(dir, 'plans_0.yml'))
      assert_equal 1, exported_plans.size
    end
  end

  def test_export_should_contain_program_information
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_deliverables = YAML.load_file(File.join(dir, 'deliverables_0.yml'))
      exported_programs = exported_deliverables.select { |d| d['type'] == 'Program' }
      assert_equal 1, exported_programs.size
      assert_equal @program.identifier, exported_programs.first['identifier']
    end
  end

  def test_export_should_contain_objectives
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_objectives = YAML.load_file(File.join(dir, 'objectives_0.yml'))
      assert exported_objectives.size > 0
      assert_equal @program.objectives.planned.size, exported_objectives.size
    end
  end

  def test_export_should_contain_work
    objectives = @program.objectives.planned
    @program.plan.assign_cards(@project, 1, objectives[0])
    @program.plan.assign_cards(@project, 2, objectives[1])

    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_work = YAML.load_file(File.join(dir, 'works_0.yml'))
      assert_equal @program.plan.works.size, exported_work.size
    end
  end

  def test_export_should_contain_objective_filters
    filter = @program.objectives.planned.first.filters.create!(:project => @project, :params => {:filters => ["[status][is][new]"]})
    filter = @program.objectives.planned.first.filters.create!(:project => project_without_cards, :params => {:filters => ["[status][is][new]"]})

    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_filters = YAML.load_file(File.join(dir, 'objective_filters_0.yml'))
      assert_equal 2, exported_filters.size
    end
  end

  def test_export_should_contain_groups
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      groups = YAML.load_file(File.join(dir, 'groups_0.yml'))
      assert_equal 1, groups.size
    end
  end

  def test_export_should_contain_user_memberships
    member = User.find_by_login('member')
    @program.add_member member

    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      user_memberships = YAML.load_file(File.join(dir, 'user_memberships_0.yml'))
      assert_equal 1, user_memberships.size
    end
  end

  def test_export_should_contain_team_members_with_icons
    @program.add_member User.find_by_login('bob')
    user_with_icon = create_user!(:name => 'icon joe', :login => 'iconj', :icon => sample_attachment('user_icon.png'))
    @program.add_member user_with_icon

    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      users = YAML.load_file(File.join(dir, 'users_0.yml'))
      assert_equal 3, users.size
      assert File.exists? "#{dir}/user/icon/#{user_with_icon.id}/user_icon.png"
    end
  end

  def test_export_should_contain_program_projects
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_program_projects = YAML.load_file(File.join(dir, 'program_projects_0.yml'))
      assert_equal @program.projects.size, exported_program_projects.size
    end
  end

  def test_export_should_contain_objective_types
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_program_projects = YAML.load_file(File.join(dir, 'objective_types_0.yml'))
      assert_equal @program.objective_types.size, exported_program_projects.size
    end
  end

  def test_export_should_contain_project_records_referenced_by_plan
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_deliverables = YAML.load_file(File.join(dir, 'deliverables_0.yml'))
      exported_projects = exported_deliverables.select { |d| d['type'] == 'Project' }
      assert_equal 2, exported_projects.size
      assert_equal ['sp_first_project', 'sp_second_project'], exported_projects.collect { |record| record['identifier'] }
      assert_equal safe_table_names(['sp_first_project_cards', 'sp_second_project_cards']), exported_projects.collect { |record| record['cards_table'] }
      assert_equal safe_table_names(['sp_first_project_card_versions', 'sp_second_project_card_versions']), exported_projects.collect { |record| record['card_versions_table'] }
    end
  end

  def safe_table_names(names)
    names.map { |name| ActiveRecord::Base.connection.safe_table_name(name) }
  end

  def test_should_export_property_and_value_defined_in_project_done_status
    export_file = create_program_exporter!(@program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_property_definitions = YAML.load_file(File.join(dir, 'property_definitions_0.yml'))
      assert_equal 1, exported_property_definitions.count
      assert_equal "status", exported_property_definitions.first['name']
      exported_enumeration_values = YAML.load_file(File.join(dir, 'enumeration_values_0.yml'))
      assert_equal 1, exported_enumeration_values.count
      assert_equal "closed", exported_enumeration_values.first['value']
    end
  end

  def test_should_export_member_role_for_program
    program = create_program('sample_program')
    @user1=User.find_by_login('bob')
    program.add_member(@user1, :full_member)

    export_file = create_program_exporter!(program, @user).process!
    with_unziped_plan_export(export_file) do |dir|
      exported_member_roles = YAML.load_file(File.join(dir, 'member_roles_0.yml'))
      
      assert_equal 2, exported_member_roles.count
      assert_equal @user.id, exported_member_roles.first['member_id'].to_i
      assert_equal @user1.id, exported_member_roles.second['member_id'].to_i
      assert_equal program.id, exported_member_roles.first['deliverable_id'].to_i
      assert_equal program.id, exported_member_roles.second['deliverable_id'].to_i
      assert_equal 'program_admin', exported_member_roles.first['permission']
      assert_equal 'full_member', exported_member_roles.second['permission']
    end
  end

  def sample_user(name)
    User.new(:name => name, :login => name, :email => "#{name}@domain.com", :admin => true, :password => 'abc123')
  end

end
