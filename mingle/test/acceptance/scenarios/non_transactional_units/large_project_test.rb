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

require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

# Tags: non-transactional-units
class LargeProjectDataTest < ActionController::TestCase
  include TreeFixtures::PlanningTree

  fixtures :users, :login_access

  def setup
    login_as_admin
  end

  #bug 8811
  def test_should_be_able_to_bulk_delete_more_than_1000_cards
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    with_new_project do |project|
      last = nil

      for_oracle do
        1001.times do |index|
          last = create_card!(:name => "card#{index}", :card_type_name => 'Card')
        end
      end

      post :bulk_destroy, :project_id => project.identifier, :all_cards_selected => 'true'
      assert_response :redirect
    end
  end

  # bug minglezy/#360
  def test_should_be_able_to_delete_tree_with_more_than_1000_cards
    for_oracle do
      with_new_project do |project|
        configuration = project.tree_configurations.create!(:name => 'Planning')
        unrelated_configuration = project.tree_configurations.create!(:name => 'Zorro')
        init_three_level_tree(configuration)
        init_three_level_tree(unrelated_configuration)
        1001.times do |index|
          card = create_card!(:name => "card#{index}", :card_type_name => 'story')
          configuration.add_child(card)
          unrelated_configuration.add_child(card)
        end

        configuration.destroy
        assert_false TreeConfiguration.exists?(configuration.id)
        assert TreeConfiguration.exists?(unrelated_configuration.id)
        assert_equal 0, TreeBelonging.count(:conditions => ['tree_configuration_id = ?', configuration.id])
        assert TreeBelonging.count(:conditions => ['tree_configuration_id = ?', unrelated_configuration.id]) >= 1001
      end
    end
  end

  def test_delete_more_than_1000_attachements
    for_oracle do
      with_new_project do |project|
        card = create_card!(:name => 'card for testing update attachments')
        1001.times do
          card.attach_files(sample_attachment)
        end
        project.destroy
        assert Attachment.find_all_by_project_id(project.id).empty?
      end
    end
  end


  def test_can_compute_aggregates_for_more_than_1000_cards
    for_oracle do
      with_1000_card_project do |project|
        tree_config = project.tree_configurations.first
        assert_nothing_raised do
          tree_config.compute_aggregates_for_unique_ancestors(CardIdCriteria.new("IN (#{CardQuery.parse("Type is story").to_card_id_sql})"))
        end
      end
    end
  end

  private


  def with_1000_card_project
    with_new_project do |project|
      project.generate_secret_key!
      project.add_member(User.find_by_login('member'))
      project.add_member(User.find_by_login('proj_admin'), :project_admin)

      size = UnitTestDataLoader.setup_numeric_property_definition("size", [1, 2, 3, 4])

      type_iteration = Project.current.card_types.create :name => 'iteration'
      type_story = Project.current.card_types.create :name => 'story'

      configuration = project.tree_configurations.create(:name => '1000 cards tree')

      configuration.update_card_types({
        type_iteration => {:position => 0, :relationship_name => "iteration"},
        type_story => {:position => 1}
      })

      1001.times do |index|
        iteration = configuration.add_child(project.cards.create!(:name => "iteration #{index}", :card_type => type_iteration), :to => :root)
        configuration.add_child(project.cards.create!(:name => "story #{index}", :card_type => type_story), :to => iteration)
      end
      options = { :name => 'Sum of size',
                  :aggregate_scope => type_story,
                  :aggregate_type => AggregateType::SUM,
                  :aggregate_card_type_id => type_iteration.id,
                  :tree_configuration_id => configuration.id,
                  :target_property_definition => size.reload
                }
      sum_of_size = project.all_property_definitions.create_aggregate_property_definition(options)
      project.reload.update_card_schema
      sum_of_size.update_cards
      project.reset_card_number_sequence
      yield project
    end
  end



end
