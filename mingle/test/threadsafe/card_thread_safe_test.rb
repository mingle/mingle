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

class CardThreadSafeTest < ActiveSupport::TestCase

  def test_project_cards_association
    login_as_admin
    with_new_project do |project|
      create_card!(:name => 'card 1')
      assert_equal 1, project.cards.size
    end
    with_new_project do |project|
      assert_equal 0, project.cards.size
    end
  end
  def test_project_card_versions_association
    login_as_admin
    with_new_project do |project|
      create_card!(:name => 'card 1')
      assert_equal 1, project.card_versions.size
    end
    with_new_project do |project|
      assert_equal 0, project.card_versions.size
    end
  end
  def test_card_versions_association
    login_as_admin
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      create_card!(:name => 'card 2')
      assert_equal 1, card1.versions.size
    end
    with_new_project do |project|
      card3 = create_card!(:name => 'card 3')
      assert_equal 1, card3.versions.size
    end
  end

  def test_card_validations
    login_as_admin
    with_new_project do |project|
      validate_callbacks_size = Card.validate_callback_chain.size
      card1 = create_card!(:name => 'card 1')
      card2 = create_card!(:name => 'card 2')
      assert_equal validate_callbacks_size, Card.validate_callback_chain.size
    end
  end

  def test_card_and_card_version_table_names
    login_as_admin
    with_new_project do |project|
      assert_card_and_card_version_table_names project
    end
    with_first_project do |project|
      assert_card_and_card_version_table_names project
    end
  end

  def test_kind_of_card
    login_as_admin
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      assert card1.kind_of?(Card)
      assert !card1.kind_of?(Card::Version)

      assert card1.versions.first.kind_of?(Card::Version)
    end
  end

  def test_is_a_card
    login_as_admin
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      assert card1.is_a?(Card)
      assert !card1.is_a?(Card::Version)

      assert card1.versions.first.is_a?(Card::Version)
    end
  end

  def test_instance_of_card
    login_as_admin
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      assert card1.instance_of?(Card)
      assert !card1.instance_of?(Card::Version)

      assert card1.versions.first.instance_of?(Card::Version)
    end
  end

  pending 'we do not define card class as constant anymore'
  def test_class_name_and_to_s
    login_as_admin
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      assert_equal 'Card', card1.class.name
      assert_equal 'Card', card1.class.to_s
      assert_equal '', card1.class.real_name
      
      version_class = card1.versions.first.class
      assert_equal 'Card::Version', version_class.name
      assert_equal 'Card::Version', version_class.to_s
      assert_equal '', version_class.real_name
    end
  end

  def test_tag_card
    login_as_admin
    with_new_project do |project|
      card1 = create_card!(:name => 'card 1')
      card1.tag_with("tagname")
      card1.save
      tag = card1.reload.tags.first
      assert_equal 2, tag.taggings.size
      taggables = tag.taggings.collect(&:taggable).sort_by {|t| t.class.name}
      assert taggables.first.instance_of?(Card)
      assert taggables.last.instance_of?(Card::Version)
    end
  end

  class CardObserver < ActiveRecord::Observer
    observe Card
    attr_accessor :notifications
    def after_create(model)
      @notifications ||= []
      @notifications << model.name
    end
  end

  def test_observe_card_events
    login_as_admin
    with_new_project do |project|
      CardObserver.instance
      create_card!(:name => 'card 1')
      assert_equal ['card 1'], CardObserver.instance.notifications
    end
  end

  def test_update_project_identifier
    login_as_admin
    with_new_project do |project|
      project.identifier = "#{project.identifier}abc123"
      project.save!
      create_card!(:name => 'card 1')
    end
  end

  def test_find_card_in_thread
    queue = Queue.new
    thread1 = start_thread do
      login_as_admin
      with_new_project do |project|
        3.times { |index| create_card!(:name => "card 1#{index}") }
        queue << project.cards.size
      end
    end
    thread2 = start_thread do
      login_as_admin
      with_new_project do |project|
        4.times { |index| create_card!(:name => "card 2#{index}") }
        queue << project.cards.size
      end
    end
    thread1.join
    thread2.join

    first = queue.pop
    second = queue.pop
    
    assert_equal 3+4, first + second
  end

  pending "this test will cause build hanging, seems db connection is not released after thread run finished"
  def test_multi_threads_creating_three_level_project
    # this number should be less than connection pool size
    # if it's same with connection pool size, this test will fail on jruby & cruby
    # I guess it's because every thread will checkout one connection and never release until quit
    # same reason will cause this test hang on when other tests start some threads
    # TODO: we need figure out a way to release connection when thread ends, so that every test
    #       has full connections in pool
    count = 3
    queue = Queue.new
    threads = []
    count.times do |index|
      threads << start_thread do
        Thread.current['index'] = index
        login_as_admin
        with_new_project(:prefix => "project#{index}") do |project|
          ThreeLevelProject.new(project).build
          index.times {|i| create_card!(:name => "card index#{index}") }
          queue << project.cards.size
        end
      end
    end
    threads.each(&:join)
    result = 0
    count.times { result += queue.pop }
    assert_equal count * 5 + 0 + 1 + 2, result
  end

  def assert_card_and_card_version_table_names(project)
    assert_equal project.cards_table, Card.table_name
    assert_equal project.card_versions_table, Card.versioned_table_name
    assert_equal project.card_versions_table, Card::Version.table_name
  end

  class ThreeLevelProject
    include TreeFixtures::PlanningTree
    def initialize(project)
      @project = project
    end
    def build
      @project.add_member(User.find_by_login('member'))
      @project.add_member(User.find_by_login('proj_admin'), :project_admin)

      @configuration = @project.tree_configurations.create(:name => 'three level tree')
      init_planning_tree_types
      init_three_level_tree(@configuration)

      @type_story = @project.card_types.find_by_name("story")
      @type_iteration = @project.card_types.find_by_name("iteration")

      UnitTestDataLoader.setup_card_relationship_property_definition('related card')
      UnitTestDataLoader.setup_property_definitions :status => ['open', 'closed']
      @project.reload
      @project.find_property_definition('status').card_types = [@type_iteration, @type_story]
      @project.find_property_definition('related card').card_types = [@type_story]

      UnitTestDataLoader.setup_numeric_property_definition("size", [1, 2, 3, 4])
      UnitTestDataLoader.setup_user_definition("owner")
      @project.reload
      size = @project.find_property_definition('size')
      owner = @project.find_property_definition('owner')
      @type_story.reload.add_property_definition(size)
      @type_story.reload.add_property_definition(owner)

      @project.cards.find_by_name("story1").update_attribute(:cp_size, 1)
      @project.cards.find_by_name("story2").update_attribute(:cp_size, 3)

      options = { :name => 'Sum of size',
                  :aggregate_scope => @type_story,
                  :aggregate_type => AggregateType::SUM,
                  :aggregate_card_type_id => @type_iteration.id,
                  :tree_configuration_id => @configuration.id,
                  :target_property_definition => size.reload
                }                                                 
      @sum_of_size = @project.all_property_definitions.create_aggregate_property_definition(options)
      @project.reload.update_card_schema
      @sum_of_size.update_cards
      @project.reset_card_number_sequence
    rescue => e
      puts e.message
      puts e.backtrace.join("\n")
      raise
    end
  end

  def start_thread(&block)
    Thread.start do
      begin
        block.call
      ensure
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end
end
