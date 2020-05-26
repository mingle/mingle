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

module CardTreeAcceptanceSupport

  PRIORITY = 'riority'
  STATUS = 'status'
  SIZE = 'size'
  ITERATION = 'iteration'
  OWNER = 'Zowner'

  RELEASE = 'Release'
  ITERATION_TYPE = 'Iteration'
  STORY = 'Story'
  DEFECT = 'Defect'
  TASK = 'Task'
  CARD = 'Card'

  NOTSET = '(not set)'
  ANY = '(any)'
  TYPE = 'Type'
  NEW = 'new'
  OPEN = 'open'
  CLOSED = 'closed'
  LOW = 'low'

  PLANNING = 'Planning'
  NONE = 'None'
  BLANK = ''

  RELATION_PLANNING_RELEASE = 'Planning tree - release'
  RELATION_PLANNING_ITERATION = 'Planning tree - iteration'
  RELATION_PLANNING_STORY = 'Planning tree - story'

  def reset_filter_when_no_card_found
    click_link("Reset filter")
    wait_for_tree_result_load
  end

# fills @tree with one branch: release_card -> iteration_card -> story_card; creates these cards and returns them in an array
  def fill_one_branch_tree
    release_card = create_card!(:name => 'release 1', :card_type => @type_release)
    iteration_card = create_card!(:name => 'iteration 1', :card_type => @type_iteration)
    story_card = create_card!(:name => 'story 1', :card_type => @type_story)

    add_card_to_tree(@tree, release_card)
    add_card_to_tree(@tree, iteration_card, release_card)
    add_card_to_tree(@tree, story_card, iteration_card)

    [release_card, iteration_card, story_card]
  end

  def get_planning_tree_generated_with_cards_on_tree
    add_card_to_tree(@tree, @r1)
    add_card_to_tree(@tree, @i1, @r1)
    add_card_to_tree(@tree, @stories, @i1)
    add_card_to_tree(@tree, @tasks, @stories[1])
  end

  def assert_cards_are_linked_to_its_parent_card(card, type)
    open_card(@project, card)
    assert_property_set_to_card_on_card_show(RELATION_PLANNING_ITERATION, @i1)
  end

end
