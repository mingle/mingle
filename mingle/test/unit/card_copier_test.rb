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

class Card::CardCopierTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_property_definitions_that_are_allowed_to_be_copied
    [UserPropertyDefinition.new, EnumeratedPropertyDefinition.new, IntegerPropertyDefinition.new, DatePropertyDefinition.new, TextPropertyDefinition.new].each do |definition|
      assert_equal true, definition.allow_copy?
    end
  end

  def test_property_definitions_that_are_not_allowed_to_be_copied
    [FormulaPropertyDefinition.new, AggregatePropertyDefinition.new, CardPropertyDefinition.new, CardRelationshipPropertyDefinition.new, TreeRelationshipPropertyDefinition.new].each do |definition|
      assert_equal false, definition.allow_copy?
    end
  end

  def test_copy_to_target_project_should_copy_checklist_items
    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => "with checklists"
      card_to_copy.checklist_items.create! :text => "hello", :completed => true, :position => 1
      card_to_copy.checklist_items.create! :text => "world", :completed => false, :position => 2
      card_to_copy.reload
      copier = CardCopier.new(card_to_copy.reload, source)

      new_card = copier.copy_to_target_project
      checklists = new_card.checklist_items.all.sort_by(&:position)

      assert_equal "hello", checklists.first.text
      assert_equal 1, checklists.first.position
      assert checklists.first.completed

      assert_equal "world", checklists.last.text
      assert_equal 2, checklists.last.position
      assert !checklists.last.completed
    end
  end

  def test_should_include_all_tree_relationship_properties_when_copying_within_same_project
    tree_configuration = nil
    source_project = with_new_project do |source|
      tree_configuration = source.tree_configurations.create!(:name => "planning")
      init_empty_planning_tree tree_configuration
    end

    source_project.reload.with_active_project do |source|
      type_release, type_story = %w{release story}.collect { |card_type_name| source.card_types.find_by_name(card_type_name) }

      release_card = create_card! :name => "release", :card_type => type_release
      tree_configuration.add_child(release_card, :to => :root)
      card_to_copy = create_card! :name => "jimmy", :card_type => type_story
      tree_configuration.add_child(card_to_copy, :to => release_card)

      copier = CardCopier.new(card_to_copy, source)

      assert copier.never_copiable_properties_for(TreeRelationshipPropertyDefinition).empty?
      assert copier.setting_to_not_set_properties.empty?

      new_card = copier.copy_to_target_project
      assert_equal release_card.id, new_card.cp_planning_release_card_id
    end
  end

  def test_should_include_all_card_relationship_properties_when_copying_within_same_project
    source_project = with_new_project do |source|
      setup_card_relationship_property_definition "owner"
    end

    source_project.with_active_project do |source|
      owner = create_card! :name => "timmy"
      card_to_copy = create_card! :name => "jimmy"
      card_to_copy.update_attributes :cp_owner_card_id => owner.id

      copier = CardCopier.new(card_to_copy, source)

      assert copier.never_copiable_properties_for(CardRelationshipPropertyDefinition).empty?
      assert copier.setting_to_not_set_properties.empty?

      new_card = copier.copy_to_target_project
      assert_equal owner.id, new_card.cp_owner_card_id
    end
  end

  def test_copy_to_target_project_should_copy_attachments_within_same_project
    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      card_to_copy.attach_files(sample_attachment('1.txt'), sample_attachment('2.jpg'))
      card_to_copy.description = %Q{

<h1>Testing Card Copy</h1>

<p>Link to attachment: <span>[[sample attachment|1.txt]]</span></p>

<p>Inline image attachment: !2.jpg!</p>

      }
      card_to_copy.save!
      copier = CardCopier.new(card_to_copy.reload, source)

      new_card = copier.copy_to_target_project
      assert_equal "Copy of copy", new_card.name
      assert_equal ['1_copy_1.txt', '2_copy_1.jpg'], new_card.attachments.map(&:file_name).sort
      assert new_card.description.include?("[[sample attachment| 1_copy_1.txt]]")
      assert new_card.description.include?("!2_copy_1.jpg!")

      copier = CardCopier.new(new_card, source)
      another_new_card = copier.copy_to_target_project
      assert_equal "Copy of Copy of copy", another_new_card.name
      assert_equal ['1_copy_2.txt', '2_copy_2.jpg'], another_new_card.attachments.map(&:file_name).sort
      assert another_new_card.description.include?("[[sample attachment| 1_copy_2.txt]]")
      assert another_new_card.description.include?("!2_copy_2.jpg!")
    end
  end

  def test_copy_to_target_project_should_avoid_attachment_name_collisions
    source_project = with_new_project do |source|
      other_card = create_card! :name => 'other card'
      other_card.attach_files(sample_attachment('1_copy_1.txt'))
      other_card.save!

      card_to_copy = create_card! :name => 'copy'
      card_to_copy.attach_files(sample_attachment('1.txt'))
      card_to_copy.save!
      copier = CardCopier.new(card_to_copy.reload, source)

      new_card = copier.copy_to_target_project
      assert_equal "Copy of copy", new_card.name
      assert_equal 1, new_card.attachments.size
      assert_not_equal "1_copy_1.txt", new_card.attachments.map(&:file_name).first
      assert (new_card.attachments.map(&:file_name).first =~ /1_copy_1-[a-z0-9]{6}.txt/)
    end
  end

  def test_never_copiable_properties_for_should_contain_all_tree_relationship_properties
    tree_configuration = nil
    source_project = with_new_project do |source|
      tree_configuration = source.tree_configurations.create!(:name => 'planning')
      init_empty_planning_tree tree_configuration
    end

    target_project = with_new_project do |target|
      init_empty_planning_tree target.tree_configurations.create!(:name => 'planning')
      init_empty_planning_tree tree_configuration
    end

    source_project.with_active_project do |source|
      type_release, type_iteration, type_story = %w{release iteration story}.collect { |card_type_name| source.card_types.find_by_name(card_type_name) }
      release_card = create_card! :name => 'release', :card_type => type_release
      tree_configuration.add_child(release_card, :to => :root)
      card_to_copy = create_card! :name => 'jimmy', :card_type => type_story
      tree_configuration.add_child(card_to_copy, :to => release_card)

      copier = CardCopier.new(card_to_copy, target_project)

      assert_equal ['Planning iteration', 'Planning release'], copier.never_copiable_properties_for(TreeRelationshipPropertyDefinition).map(&:name)
      assert copier.setting_to_not_set_properties.empty?
    end
  end

  def test_never_copiable_properties_for_should_contain_all_card_relationship_properties
    source_project = with_new_project do |source|
      setup_card_relationship_property_definition 'owner'
      # a and B are present to show smart sorting.
      setup_card_relationship_property_definition 'a'
      setup_card_relationship_property_definition 'B'
    end
    target_project = with_new_project do |target|
      setup_card_relationship_property_definition 'owner'
      setup_card_relationship_property_definition 'a'
      setup_card_relationship_property_definition 'B'
    end

    source_project.with_active_project do |source|
      owner = create_card! :name => 'timmy'
      card_to_copy = create_card! :name => 'jimmy'
      card_to_copy.update_attributes :cp_owner_card_id => owner.id, :cp_a_card_id => owner.id, :cp_b_card_id => owner.id

      copier = CardCopier.new(card_to_copy, target_project)

      assert_equal ['a', 'B', 'owner'], copier.never_copiable_properties_for(CardRelationshipPropertyDefinition).map(&:name)
      assert copier.setting_to_not_set_properties.empty?
    end
  end

  def test_never_copiable_properties_for_should_contain_all_formula_properties
    target_project = with_new_project do |target|
      setup_formula_property_definition('formula', "1+1")
    end

    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => 'copy', :type => 'Card'
      formula = setup_formula_property_definition('formula', '2+2')

      type = card_to_copy.card_type
      type.property_definitions = type.property_definitions + [formula]
      type.save!
      formula.update_all_cards

      copier = CardCopier.new(card_to_copy, target_project)

      assert_equal ['formula'], copier.never_copiable_properties_for(FormulaPropertyDefinition).map(&:name)
      assert copier.setting_to_not_set_properties.empty?
    end
  end

  def test_never_copiable_properties_for_should_contain_all_aggregate_properties
    target_project = create_tree_project(:init_empty_planning_tree) do |target_project, tree, config|
      type_release = target_project.card_types.find_by_name('release')
      setup_aggregate_property_definition('count_aggregate', AggregateType::COUNT, nil, config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
    end

    create_tree_project(:init_empty_planning_tree) do |source_project, tree, config|
      type_release = source_project.card_types.find_by_name('release')
      aggregate_prop_def = setup_aggregate_property_definition('count_aggregate', AggregateType::COUNT, nil, config.id, type_release.id, AggregateScope::ALL_DESCENDANTS)

      card_to_copy = create_card! :name => 'one', :card_type => type_release
      copier = CardCopier.new(card_to_copy, target_project)

      assert_equal ['count_aggregate'], copier.never_copiable_properties_for(AggregatePropertyDefinition).map(&:name)
      assert copier.setting_to_not_set_properties.empty?
    end
  end

  def test_setting_to_not_set_properties_should_contain_user_properties_whose_value_is_not_team_member_in_target_project
    source_project = with_new_project do |source|
      setup_user_definition 'property_exists_in_target_project'
      setup_user_definition 'property_not_exist_in_target_project'
      # a and B show that properties are smart sorted
      setup_user_definition 'a'
      setup_user_definition 'B'
      source.card_types.first.update_attribute :name, source.card_types.first.name.downcase
    end

    target_project = with_new_project do |target|
      setup_user_definition 'property_exists_in_TARGET_PROJECT'
      setup_user_definition 'a'
      setup_user_definition 'B'
      target.card_types.first.update_attribute :name, target.card_types.first.name.upcase
    end

    alice = User.find_by_login 'member'
    bob   = User.find_by_login 'longbob'
    source_project.add_member alice
    source_project.add_member bob
    target_project.add_member alice

    source_project.with_active_project do
      alice_card = create_card! :name => 'alice', :property_exists_in_target_project => alice.id, :property_not_exist_in_target_project => alice.id
      bob_card = create_card! :name => 'bob', :property_exists_in_target_project => bob.id, :property_not_exist_in_target_project => bob.id, :a => bob.id, :b => bob.id

      copier = CardCopier.new(bob_card, target_project)
      assert_equal ['a', 'B', 'property_exists_in_target_project'], copier.setting_to_not_set_properties_for(UserPropertyDefinition).map(&:name), "Failed. Should have warning since Bob is not member of target project."

      not_set_card = create_card! :name => 'no user properties set'
      copier = CardCopier.new(not_set_card, target_project)
      assert copier.setting_to_not_set_properties_for(UserPropertyDefinition).empty?
    end
  end

  def test_setting_to_not_set_properties_should_contain_locked_properties_when_user_is_not_admin
    full_user = create_user! :admin => false
    target_project = with_new_project(:users => [full_user]) do |target|
      locked = setup_property_definitions('locked' => ['1', '3']).first
      locked.restricted = true
      locked.save!
    end

    source_project = with_new_project(:users => [full_user]) do |source|
      setup_property_definitions 'locked' => ['1', '2', '3']
      card_to_copy = create_card! :name => 'copy', :locked => '2'

      User.with_current(full_user) do
        copier = CardCopier.new(card_to_copy, target_project)

        assert_equal [], copier.never_copiable_properties_for(EnumeratedPropertyDefinition)
        assert_equal ['locked'], copier.setting_to_not_set_properties_for(EnumeratedPropertyDefinition).map(&:name)
      end
    end
  end

  def test_setting_to_not_set_properties_should_not_contain_locked_properties_when_user_is_admin
    admin = create_user! :admin => true
    target_project = with_new_project(:admins => [admin]) do |target|
      locked = setup_property_definitions('locked' => ['1', '3']).first
      locked.restricted = true
      locked.save!
    end

    source_project = with_new_project(:admins => [admin]) do |source|
      setup_property_definitions 'locked' => ['1', '2', '3']
      card_to_copy = create_card! :name => 'copy', :locked => '2'

      User.with_current(admin) do
        copier = CardCopier.new(card_to_copy, target_project)

        assert_equal [], copier.never_copiable_properties_for(EnumeratedPropertyDefinition)
        assert_equal [], copier.setting_to_not_set_properties_for(EnumeratedPropertyDefinition).map(&:name)
      end
    end
  end

  def test_hidden_properties_that_will_be_copied_should_contain_hidden_properties_that_will_be_copied
    target_project = with_new_project do |target|
      setup_text_property_definition('hidden_one').update_attribute :hidden, true
      setup_text_property_definition('hidden_two').update_attribute :hidden, true
    end

    with_new_project do |source|
      setup_text_property_definition('hidden_one').update_attribute :hidden, true
      setup_text_property_definition('hidden_two').update_attribute :hidden, true

      card_to_copy = create_card! :name => 'copy', :hidden_one => 'uno', :hidden_two => 'dos'
      copier = CardCopier.new(card_to_copy.reload, target_project)
      assert_equal ['hidden_one', 'hidden_two'], copier.hidden_properties_that_will_be_copied.map(&:name)
    end
  end

  def test_missing_attachments_should_contain_attachment_filenames_if_they_are_missing
    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      card_to_copy.attach_files(sample_attachment)
      attachment = card_to_copy.attachments.first
      attachment.write_attribute(:file, 'doesnt_exist')
      attachment.save!

      copier = CardCopier.new(card_to_copy.reload, create_project)
      assert_equal ['doesnt_exist'], copier.missing_attachments.map(&:file_name)
    end
  end

  def test_warnings_are_all_empty_when_nothing_significant_happens
    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      copier = CardCopier.new(card_to_copy.reload, create_project)

      assert copier.never_copiable_properties.empty?
      assert copier.setting_to_not_set_properties.empty?
      assert copier.missing_attachments.empty?
      assert copier.hidden_properties_that_will_be_copied.empty?
    end
  end

  def test_copy_to_target_project_should_not_copy_value_over_when_property_name_exists_in_both_projects_but_under_different_card_type
    target_project = with_new_project do |target|
      release_type = target.card_types.first
      release_type.update_attribute :name, 'Release'
      story_type = target.card_types.create! :name => 'Story'
      exists = setup_text_property_definition 'exists_on_different_card_type'
      exists.card_types = [release_type]
    end

    new_card = nil
    with_new_project do |source|
      story_type = source.card_types.first
      story_type.update_attribute :name, 'Story'
      exists = setup_text_property_definition 'exists_on_different_card_type'
      exists.card_types = [story_type]

      card_to_copy = create_card! :name => 'bob', :exists_on_different_card_type => 'TEXT'
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      prop = target.find_property_definition('exists_on_different_card_type')
      assert_nil prop.value(new_card.reload)
    end
  end

  def test_copy_to_target_project_should_not_copy_value_over_when_same_name_property_type_is_enumerated_text_but_the_other_is_enumerated_numeric
    target_project = with_new_project do |target|
      setup_managed_text_definition 'same_name', ["1", "2"]
    end

    new_card = nil
    with_new_project do |source|
      setup_numeric_property_definition 'same_name', ["1", "2"]
      card_to_copy = create_card! :name => 'card', :same_name => "1"

      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_nil new_card.reload.cp_same_name
    end
  end

  def test_copy_to_target_project_should_not_copy_value_over_when_properties_are_same_name_but_property_type
    target_project = with_new_project do |target|
      setup_text_property_definition 'same_name'
    end

    new_card = nil
    with_new_project do
      setup_numeric_property_definition 'same_name', ['1.11']
      card_to_copy = create_card! :name => 'bob', :same_name => '1.11'
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_nil new_card.reload.cp_same_name
    end
  end

  def test_copy_to_target_project_should_copy_all_basic_info
    target_project = create_project

    with_new_project do |source|
      card_to_copy = create_card! :name => 'copy', :description => 'this is the description'

      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
      assert_equal target_project.id, new_card.project_id
      assert_equal 'copy', new_card.name
      assert_equal 'this is the description', new_card.description
    end
  end

  def test_copy_to_target_project_should_produce_new_card_tagged_with_same_tags
    target_project = with_new_project { |target| create_card! :tags => "already_exists", :name => "ignore" }

    new_card = nil
    with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      card_to_copy.tag_with('already_exists, create_in_target')

      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal ["already_exists", "create_in_target"], new_card.reload.tags.map(&:name).sort
      assert_equal 1, new_card.versions.size
    end
  end

  def test_copy_to_target_project_should_copy_attachments
    target_project = create_project

    card_to_copy, new_card = nil, nil
    with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      card_to_copy.attach_files(sample_attachment('1.txt'), sample_attachment('2.txt'))
      card_to_copy.save!
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal 2, new_card.reload.attachments.size
      assert_equal ['1.txt', '2.txt'], new_card.attachments.map(&:file_name).sort
      assert_equal 1, new_card.versions.size
      assert_not_equal card_to_copy.attachments.map { |attachment| attachment.file }.sort, new_card.attachments.map { |attachment| attachment.file }.sort
    end
  end

  def test_copy_to_target_project_should_ignore_attachments_with_bad_paths
    # This scenario would happen if they change their data dir, but don't copy the attachments.
    target_project = create_project

    new_card = nil
    with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      card_to_copy.attach_files(sample_attachment('1.txt'), sample_attachment('2.txt'))
      card_to_copy.save!
      attachment_2 = card_to_copy.attachments.detect { |attachment| attachment.attributes['file'] == '2.txt' }
      source.connection.execute("UPDATE #{Attachment.table_name} SET path='attachments/bullspit' WHERE id=#{attachment_2.id}")
      attachment_2.reload

      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal 1, new_card.reload.attachments.size
      assert_equal ['1.txt'], new_card.attachments.map(&:file_name)
    end
  end

  def test_copy_to_target_project_should_copy_hidden_properties
    target_project = with_new_project do |target|
      hidden = setup_text_property_definition 'hidden'
      hidden.update_attribute :hidden, true
    end

    new_card = nil
    source_project = with_new_project do |source|
      hidden = setup_text_property_definition 'hidden'
      hidden.update_attribute :hidden, true
      card_to_copy = create_card! :name => 'copy', :hidden => 'copy_value'
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal 'copy_value', new_card.reload.cp_hidden
    end
  end

  def test_copy_to_target_project_should_not_copy_formula_value_or_formula
    target_project = with_new_project do |target|
      setup_formula_property_definition('formula', "1+1")
    end

    new_card = nil
    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => 'copy', :type => 'Card'
      formula = setup_formula_property_definition('formula', '2+2')
      type = card_to_copy.card_type
      type.property_definitions = type.property_definitions + [formula]
      type.save!
      formula.update_all_cards

      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      formula = new_card.reload.property_definitions_with_hidden.find{ |p| p.name == "formula"}
      formula.update_all_cards
      assert_equal 2, formula.value(new_card.reload)
      assert_equal "1+1", formula.reload.attributes['formula']
    end
  end

  def test_copy_to_target_project_should_not_copy_properties_which_do_not_exist_in_target
    target_project = with_new_project do |target|
      setup_text_property_definition 'exists'
    end
    new_card = nil
    source_project = with_new_project do
      setup_text_property_definition 'exists'
      setup_text_property_definition 'doesnt_exist'
      card_to_copy = create_card! :name => 'copy', :exists => 'will_copy', :doesnt_exist => 'wont_copy'
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert new_card.reload.property_definitions_with_hidden.map(&:name).any?{ |p| p == "exists"}
      assert !new_card.reload.property_definitions_with_hidden.map(&:name).any?{ |p| p == "doesnt_exist"}
    end
  end

  def test_copy_to_target_project_should_copy_users_that_are_team_members_in_the_target_project
    source_project = with_new_project do
      setup_user_definition 'owner'
    end

    target_project = with_new_project do
      setup_user_definition 'owner'
    end

    bob = User.find_by_login 'longbob'
    target_project.add_member bob
    source_project.add_member bob

    new_card = nil
    source_project.with_active_project do
      card_to_copy = create_card! :name => 'copy', :owner => bob.id

      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal bob, new_card.reload.cp_owner
    end
  end

  def test_copy_to_target_project_should_not_copy_users_that_are_not_team_members_in_the_target_project
    source_project = with_new_project do
      setup_user_definition 'owner'
    end

    target_project = with_new_project do
      setup_user_definition 'owner'
    end

    bob = User.find_by_login 'longbob'
    source_project.add_member bob

    new_card = nil
    source_project.with_active_project do
      card_to_copy = create_card! :name => 'copy', :owner => bob.id
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_nil new_card.reload.cp_owner
    end
  end

  def test_copy_to_target_project_should_create_managed_text_value_when_it_doesnt_exist_in_target
    target_project = with_new_project do |target|
      setup_managed_text_definition("managed_text", ['left'])
    end

    new_card = nil
    source_project = with_new_project do |source|
      setup_managed_text_definition("managed_text", ['left', 'right'])
      card_to_copy = create_card! :name => 'copy', :type => 'Card', :managed_text => 'right'
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal 'right', new_card.reload.cp_managed_text

      managed_text = new_card.property_definitions_with_hidden.find{ |p| p.name == "managed_text"}
      assert_equal [['left', 'left'], ['right', 'right']], managed_text.name_values
    end
  end

  def test_copying_should_create_managed_numeric_value_when_it_doesnt_exist_in_target
    target_project = with_new_project do |target|
      setup_numeric_property_definition("managed_numeric", [1, 3])
    end

    new_card = nil
    source_project = with_new_project do |source|
      setup_numeric_property_definition("managed_numeric", [1, 2, 3])
      card_to_copy = create_card! :name => 'copy', :type => 'Card', :managed_numeric => 2
      copier = CardCopier.new(card_to_copy.reload, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal '2', new_card.reload.cp_managed_numeric

      managed_numeric = new_card.property_definitions_with_hidden.find{ |p| p.name == "managed_numeric"}
      assert_equal [['1', '1'], ['2', '2'], ['3', '3']], managed_numeric.name_values
    end
  end

  def test_copy_to_target_project_should_not_copy_locked_properties_when_user_is_not_admin
    locked, unlocked = nil, nil
    target_project = with_new_project do |target|
      locked, unlocked = setup_property_definitions('locked' => ['1', '3'], 'unlocked' => ['1', '3']).sort_by(&:name)
      locked.restricted = true
      locked.save!
    end

    new_card = nil
    source_project = with_new_project do |source|
      setup_property_definitions 'locked' => ['1', '2', '3'], 'unlocked' => ['1', '2', '3']
      card_to_copy = create_card! :name => 'copy', :unlocked => '2', :locked => '2'
      copier = CardCopier.new(card_to_copy, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal ['1', '3'], locked.reload.values.map(&:value)
      assert_equal ['1', '2', '3'], unlocked.reload.values.map(&:value)
      assert_equal nil, new_card.reload.cp_locked
      assert_equal '2', new_card.cp_unlocked
    end
  end

  def test_copy_to_target_project_should_copy_existing_locked_property_value_regardless_if_user_is_admin
    locked = nil
    target_project = with_new_project do |target|
      locked = setup_property_definitions('locked' => ['a']).first
      locked.restricted = true
      locked.save!
    end

    new_card = nil
    source_project = with_new_project do |source|
      setup_property_definitions 'locked' => ['A']
      card_to_copy = create_card! :name => 'copy', :locked => 'A'
      copier = CardCopier.new(card_to_copy, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal 'a', new_card.reload.cp_locked
    end
  end

  def test_copy_to_target_project_should_copy_locked_properties_when_user_is_admin
    locked, unlocked = nil, nil
    target_project = with_new_project do |target|
      target.add_member(User.current, :project_admin)
      locked, unlocked = setup_property_definitions('locked' => ['1', '3'], 'unlocked' => ['1', '3']).sort_by(&:name)
      locked.restricted = true
      locked.save!
    end

    new_card = nil
    source_project = with_new_project do |source|
      setup_property_definitions 'locked' => ['1', '2', '3'], 'unlocked' => ['1', '2', '3']
      card_to_copy = create_card! :name => 'copy', :unlocked => '2', :locked => '2'
      copier = CardCopier.new(card_to_copy, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal ['1', '2', '3'], locked.reload.values.map(&:value)
      assert_equal ['1', '2', '3'], unlocked.reload.values.map(&:value)
      assert_equal '2', new_card.reload.cp_locked
      assert_equal '2', new_card.cp_unlocked
    end
  end

  def test_copy_to_target_project_with_less_precision_should_round_up_and_use_precision_of_existing_values
    target_project = with_new_project do |target|
      target.update_attribute :precision, 0
      setup_numeric_property_definition 'estimate', ['1', '2']
    end

    source_project = with_new_project do |source|
      source.update_attribute :precision, 1
      setup_numeric_property_definition 'estimate', ['1.4', '1.5', '2.5']
      CardCopier.new(create_card!(:name => 'round_down',    :estimate => '1.4'), target_project).copy_to_target_project
      CardCopier.new(create_card!(:name => 'round_up',      :estimate => '1.5'), target_project).copy_to_target_project
      CardCopier.new(create_card!(:name => 'round_and_add', :estimate => '2.5'), target_project).copy_to_target_project
    end

    target_project.with_active_project do |target|
      target.cards.reload
      round_down, round_up, round_and_add = %w{round_down round_up round_and_add}.collect { |card_name| target.cards.find_by_name(card_name) }
      assert_equal '1', round_down.cp_estimate
      assert_equal '2', round_up.cp_estimate
      assert_equal '3', round_and_add.cp_estimate
      assert_equal ['1', '2', '3'], target.find_property_definition('estimate').values.map(&:name)
    end
  end

  def test_copy_to_target_project_with_more_precision_should_use_precision_of_existing_values
    target_project = with_new_project do |target|
      setup_numeric_property_definition 'estimate', ['1.0', '2.0']
      setup_numeric_property_definition 'size',     ['1', '2']
    end

    new_card = nil
    source_project = with_new_project do |source|
      setup_numeric_property_definition 'estimate', ['1', '2']
      setup_numeric_property_definition 'size',     ['1.0', '2.0']
      card_to_copy = create_card! :name => 'copy', :estimate => '1', :size => '2.0'
      copier = CardCopier.new(card_to_copy, target_project)
      new_card = copier.copy_to_target_project
    end

    target_project.with_active_project do |target|
      assert_equal '1.0', new_card.reload.cp_estimate
      assert_equal '2', new_card.cp_size
      assert_equal ['1.0', '2.0'], target.find_property_definition('estimate').values.map(&:name)
      assert_equal ['1', '2'], target.find_property_definition('size').values.map(&:name)
    end
  end

  def test_should_clear_target_project_cache_after_copy
    target_project = ProjectCacheFacade.instance.load_project(create_project.identifier)
    ProjectCacheFacade.instance.cache_project(target_project)

    source_project = with_new_project do |source|
      card_to_copy = create_card! :name => 'copy'
      card_to_copy.tag_with('foo')
      CardCopier.new(card_to_copy, target_project).copy_to_target_project
    end

    target_through_cache = ProjectCacheFacade.instance.load_project(target_project.identifier)
    assert_object_id_not_equal target_project, target_through_cache
  end

end
