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

class CardExportTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include TreeFixtures::FeatureTree

  def setup
    @project = first_project
    @project.activate
    login_as_admin
    @excel_content_file = SwapDir::CardImportingPreview.file(@project)
    @raw_excel_content_file_path = @excel_content_file.pathname
  end

  def teardown
    File.delete(@excel_content_file.pathname) if File.exist?(@excel_content_file.pathname)
  end

  def test_export_tab_separated_cards
    last_user = @project.users.last
    first_card = @project.cards.find_by_number(1)
    another_card = @project.cards.find_by_number(4)
    first_card.tag_with([]).save!
    first_card.update_attributes(:cp_status => 'open', :cp_old_type => 'bug', :cp_dev => last_user)

    another_card.tag_with([]).save!
    another_card.update_attributes(:cp_status => 'closed', :cp_old_type => 'story')

    expected_export = <<-EXPORT
Number,Name,Description,Type,Assigned,Custom property,dev,id,Iteration,Material,old_type,Priority,Property without values,Release,Some property,Stage,start date,Status,Unused,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,,,,,,story,,,,,,,closed,,#{another_card.created_by.login},#{another_card.modified_by.login},"",""
1,first card,this is the first card,Card,,,#{last_user.login},,,,bug,,,,,,,open,,#{first_card.created_by.login},#{first_card.modified_by.login},"",""
    EXPORT
      assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'list'))
  end

  def test_export_converts_to_html_before_export
    with_new_project do |project|
      last_user = @project.users.last
      card = @project.cards.create!(:name => 'old unmigrated card', :description => "# one\n# two", :card_type_name => 'Card')
      card.update_attribute :redcloth, true
      expected_export = <<-EXPORT
Number,Name,Description,Type,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
#{card.number},old unmigrated card,"<ol>\n <li>one</li>\n  <li>two</li>\n </ol>",Card,#{card.created_by.login},#{card.created_by.login},"",""
      EXPORT

        assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'list'))
    end
  end

  def test_should_escape_quoted_text_multiline_content_with_double_quotes
    first_card = @project.cards.find_by_number(1)
    another_card = @project.cards.find_by_number(4)

    first_card.update_attributes(:description => %{this description
has "quoted"
stuff})

    expected_export = <<-EXPORT
Number,Name,Description,Type,Assigned,Custom property,dev,id,Iteration,Material,old_type,Priority,Property without values,Release,Some property,Stage,start date,Status,Unused,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,,,,,,,,,,,,,,,#{another_card.created_by.login},#{another_card.modified_by.login},another_tag,"",""
1,first card,"this description
has ""quoted""
stuff",Card,,,,,,,,,,,,,,,,#{first_card.created_by.login},#{first_card.modified_by.login},first_tag,"",""
    EXPORT
      assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'list'))
  end

  def test_should_export_dates_in_project_format
    first_card = @project.cards.find_by_number(1)
    first_card.tag_with([])
    first_card.update_attributes(:cp_start_date => '2007-02-01')

    another_card = @project.cards.find_by_number(4)
    another_card.tag_with([])
    another_card.update_attributes(:cp_start_date => '2007-04-03')
    @project.update_attributes(:date_format => '%d/%m/%Y')

    expected_export = <<-EXPORT
Number,Name,Description,Type,Assigned,Custom property,dev,id,Iteration,Material,old_type,Priority,Property without values,Release,Some property,Stage,start date,Status,Unused,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
4,another card,another card is good,Card,,,,,,,,,,,,,03/04/2007,,,#{another_card.created_by.login},#{another_card.modified_by.login},"",""
1,first card,this is the first card,Card,,,,,,,,,,,,,01/02/2007,,,#{first_card.created_by.login},#{first_card.modified_by.login},"",""
    EXPORT
      assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'list'))
  end

  def test_export_tab_separated_cards_only_includes_relevant_properties
    story = @project.card_types.create!(:name => 'story')
    story.property_definitions = ['release', 'iteration'].collect{|pd_name| @project.find_property_definition(pd_name)}
    bug = @project.card_types.create!(:name => 'bug')
    bug.property_definitions = ['assigned'].collect{|pd_name| @project.find_property_definition(pd_name)}
    @project.reload

    story_foo = @project.cards.create!(:card_type_name => 'story', :name => 'foo', :number => 1000, :cp_release => '1', :cp_iteration => '2')
    story_bar = @project.cards.create!(:card_type_name => 'story', :name => 'bar', :number => 1001, :cp_release => '2', :cp_iteration => '3')

    view = CardListView.construct_from_params(@project, :filters => ['[type][is][story]'])
    expected_export = <<-EXPORT
Number,Name,Description,Type,Iteration,Release,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1001,bar,,story,3,2,#{story_foo.created_by.login},#{story_foo.modified_by.login},"",""
1000,foo,,story,2,1,#{story_bar.created_by.login},#{story_bar.modified_by.login},"",""
    EXPORT
      assert_equal expected_export, export(view)

    bug_card = @project.cards.create!(:card_type_name => 'bug', :name => 'buggin out', :number => 1002, :cp_assigned => 'jen')
    view = CardListView.construct_from_params(@project, :filters => %w([type][is][story] [type][is][bug]))
    expected_export = <<-EXPORT
Number,Name,Description,Type,Assigned,Iteration,Release,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1002,buggin out,,bug,jen,,,#{bug_card.created_by.login},#{bug_card.modified_by.login},"",""
1001,bar,,story,,3,2,#{story_foo.created_by.login},#{story_foo.modified_by.login},"",""
1000,foo,,story,,2,1,#{story_bar.created_by.login},#{story_bar.modified_by.login},"",""
    EXPORT
      assert_equal expected_export, export(view)
  end

  def test_export_cards_only_includes_visible_columns
    @project.cards.each { |c| c.tag_with([]) }
    first_card = @project.cards.find_by_number(1)
    last_card = @project.cards.find_by_number(4)
    view = CardListView.construct_from_params(@project, :columns => ['Type', 'Status'])
    expected_export = <<-EXPORT
Number,Name,Type,Status
#{last_card.number},#{last_card.name},Card,
#{first_card.number},#{first_card.name},Card,
    EXPORT
    assert_equal expected_export, export(view, false, false)
  end

  def test_should_not_export_card_description_when_description_is_not_included
    story = @project.card_types.create!(:name => 'story')
    story.property_definitions = ['release', 'iteration'].collect{|pd_name| @project.find_property_definition(pd_name)}
    story_foo = @project.cards.create!(:card_type_name => 'story', :name => 'foo', :number => 1000, :cp_release => '1', :cp_iteration => '2')
    story_bar = @project.cards.create!(:card_type_name => 'story', :name => 'bar', :number => 1001, :cp_release => '2', :cp_iteration => '3')
    view = CardListView.construct_from_params(@project, :filters => ['[type][is][story]'])
    expected_export_without_description = <<-EXPORT
Number,Name,Type,Iteration,Release,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1001,bar,story,,,#{story_foo.created_by.login},#{story_foo.modified_by.login},"",""
1000,foo,story,,,#{story_bar.created_by.login},#{story_bar.modified_by.login},"",""
    EXPORT
      assert_equal expected_export_without_description, export(view, nil)
      assert_equal expected_export_without_description, export(view, false)

    expected_export_with_description = <<-EXPORT
Number,Name,Description,Type,Iteration,Release,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1001,bar,,story,,,#{story_foo.created_by.login},#{story_foo.modified_by.login},"",""
1000,foo,,story,,,#{story_bar.created_by.login},#{story_bar.modified_by.login},"",""
    EXPORT
      assert_equal expected_export_with_description, export(view, true)
  end

  #todo: this dose not work well with mysql so I change it use new project, but obviously we need clean up this testcase
  # WPC 2008-03-31
  def test_new_lines_can_be_round_tripped
    with_new_project do |project|
      UnitTestDataLoader.setup_property_definitions(
        :Status => ['fixed', 'new', 'open', 'closed','in progress'],
        :Iteration => ['1', '2'],
        :'Custom property' => %w(old_value some_new_value),
        :old_type => %w(bug story foo),
        :'Some property' => ['first value'],
        :Priority => %w(low medium high),
        :'Property without values' => [],
        :Assigned => ['jen'],
        :Material => %w(sand wood gold),
        :Stage => ['25'],
        :Unused => ['value']
      )

      UnitTestDataLoader.setup_user_definition('dev')
      UnitTestDataLoader.setup_text_property_definition('id')
      UnitTestDataLoader.setup_numeric_property_definition 'Release', %w(1 2)

      UnitTestDataLoader.setup_date_property_definition('start date')
      first_card = project.cards.create!(:number => 1, :name => 'first card', :description => 'this is the first card', :card_type => project.card_types.first)
      first_card.tag_with('first_tag').save!

      another_card = project.cards.create!(:number => 4, :name => 'another card', :description => 'another card is good', :card_type => project.card_types.first)
      another_card.tag_with('another_tag').save!

      first_card.description = "this is one line\nthis is another"
      first_card.save!

      view = CardListView.construct_from_params(project, {:style => 'list', :columns => %w(Number Name Description)})

      expected_export = <<-EXPORT
Number,Name,Description
4,another card,another card is good
1,first card,"this is one line\nthis is another"
      EXPORT
      assert_equal expected_export, export(view, true, false)
      first_card.update_attributes(:description => '')
      export_content = project.export_csv_cards(view, true, false)
      tabbed_content = expected_export.gsub(',', "\t")
      write_content(tabbed_content)
      importer = create_card_importer!(project, @raw_excel_content_file_path)
      importer.import_cards
      assert_equal "this is one line\nthis is another", project.reload.cards.find_by_number(1).description
    end
  end

  def test_should_only_export_cards_in_current_view_if_specified
    first_card = @project.cards.find_by_number(1)
    first_card.cp_status = 'open'
    first_card.cp_old_type = 'bug'
    first_card.save!

    view = CardListView.construct_from_params(@project, :filters => %w([status][is][open] [old_type][is][bug]))
    expected_export = <<-EXPORT
Number,Name
1,first card
    EXPORT
    assert_equal expected_export, export(view, false, false)
  end

  def test_should_export_all_cards_in_view
    count_of_all_cards_in_view = PAGINATION_PER_PAGE_SIZE + 5
    (1..count_of_all_cards_in_view).each { |counter| create_card!(:name => "Card #{counter}", :status => 'open', :old_type => 'bug')}

    view = CardListView.construct_from_params(@project, :filters => %w([status][is][open] [old_type][is][bug]))
    number_of_exported_cards = export(view).split("\n").size - 1 #exclude header line

    assert_equal PAGINATION_PER_PAGE_SIZE, view.cards.size
    assert_equal count_of_all_cards_in_view,  number_of_exported_cards
  end

  def test_should_obey_card_list_view_sort_order_on_export
    (1..30).each { |counter| create_card!(:name => "Card #{counter}", :status => 'open', :old_type => 'bug')}

    view = CardListView.construct_from_params(@project, :filters => %w([status][is][open] [old_type][is][bug]), :sort => 'number', :order => 'ASC')
    rows = export(view).split("\n")[1..-1]
    card_numbers = rows.collect { |row| row.split(',').first.to_i }
    assert_equal card_numbers, card_numbers.sort

    view = CardListView.construct_from_params(@project, :filters => %w([status][is][open] [old_type][is][bug]), :sort => 'number', :order => 'DESC')
    rows = export(view).split("\n")[1..-1]
    card_numbers = rows.collect { |row| row.split(',').first.to_i }
    assert_equal card_numbers, card_numbers.sort.reverse
  end

  def test_export_tree_should_export_tree_relationship_property_value_using_number_and_name_and_having_card_tree_column
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      expected_export = <<-EXPORT
Number,Name,Description,Type,Planning,Planning release,Planning iteration,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
5,story2,,story,yes,#1 release1,#2 iteration1,#{User.current.login},#{User.current.login},"",""
4,story1,,story,yes,#1 release1,#2 iteration1,#{User.current.login},#{User.current.login},"",""
3,iteration2,,iteration,yes,#1 release1,,#{User.current.login},#{User.current.login},"",""
2,iteration1,,iteration,yes,#1 release1,,#{User.current.login},#{User.current.login},"",""
1,release1,,release,yes,,,#{User.current.login},#{User.current.login},"",""
      EXPORT
        assert_equal expected_export, export(CardListView.construct_from_params(project, :style => 'list'))
    end
  end


  def test_export_cards_should_export_all_tree_relationship_columns
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_cofiguration = project.tree_configurations.create!(:name => 'Planning tree')
      tree_cofiguration.update_card_types({
        type_release => {:position => 0, :relationship_name => 'Planning release'},
        type_iteration => {:position => 1, :relationship_name => 'Planning iteration'},
        type_story => {:position => 2, :relationship_name => 'Planning story'}
      })
      card = create_card!(:name => 'I am a card')
      expected_export = <<-EXPORT
Number,Name,Description,Type,Planning tree,Planning release,Planning iteration,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
#{card.number},I am a card,,Card,no,,,#{card.created_by.login},#{card.modified_by.login},"",""
      EXPORT
        assert_equal expected_export, export(CardListView.construct_from_params(project, :style => 'list'))
    end
  end

  def test_should_always_export_all_columns_on_grid_view
    expected_export = <<-EXPORT
Number,Name,Description,Type,Assigned,Custom property,dev,id,Iteration,Material,old_type,Priority,Property without values,Release,Some property,Stage,start date,Status,Unused,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
1,first card,this is the first card,Card,,,,,,,,,,,,,,,,member,member,first_tag,"",""
4,another card,another card is good,Card,,,,,,,,,,,,,,,,member,member,another_tag,"",""
    EXPORT
      assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'grid'), true, false)
      assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'grid'), true, true)
  end

  def test_should_always_export_all_columns_on_tree_view
    expected_export = <<-EXPORT
Number,Name,Description,Type,owner,related card,size,status,three level tree,Planning release,Planning iteration,Sum of size,Created by,Modified by,Incomplete Checklist Items,Completed Checklist Items
1,release1,,release,,,,,yes,,,,member,member,"",""
2,iteration1,,iteration,,,,,yes,#1 release1,,,member,member,"",""
4,story1,,story,,,1,,yes,#1 release1,#2 iteration1,,member,member,"",""
5,story2,,story,,,3,,yes,#1 release1,#2 iteration1,,member,member,"",""
3,iteration2,,iteration,,,,,yes,#1 release1,,,member,member,"",""
    EXPORT
    with_three_level_tree_project do |project|
        assert_equal expected_export, export(CardListView.construct_from_params(project, :style => 'tree', :tree_name => project.tree_configurations.first.name), true, false)
    end
  end

  def test_should_export_checklist_items_when_toggled_on
    first_card = @project.cards.first
    first_card.checklist_items.build(:text => 'item1', :position => 1).save!
    first_card.checklist_items.build(:text => 'item2', :completed => true, :position => 1).save!
    first_card.checklist_items.build(:text => 'item3', :position => 2).save!
    first_card.checklist_items.build(:text => 'item5', :completed => true, :position => 2).save!
    expected_export = <<-EXPORT
Number,Name,Description,Type,Assigned,Custom property,dev,id,Iteration,Material,old_type,Priority,Property without values,Release,Some property,Stage,start date,Status,Unused,Created by,Modified by,Tags,Incomplete Checklist Items,Completed Checklist Items
1,first card,this is the first card,Card,,,,,,,,,,,,,,,,member,member,first_tag,"item1\ritem3","item2\ritem5"
4,another card,another card is good,Card,,,,,,,,,,,,,,,,member,member,another_tag,"",""
    EXPORT
      assert_equal expected_export, export(CardListView.construct_from_params(@project, :style => 'grid'), true, false)
  end

  def test_should_export_aggregate_properties_in_order
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      size = setup_numeric_property_definition('size', [2, 4, 6, 8])
      type_story.add_property_definition(size)
      setup_aggregate_property_definition('sum size', AggregateType::SUM, size, configuration.id, type_release.id, type_iteration)
      setup_aggregate_property_definition('count', AggregateType::COUNT, nil, configuration.id, type_release.id, type_iteration)

      export_data = export(CardListView.construct_from_params(project, :style => 'list'))
      headers = export_data.lines.first.split(',')
      columns_of_interest = -7..-5
      assert_equal ['Planning iteration', 'count', 'sum size'], headers[columns_of_interest]
    end
  end

  def test_export_multiple_tree_should_fill_all_tree_name_into_card_trees_column
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      feature_tree = create_three_level_feature_tree
      story1 = project.cards.find_by_name('story1')
      reporting_feature = project.cards.find_by_name('reporting')
      feature_tree.add_child(story1, :to => reporting_feature)


      lines = export(CardListView.construct_from_params(project, :style => 'list')).split("\n").map{|line| line.split(',')}
      headers = lines.shift
      story1_line = lines.detect{ |line| line.first == story1.number.to_s }

      assert story1_line
      columns_of_interest = -10..-5
      assert_equal ['yes', '#1 release1', '#2 iteration1', 'yes', '#6 CRM', '#10 reporting'], story1_line[columns_of_interest]
      assert_equal ['Planning', 'Planning release', 'Planning iteration', 'System breakdown', 'System breakdown module', 'System breakdown feature'], headers[columns_of_interest]
    end
  end

  private
  def export(view = nil, include_description = true, include_all_columns = true)
    Project.current.reload
    CardExport.new(Project.current, view).export(include_description, include_all_columns)
  end

  def write_content(content)
    @excel_content_file.write(content)
  end

end
