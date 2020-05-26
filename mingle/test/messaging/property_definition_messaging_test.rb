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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

class PropertyDefinitionMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_should_clear_all_changes_related_to_prop_before_destroyed_it
    with_new_project do |project|
      login_as_member
      project.add_member(User.find_by_login('member'))

      setup_property_definitions :status => ['new', 'open', 'close']
      card = create_card!(:name =>'card 1', :status => 'new')
      card.update_attribute :cp_status, 'close'
      
      create_transition project, 'open', :required_properties => {:status => 'new'}, :set_properties => {:status => 'open'}
      create_transition project, 'close', :required_properties => {}, :set_properties => {:status => 'close'}
      
      iteration_cards = project.card_list_views.create_or_update(:view => {:name => 'iteration cards'}, :tagged_with => 'iteration')
      
      project.card_list_views.create_or_update(:view => {:name => 'Status in filter'}, :filters => ['[status][is][new]'])
      project.card_list_views.create_or_update(:view => {:name => 'Status in group by'}, :style => 'grid', :group_by => 'status')
      project.card_list_views.create_or_update(:view => {:name => 'Status in color by'}, :style => 'grid', :color_by => 'status')

      project.create_history_subscription(User.current, HistoryFilterParams.new({'involved_filter_properties' => {'status' => "new"}}).serialize)
      project.create_history_subscription(User.current, HistoryFilterParams.new({'acquired_filter_properties' => {'status' => "open"}}).serialize)
      all_history_subscription = project.create_history_subscription(User.current, HistoryFilterParams.new({}).serialize)
      
      project.reload
      status = project.find_property_definition :status
      status.destroy
      HistoryGeneration.run_once
      project.reload
      
      assert_equal 2, project.events.without_correction.all.sum {|event| event.changes.size} # Name & card_type & comment

      assert_equal 1, project.card_list_views.size
      assert_equal [iteration_cards], project.card_list_views

      assert_equal 0, project.transitions.size

      assert_equal 0, project.property_definitions_with_hidden.size
      assert_equal 0, EnumerationValue.find_all_by_property_definition_id(status.id).size
      assert !Card.column_names.include?(status.column_name)
      assert !Card::Version.column_names.include?(status.column_name)
      
      assert_equal [all_history_subscription], project.history_subscriptions
    end
  end
  
  def xtest_should_add_or_append_a_comment_for_card_version_which_has_a_change_with_the_property_deleted
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'close']
      card = create_card!(:name =>'card 1', :status => 'new')
      card.update_attribute :cp_status, 'close'
      card.update_attributes :comment => 'reopen it', :cp_status => 'open'
      
      status = project.find_property_definition :status
      status.destroy

      project.reload

      card.reload
      
      events = Event.find_all_by_deliverable_id(project.id)
      
      assert_equal 2 + 1 + 1, events.inject(0) {|sum, event| sum += event.changes.size}
      assert_equal 2, card.versions[0].changes.size
      assert_equal "Name", card.versions[0].changes[0].field
      assert_equal "Type", card.versions[0].changes[1].field
      assert_equal 1, card.versions[1].changes.size
      assert_equal "Comment", card.versions[1].changes[0].field
      assert_equal "[Property status was deleted from the project and is no longer reflected in this version.]", card.versions[1].changes[0].new_value
      assert_equal 1, card.versions[2].changes.size
      assert_equal "Comment", card.versions[2].changes[0].field
      assert_equal "reopen it [Property status was deleted from the project and is no longer reflected in this version.]", card.versions[2].changes[0].new_value
    end
  end
  
  def test_udpate_name_does_not_update_changes_in_another_project
    project_1 = with_new_project do |project|
      setup_property_definitions :feeture => ['cards', 'api']
      create_card!(:name =>'story for project 1', :feeture => 'api')
    end  

    project_2 = with_new_project do |project|
      setup_property_definitions :feeture => ['cards', 'api']
      create_card!(:name => 'story for project 2', :feeture => 'api')
    end
    
    project_1.with_active_project do |project|
      misspelled_property = project.find_property_definition('feeture')
      misspelled_property.update_attribute :name, 'feature'
      HistoryGeneration.run_once

      project_1_card = project.cards.find_by_name('story for project 1')
      assert !project_1_card.versions[0].changes.any?{|change| change.field == 'feeture'}          
      assert project_1_card.versions[0].changes.any?{|change| change.field == 'feature'}   
    end  
    
    project_2.with_active_project do |project|
      misspelled_property = project.find_property_definition('feeture')
      misspelled_property.update_attribute :name, 'feature'

      project_2_card = project.cards.find_by_name('story for project 2')
      assert !project_2_card.versions[0].changes.any?{|change| change.field == 'feeture'}          
      assert project_2_card.versions[0].changes.any?{|change| change.field == 'feature'}   
    end  
    # 
    # 
    # project_2.with_active_project do |project|
    #   project_2_card = project.cards.find_by_name('story for project 2')
    #   assert project_2_card.versions[0].changes.any?{|change| change.field == 'feeture'}                 
    #   assert !project_2_card.versions[0].changes.any?{|change| change.field == 'feature'}                 
    # end
  end
  
  def test_update_name_updates_changes
    with_new_project do |project|
      setup_property_definitions :feeture => ['cards', 'api']
      card = create_card!(:name =>'Story number 2', :feeture => 'api')
      feeture = project.find_property_definition('feeture')
      feeture.update_card(card, 'cards')
      card.save!
      card.reload
      HistoryGeneration.run_once
      
      assert card.versions[0].changes.any?{|change| change.field == 'feeture' && change.old_value.nil? && change.new_value == 'api'}
      assert card.versions[1].changes.any?{|change| change.field == 'feeture' && change.old_value == 'api' && change.new_value == 'cards'}  
        
      misspelled_property = project.find_property_definition('feeture')
      misspelled_property.update_attribute :name, 'feature'
      card.reload
      assert !card.versions[0].changes.any?{|change| change.field == 'feeture'}
      assert !card.versions[1].changes.any?{|change| change.field == 'feeture'}
      assert card.versions[0].changes.any?{|change| change.field == 'feature' && change.old_value.nil? && change.new_value == 'api'}
      assert card.versions[1].changes.any?{|change| change.field == 'feature' && change.old_value == 'api' && change.new_value == 'cards'}       
    end
  end
  
  def test_removing_card_types_will_generate_new_versions_of_cards_with_values_that_are_now_not_applicable
    release =  @project.find_property_definition('release')      
    @project.card_types.create(:name => 'story').add_property_definition(release)
    @project.reload
    release.reload
  
    regular_card = @project.cards.create!(:card_type_name => 'card', :name => 'regular_card', :cp_release => '1')
    story_1 = @project.cards.create!(:card_type_name => 'story', :name => 'story 1', :cp_release => '1')
    story_2 = @project.cards.create!(:card_type_name => 'story', :name => 'story 2', :cp_release => nil)
    story_3 = @project.cards.create!(:card_type_name => 'story', :name => 'story 3', :cp_release => '2')
  
    release.card_types = [@project.card_types.first]
    release.save!
          
    HistoryGeneration.run_once
  
    assert_equal '1', regular_card.reload.cp_release
    
    assert_nil story_1.reload.cp_release
    assert_equal 2, story_1.versions.size

    assert_nil story_1.versions.first.comment

    assert_equal 'Property Release is no longer applicable to this card type.', story_1.versions.last.system_generated_comment
    last_version_changes = story_1.versions.last.changes.sort_by {|change| change.field}
    assert_equal 2, last_version_changes.size

    assert_equal 'Release', last_version_changes[0].field
    assert_equal '1', last_version_changes[0].old_value
    assert_equal nil, last_version_changes[0].new_value
    assert_equal 'Property Release is no longer applicable to this card type.', last_version_changes[1].new_value

    assert_nil story_3.reload.cp_release
    assert_equal 2, story_3.versions.size
    assert_nil story_3.versions.last.comment
    assert_equal 'Property Release is no longer applicable to this card type.', story_3.versions.last.system_generated_comment

    last_version_changes = story_3.versions.last.changes.sort_by {|change| change.field}
    assert_equal 'Release', last_version_changes[0].field
    assert_equal '2', last_version_changes[0].old_value
    assert_equal nil, last_version_changes[0].new_value
    assert_equal 'Property Release is no longer applicable to this card type.', last_version_changes[1].new_value      

    assert_nil story_2.reload.cp_release
    assert_equal 1, story_2.versions.size      

  end
end
