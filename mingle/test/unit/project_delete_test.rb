#encoding: UTF-8

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

class ProjectDeleteTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_admin
  end

  def test_should_no_error_when_delete_a_non_exist_project
    project = Project.create(:name => 'new project', :identifier => 'new_project!')
    assert !project.valid?
    assert_nil project.id
    project.destroy
    assert_nil Project.find_by_name('new project')
  end

  def test_should_destroy_groups_with_project
    with_new_project do |project|
      project.user_defined_groups.create!(:name => 'Group')
      assert_difference "Group.count", -2 do
        project.destroy
      end
    end
  end

  def test_should_destroy_group_memberships_with_project
    bob = User.find_by_login('bob')
    with_new_project do |project|
      group = project.user_defined_groups.create!(:name => 'Group')
      project.add_member(bob)
      group.add_member(bob)
      assert_difference "UserMembership.count", -2 do
        project.destroy
      end
    end
  end

  def test_should_work_without_project_cards_and_card_versions_table
    with_new_project do |project|
      card1 = create_card!(:number => 1, :name => 'first card')
      card1.tag_with 'foo,rss'

      deleted_project_id = project.id

      project.drop_card_schema
      project.activate
      project.destroy

      assert !Project.connection.table_exists?(Card.table_name)
      assert !Project.connection.table_exists?(Card::Version.table_name)
      assert_equal [], Tag.find_all_by_project_id(deleted_project_id)
    end
  end

  def test_deleting_a_project_deletes_cards_and_pages_except_users
    with_new_project do |project|
      project.add_member(User.find_by_login('bob'))
      card1 = create_card!(:number => 1, :name => 'first card')
      card1.tag_with 'foo,rss'
      card1.save!
      project.pages.create!(:name => 'first page')

      user_count_before_delete = User.count

      deleted_project_id = project.id
      project.destroy
      assert !Project.connection.table_exists?(Card.table_name)
      assert !Project.connection.table_exists?(Card::Version.table_name)
      assert Tag.find(:all, :conditions => {:project_id => deleted_project_id}).empty?
      assert Page.find(:all, :conditions => {:project_id => deleted_project_id}).empty?
      assert_equal user_count_before_delete, User.count
    end
  end

  def test_can_delete_a_project_with_transitions_using_enum_values
    with_new_project do |project|
      setup_property_definitions :status => ['open', 'closed']
      close = project.transitions.new(:name => 'close', :project => project)
      close.add_set_value_action('status', 'closed')
      close.save!

      project.destroy
      assert_record_deleted project
    end
  end

  def test_deleteing_a_project_deletes_attachments_and_changes_and_history_subscriptions_and_revisions
    attaching_count_before_project_creation = Attaching.count
    with_new_project do |project|
      card =create_card!(:name => 'card for testing update attachments')
      card.attach_files(sample_attachment)
      card.save!
      project.history_subscriptions.create!(:user_id => User.find_by_login('member'), :last_max_card_version_id => 1,
        :last_max_page_version_id => 1, :last_max_revision_id => 1)
      project.revisions.create!(:number => 2, :identifier => '2',
        :commit_message => 'revision 2', :commit_time => Time.now, :commit_user => 'bob')

      attachment_paths = card.attachments.collect(&:full_directory_path)
      project.destroy
      assert attachment_paths.all?{|path| !File.exist?(path)}
      assert Attachment.find_all_by_project_id(project.id).empty?
      assert_equal attaching_count_before_project_creation, Attaching.count
      assert Event.find_all_by_deliverable_id(project.id).empty?
      assert HistorySubscription.find_all_by_project_id(project.id).empty?
      assert Revision.find_all_by_project_id(project.id).empty?
    end
  end

  def test_delete_all_events_and_changes
    with_new_project do |project|
      card = create_card!(:name => 'card for testing events and changes')
      card.update_attribute(:name, 'hello')


      events = card.versions.collect(&:event)
      events.each { |event| event.send(:generate_changes) }
      change_ids = events.each(&:reload).collect(&:changes).flatten.collect(&:id)

      project.destroy
      assert Event.find_all_by_deliverable_id(project.id).empty?
      change_ids.each { |change_id| assert_nil Change.find_by_id(change_id) }
    end
  end

  def test_deleteing_a_project_deletes_hidden_property_definition_and_their_values
    with_new_project do |project|
      setup_property_definitions(:old_type => ['card'])
      project.reload
      project.property_definitions.each{|property_definition|property_definition.update_attribute(:hidden, true)}

      project.destroy
      assert PropertyDefinition.find_all_by_project_id(project.id).empty?
    end
  end

  def test_should_delete_card_defaults
    with_new_project do |project|
      setup_property_definitions :status => ['open', 'closed']
      defaults = project.card_types.first.card_defaults
      defaults.update_attributes(:description => 'default description')
      defaults.update_properties(:status => 'open')
      defaults.save!
      project.destroy
      assert_equal [], TransitionAction.find_all_by_executor_id_and_executor_type(defaults.id, defaults.class.name)
      assert CardDefaults.find_all_by_project_id(project.id).empty?
    end
  end

  def test_deleteing_a_project_deletes_card_trees_and_tree_cards_mappings
    with_new_project do |project|
      init_planning_tree_types
      tree_config = project.tree_configurations.create!(:name => 'tree')
      init_three_level_tree(tree_config)
      project.reload

      project.destroy
      assert TreeConfiguration.find_all_by_project_id(project.id).empty?
      assert TreeBelonging.find_all_by_tree_configuration_id(tree_config.id).empty?
    end
  end

  def test_should_delete_project_variables_and_their_associations_with_property_definitions
    with_new_project do |project|
      project.connection.execute("delete from variable_bindings")
      setup_property_definitions :status => ['open', 'closed']
      status = project.find_property_definition('status')
      create_plv!(project, :name => 'CURRENT IT', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '5', :property_definitions => [status])
      project.destroy
      assert ProjectVariable.find_all_by_project_id(project.id).empty?
      assert project.connection.select_all("select project_variable_id from variable_bindings").empty?
    end
  end

  def test_deletes_all_repos_configs
    with_new_project do |project|
      SubversionConfiguration.create!(:project => project, :repository_path => "foorepository", :marked_for_deletion => nil)
      SubversionConfiguration.create!(:project => project, :repository_path => "foorepository", :marked_for_deletion => true)
      SubversionConfiguration.create!(:project => project, :repository_path => "foorepository", :marked_for_deletion => false)
      assert_equal 3, SubversionConfiguration.count(:conditions => ["project_id = #{project.id}"])
      project.destroy
      assert_equal 0, SubversionConfiguration.count(:conditions => ["project_id = #{project.id}"])
    end
  end

  def test_deletes_all_favourites
    with_new_project do |project|
      view = CardListView.construct_from_params(project, {:columns => 'Created by', :sort => 'Created by', :order => 'asc'})
      view.name = 'view'
      view.save!
      assert_difference "Favorite.count(:conditions => { :project_id => project.id })", -1 do
        project.destroy
      end
    end
  end

  def test_should_destroy_user_filter_usage_referencing_card_list_views_in_the_project_to_be_deleted
    member = nil
    project1 = with_new_project do |project|
      setup_user_definition('owner')
      member = create_user!
      project.add_member(member)
      view = CardListView.construct_from_params(project, {:columns => 'Created by', :sort => 'Created by', :order => 'asc', :filters => ["[owner][is][#{member.login}]"]})
      view.name = 'view'
      view.save!
    end
    with_new_project do |project|
      setup_user_definition('owner')
      project.add_member(member)
      view = CardListView.construct_from_params(project, {:columns => 'Created by', :sort => 'Created by', :order => 'asc', :filters => ["[owner][is][#{member.login}]"]})
      view.name = 'view'
      view.save!
    end
    assert_difference "UserFilterUsage.count", -1 do
      project1.destroy
    end
  end

  def test_should_destroy_user_filter_usage_referencing_history_subscriptions_in_the_project_to_be_deleted
    member = nil
    project1 = with_new_project do |project|
      setup_user_definition('owner')
      member = create_user!
      project.add_member(member)
      project.create_history_subscription member, HistoryFilterParams.new('acquired_filter_properties' => {'owner' => member.id.to_s}).to_hash

    end
    assert_equal 1, member.reload.user_filter_usages.count
    project1.destroy
    assert_equal 0, member.reload.user_filter_usages.count
  end

  def test_deletes_all_murmurs
    with_new_project do |project|
      create_murmur
      assert_equal 1, project.murmurs.count
      project.destroy
      assert_equal 0, project.murmurs.count
    end
  end

  def test_deletes_all_conversations
    with_new_project do |project|
      project.conversations.create
      assert_equal 1, project.conversations.count
      project.destroy
      assert_equal 0, project.conversations.count
    end
  end

  def test_delete_project_should_delete_all_member_roles
    with_new_project do |project|
      project.add_member(create_user!, :readonly_member)
      project.add_member(create_user!, :project_admin)
      project.destroy
      assert_equal 0, MemberRole.count(:conditions => {:deliverable_id => project.id})
    end
  end

  def test_deletes_all_dependency_views
    with_new_project do |project|
      project.dependency_views.create_by_user_id(User.current.id)
      assert_equal 1, project.dependency_views.count
      project.destroy
      assert_equal 0, project.dependency_views.count
    end
  end

  def test_deleting_project_should_destroy_raised_dependencies_but_leave_resolving_ones
    p1 = with_new_project do |p1|
      @p1_card = create_card!(:name => 'p1 card')
      card = create_card!(:name => 'p1 res card')

      @dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p1.id,
        :name => "some dependency"
      )
      @dep.save!
      @dep.link_resolving_cards([card])
    end

    with_new_project do |p2|
      card = create_card!(:name => 'p2 card')
      resolving_card = create_card!(:name => 'p2 card')
      raised_dep = card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p1.id,
        :name => "some dependency"
      )
      raised_dep.save!
      resolving_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p2.id,
        :name => "some dependency"
      )
      resolving_dep.save!
      resolving_dep.link_resolving_cards([resolving_card])
      resolving2_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p2.id,
        :name => "some dependency"
      )
      resolving2_dep.save!
      resolving2_dep.link_resolving_cards([resolving_card])
      resolving2_dep.toggle_resolved_status

      assert_equal 1,  resolving_dep.reload.dependency_resolving_cards.length
      resolving_dep_dhc_id = resolving_dep.dependency_resolving_cards.first.id

      p2.destroy

      assert_false Dependency.exists?(raised_dep.id)
      assert Dependency.exists?(resolving_dep.id)
      assert_equal 'NEW', resolving_dep.reload.status
      assert_nil resolving_dep.resolving_project_id
      assert_false DependencyResolvingCard.exists?(resolving_dep_dhc_id)
      assert_equal 'RESOLVED', resolving2_dep.reload.status
      assert Dependency.exists?(@dep.id)
      assert_equal p1.id, @dep.reload.resolving_project_id
      assert_equal 1, @dep.dependency_resolving_cards.length
    end
  end

  def test_deleting_raising_project_should_murmur_resolving_projects
    p1 = with_new_project do |p1|
      @p1_card = create_card!(:name => 'p1 card')
    end

    p2 = with_new_project do |p2|
      card = create_card!(:name => 'p2 card', :number => 55)
      card2 = create_card!(:name => 'p2 card', :number => 57)
      resolving_card = create_card!(:name => 'p2 card', :number => 56)
      resolving_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p2.id,
        :name => "some dependency"
      )
      resolving_dep.save!
      resolving_dep.link_resolving_cards([resolving_card])
      resolving2_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p2.id,
        :name => "some dependency"
      )
      resolving2_dep.save!
      resolving2_dep.link_resolving_cards([card, resolving_card, card2])
    end

    p3 = with_new_project do |p3|
      resolving_card = create_card!(:name => 'p2 card', :number => 59)
      resolving_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p3.id,
        :name => "some dependency"
      )
      resolving_dep.save!
      resolving_dep.link_resolving_cards([resolving_card])
    end

    p4 = with_new_project do |p4|
      resolving_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p4.id,
        :name => "some dependency"
      )
      resolving_dep.save!
    end

    p5 = with_new_project do |p5|
      card1 = create_card!(:name => 'p2 card', :number => 60)
      card2 = create_card!(:name => 'p2 card', :number => 61)
      resolving_dep = @p1_card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p5.id,
        :name => "some dependency"
      )
      resolving_dep.save!
      resolving_dep.link_resolving_cards([card1, card2])
    end

    p1_name = p1.name
    p1.destroy

    p2.with_active_project do |p2|
      assert_equal 1, p2.murmurs.length
      assert_equal p1_name, p2.murmurs.first.author.name
      assert_equal "The project \"#{p1_name}\" and its dependencies were deleted. The resolving cards — #56, #55, and #57 — have been unlinked.", p2.murmurs.first.murmur
    end

    p3.with_active_project do |p3|
      assert_equal 1, p3.murmurs.length
      assert_equal p1_name, p3.murmurs.first.author.name
      assert_equal "The project \"#{p1_name}\" and its dependencies were deleted. The resolving card, #59, has been unlinked.", p3.murmurs.first.murmur
    end

    p5.with_active_project do |p5|
      assert_equal 1, p5.murmurs.length
      assert_equal p1_name, p5.murmurs.first.author.name
      assert_equal "The project \"#{p1_name}\" and its dependencies were deleted. The resolving cards, #60 and #61, have been unlinked.", p5.murmurs.first.murmur
    end

    p4.with_active_project do |p4|
      assert_equal 1, p4.murmurs.length
      assert_equal p1_name, p4.murmurs.first.author.name
      assert_equal "The project \"#{p1_name}\" and its dependencies were deleted.", p4.murmurs.first.murmur
    end
  end

  def test_deleting_project_should_destroy_dependencies_raised_on_itself
    with_new_project do |p1|
      card = create_card!(:name => 'p1 card')
      resolving_card = create_card!(:name => 'res card')

      dep = card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => p1.id,
        :name => "some dependency"
      )
      dep.save!
      dep.link_resolving_cards([resolving_card])
      drc = dep.dependency_resolving_cards.first

      p1.destroy
      assert_false Dependency.exists?(dep.id)
      assert_false DependencyResolvingCard.exists?(drc.id)
    end
  end

  def test_deleting_raising_project_with_dependencies_should_delete_versions_and_events
    p1 = with_new_project do |p1|
      @p1_card = create_card!(:name => 'p1 card')
      card = create_card!(:name => 'p1 res card')
    end

    with_new_project do |p2|
      card = create_card!(:name => 'p2 card')
      resolving_card = create_card!(:name => 'p2 card')
      raised_dep = card.raise_dependency(
                            :desired_end_date => "8-11-2014",
                            :resolving_project_id => p1.id,
                            :name => "some dependency")
      raised_dep.save!
      raised_dep.link_resolving_cards([@p1_card])
      latest_version =  raised_dep.versions.last

      p2.destroy

      assert_false Dependency::Version.exists?(:dependency_id => raised_dep.id)
      assert_false DependencyResolvingCard.exists?(:project_id => p2.id)
      assert_false Event.exists?(:origin_id => latest_version.id, :origin_type => 'Dependency::Version')
    end
  end

  def test_deleting_resolving_project_with_dependencies_should_delete_versions_and_events
    p2 = with_new_project do |p2|
      @p2_card = create_card!(:name => 'p2 card')
    end

    p1 = with_new_project do |p1|
      card = create_card!(:name => 'p1 res card')

      @dep = card.raise_dependency(
                            :desired_end_date => "8-11-2014",
                            :resolving_project_id => p2.id,
                            :name => "some dependency")
      @dep.save!
      @dep.link_resolving_cards([@p2_card])
    end

    p2.with_active_project do |p2|
      latest_version =  @dep.versions.last

      p2.destroy

      assert_nil latest_version.reload.resolving_project_id
      assert_false DependencyResolvingCard.exists?(:project_id => p2.id)
      assert_false Event.exists?(:origin_id => latest_version.id, :origin_type => 'Dependency::Version', :deliverable_id => p2.id )
      assert_false Event.exists?(:origin_type => 'Dependency::Version', :deliverable_id => p2.id )
      assert Event.exists?(:origin_id => latest_version.id, :origin_type => 'Dependency::Version', :deliverable_id => p1.id )
    end
  end
end
