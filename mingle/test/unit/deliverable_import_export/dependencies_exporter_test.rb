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

class DependenciesExporterTest < ActiveSupport::TestCase
  include Zipper

  def setup
    @admin = login_as_admin
    create_test_projects
    setup_dependencies_for_projects
  end

  def create_test_projects
    @member = User.find_by_login("member")
    @bob = User.find_by_login("bob")

    @project1 = create_project(:name => "Project1", :identifier => "project1").tap do |p1|
      p1.with_active_project do
        p1.add_member(@member)
        p1.add_member(@bob)
        @raising_card_1 = p1.cards.create!(:name => 'p1 card', :card_type_name => 'card')
      end
    end

    @project2 = create_project(:name => "Project2", :identifier => "project2").tap do |p2|
      p2.with_active_project do
        p2.add_member(@member)
        p2.add_member(@bob)
        @raising_card_2 = p2.cards.create!(:name => 'p2 card', :card_type_name => 'card')
      end
    end

    @project3 = create_project(:name => "Project3", :identifier => "project3") do |p3|
      p3.add_member(@member)
      p3.add_member(@bob)
    end

    @projects = [@project1, @project2]
  end

  def setup_dependencies_for_projects
    @project1.with_active_project do |p1|
      User.with_current(@member) do
        @dependency_1 = @raising_card_1.raise_dependency(
          :name => "First Dependency",
          :resolving_project_id => @project2.id,
          :desired_end_date => "2016-01-31"
        )
        @dependency_1.save!
      end
    end

    @project2.with_active_project do |p2|
      @dependency_2 = @raising_card_2.raise_dependency(
        :name => "Second Dependency",
        :resolving_project_id => @project1.id,
        :desired_end_date => "2016-01-31"
      )
      @dependency_2.save!

      User.with_current(@bob) do
        @dependency_3 = @raising_card_2.raise_dependency(:name => "Third Dependency",
          :resolving_project_id => @project3.id,
          :desired_end_date => "2016-01-31"
        )
        @dependency_3.save!
      end
    end
  end

  def test_should_mark_queued_after_created_project_export
    assert_equal "queued", create_dependencies_exporter!(@projects, @admin).status
  end

  def test_plan_export_should_contain_schema_migrations
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_migrations = YAML.load_file(File.join(dir, 'schema_migrations_0.yml'))
      assert exported_migrations.size > 0
    end
  end

  def test_export_should_contain_dependencies_information
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_dependencies = YAML.load_file(File.join(dir, 'dependencies_0.yml'))
      assert_equal 2, exported_dependencies.size
      assert_equal @dependency_1.number, exported_dependencies.first['number'].to_i
      assert_equal @dependency_2.number, exported_dependencies.last['number'].to_i
    end
  end

  def test_export_should_contain_dependencies_version_information
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_dependency_versions = YAML.load_file(File.join(dir, 'dependency_versions_0.yml'))
      assert_equal 2, exported_dependency_versions.size
    end
  end

   def test_export_should_contain_dependencies_resolving_card_table_information
     resolving_card_1 = nil
     @project2.with_active_project do |p2|
      resolving_card_1 = p2.cards.create!(:name => 'resolving card', :card_type_name => 'card')
      @dependency_1.link_resolving_cards([resolving_card_1])
    end
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_dependency_resolving_cards = YAML.load_file(File.join(dir, 'dependency_resolving_cards_0.yml'))
      assert_equal 2, exported_dependency_resolving_cards.size
      assert_equal resolving_card_1.number, exported_dependency_resolving_cards.first['card_number'].to_i
      assert_equal @dependency_1.id, exported_dependency_resolving_cards.first['dependency_id'].to_i
    end
  end

  def test_export_should_contain_project_information
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_projects = YAML.load_file(File.join(dir, 'deliverables_0.yml'))
      assert_equal 2, exported_projects.size
      assert_equal @project1.identifier, exported_projects.first['identifier']
      assert_equal @project2.identifier, exported_projects[1]['identifier']
    end
  end

  def test_export_should_contain_event_information
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_events = YAML.load_file(File.join(dir, 'events_0.yml'))
      assert_equal 4, exported_events.size
      assert_equal ['Dependency::Version'], exported_events.collect{ |e| e['origin_type'] }.uniq!
      assert_equal [ @project1.id, @project2.id ], exported_events.collect{ |e| e['deliverable_id'].to_i }.uniq!
    end
  end

  def test_export_should_contain_user_information
    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_users = YAML.load_file(File.join(dir, 'users_0.yml')).map { |u| u["login"] }.uniq.sort
      assert_equal ["admin", "member"], exported_users, "should only see 'admin' and 'member', but not 'bob' because dependency_3 is not included"
    end
  end

  def test_export_should_include_user_icons
    user = create_user!(:name => "hobo with an icon", :icon => sample_attachment("user_icon.png"))

    @project1.with_active_project do |p1|
      p1.add_member(user)
      User.with_current(user) do
        @raising_card_1.raise_dependency(
          :name => "Fourth Dependency",
          :resolving_project_id => @project2.id,
          :desired_end_date => "2016-01-31"
        ).save!
      end
    end
    export_file = create_dependencies_exporter!(@projects, @admin).process!

    with_unziped_dependencies_export(export_file) do |dir|
      exported_users = YAML.load_file(File.join(dir, 'users_0.yml')).map { |u| u["login"] }.uniq.sort
      assert exported_users.include?(user.login)
      assert_relative_file_path_in_directory "user/icon/#{user.id}/user_icon.png", dir
    end
  end

  def test_export_should_contain_attachments
    attachment1 = sample_attachment("dependency_attachment1.txt")
    attachment2 = sample_attachment("dependency_attachment2.txt")
    attachment3 = sample_attachment("dependency_attachment3.txt")

    @dependency_3.attach_files(attachment3)
    @dependency_2.attach_files(attachment1)
    @dependency_2.save!
    @dependency_2.remove_attachment("dependency_attachment1.txt")
    @dependency_2.save!
    @dependency_2.attach_files(attachment2)
    @dependency_2.save!

    export_file = create_dependencies_exporter!(@projects, @admin).process!
    with_unziped_dependencies_export(export_file) do |dir|
      exported_attachings = YAML.load_file(File.join(dir, 'attachings_0.yml'))
      exported_attachments = YAML.load_file(File.join(dir, 'attachments_0.yml'))
      Rails.logger.info  "********"*8
      Rails.logger.info "DEBUG output for attachment random failure"
      Rails.logger.info exported_attachings.inspect
      Rails.logger.info exported_attachments.inspect
      Rails.logger.info  "********"*8
      assert_equal 3, exported_attachings.size
      assert_equal 2, exported_attachments.size
      assert file_in_directory?("dependency_attachment1.txt", dir)
      assert file_in_directory?("dependency_attachment2.txt", dir)
      assert_false file_in_directory?("dependency_attachment3.txt", dir)
    end
  end
end
