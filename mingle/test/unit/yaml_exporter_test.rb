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

class YamlExporterTest < ActiveSupport::TestCase

  def setup
    login_as_bob
    bob = User.find_by_name('bob')

    @test_dir = File.join(Rails.root, "tmp", "yaml_exporter_test")
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
  end

  def test_import_in_progress_projects
    Dir[ConfigurableTemplate::IN_PROGRESS_DIR + '/*.yml'].each do |f|
      spec = YAML.render_file_and_load(f)
      create_project do |new_project|
        ProjectCreator.new.merge!(new_project, spec)
      end
    end
  end

  def test_export
    @project = with_new_project(:name => "sample project", :identifier => "sample_project") do |project|
      project.add_member(User.current)
      type_sprint = project.card_types.create :name => 'sprint', :position => 2, :nature_reorder_disabled => true
      type_story = project.card_types.create :name => 'story', :position => 4, :nature_reorder_disabled => true
      type_task = project.card_types.create :name => 'task', :position => 1, :nature_reorder_disabled => true
      type_defect = project.card_types.create :name => 'defect', :position => 3, :nature_reorder_disabled => true

      status_property = UnitTestDataLoader.create_enumerated_property_definition(project, "status", ['New', 'In Progress', 'Done'], {:card_type => type_story})
      status_property.values.first.update_attribute(:color, '#111111')
      notes_property = UnitTestDataLoader.setup_text_property_definition("notes")
      release_property = UnitTestDataLoader.setup_card_relationship_property_definition("release")
      size_property = setup_numeric_property_definition('size', [1, 2, 3])
      user_prop = setup_user_definition('owner')
      type_defect.add_property_definition user_prop
      project.cards.create!(:name => 'owner_card', :card_type => type_defect, :cp_owner => User.current)

      type_defect.add_property_definition status_property
      type_story.add_property_definition notes_property
      type_story.add_property_definition size_property

      type_story.create_card_defaults_if_missing
      card_defaults = type_story.card_defaults
      card_defaults.update_properties :status => "New"
      card_defaults.update_attributes(:description => 'description')
      card_defaults.save!

      @release_card = create_card!(:name => "release 1", :card_type => type_story)

      create_plv!(project, :name => 'Current Iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => "Iteration 2", :property_definition_ids => [notes_property.id])
      create_plv!(project, :name => 'Current Release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_story, :value => @release_card.id, :property_definition_ids => [release_property.id])

      tree_configuration = project.tree_configurations.create!(:name => 'sprints', :description=> 'Sample tree')

      tree_configuration.update_card_types({
        type_sprint => {:position => 0, :relationship_name => 'Sprint'},
        type_story => {:position => 1, :relationship_name => 'Story'},
        type_task => {:position => 2, :relationship_name => 'Task'}
      })

      task1 = project.cards.create!(:name => 'task1', :card_type => type_task)
      sprint1 = project.cards.create!(:name => 'sprint1', :card_type => type_sprint)
      story1 = project.cards.create!(:name => 'story1', :card_type => type_story)

      tree_configuration.add_child(sprint1)
      tree_configuration.add_child(story1, :to => sprint1)
      tree_configuration.add_child(task1, :to => story1)
      tree_configuration.create_tree

      setup_aggregate_property_definition('velocity', AggregateType::SUM, size_property, tree_configuration.id, type_sprint.id, AggregateScope::ALL_DESCENDANTS)

      story1.update_properties 'status' => 'New'
      story1.save!
    end

    template_file = YamlExporter.export("sample_project", @test_dir)
    spec = YAML.render_file_and_load(template_file)
    assert spec

    ordered_tab_identifiers = @project.ordered_tab_identifiers
    card_type_names = @project.card_types.map(&:name)
    card_type_colors = @project.card_types.map(&:color)

    card_type_props = @project.card_types.map(&:property_definitions).map do |pds|
      pds.map(&:name)
    end
    enum_prop_values = @project.enum_property_definitions_with_hidden.map(&:values)

    create_project do |new_project|
      ProjectCreator.new.merge!(new_project, spec)

      assert_equal card_type_names, new_project.card_types.map(&:name)
      assert_equal card_type_colors, new_project.card_types.map(&:color)

      # card type property definitions
      story = new_project.card_types.find_by_name('story')
      assert_equal ["status", "notes", "size", "Sprint"].sort, story.property_definitions.map(&:name).sort

      # card defaults
      defaults = story.card_defaults
      assert_equal 'description', defaults.description
      assert_equal 1, defaults.actions.size
      assert_equal 'status', defaults.actions.first.property_definition.name
      assert_equal 'New', defaults.actions.first.value

      # enum values
      status = new_project.find_property_definition('status')
      assert_equal ['New', 'In Progress', 'Done'], status.values.map(&:value)
      assert_equal '#111111', status.values.first.color

      # user prop value
      owner_card = new_project.cards.find_by_name('owner_card')
      assert_equal User.current, owner_card.cp_owner

      # plvs
      plvs = new_project.project_variables.sort_by(&:name)
      assert_equal 2, plvs.size
      assert_equal 'Current Iteration', plvs[0].name
      assert_equal 'Iteration 2', plvs[0].value
      assert_equal 'StringType', plvs[0].data_type
      assert_equal ['notes'], plvs[0].property_definitions.map(&:name)

      assert_equal 'Current Release', plvs[1].name
      assert_equal 'release 1', new_project.cards.find_by_id(plvs[1].value).name
      assert_equal 'CardType', plvs[1].data_type
      assert_equal 'story', plvs[1].card_type.name
      assert_equal ['release'], plvs[1].property_definitions.map(&:name)

      #tree
      assert_equal 1, new_project.tree_configurations.size
      tc = new_project.tree_configurations.first
      assert_equal ['sprint', 'story', 'task'], tc.relationship_map.card_types.map(&:name)
      assert_equal ['Sprint', 'Story'], tc.relationships.map(&:name)

      #cards
      story1 = new_project.cards.find_by_name('story1')
      assert_equal 'story', story1.card_type_name
      assert_equal 'New', story1.cp_status
      assert_equal 'sprint1', story1.cp_sprint.name
    end
  end

  def test_export_import_overview_page
    @project = with_new_project(:name => "sample project", :identifier => "sample_project") do |project|
      project.pages.create!(:name => 'Overview Page',
                            :content => 'This is the overview page')
    end

    template_file = YamlExporter.export("sample_project", @test_dir)
    spec = YAML.render_file_and_load(template_file)

    create_project do |new_project|
      ProjectCreator.new.merge!(new_project, spec)
      assert_equal 'This is the overview page', new_project.overview_page.content
    end
  end

  def test_export_import_card_description
    @project = with_new_project(:name => "sample project", :identifier => "sample_project") do |project|
      project.cards.create!(:name => "card name", :description => 'card desc', :card_type_name => 'Card')
    end

    template_file = YamlExporter.export("sample_project", @test_dir)
    spec = YAML.render_file_and_load(template_file)

    create_project do |new_project|
      ProjectCreator.new.merge!(new_project, spec)
      assert_equal 'card desc', new_project.cards.first.description
    end
  end

  def test_export_import_favorites_and_tabs
    @project = with_new_project(:name => "sample project", :identifier => "sample_project") do |project|
      project.add_member(User.current)
      type_sprint = project.card_types.create :name => 'sprint', :position => 2, :nature_reorder_disabled => true
      type_story = project.card_types.create :name => 'story', :position => 4, :nature_reorder_disabled => true

      status_property = UnitTestDataLoader.create_enumerated_property_definition(project, "status", ['New', 'In Progress', 'Done'], {:card_type => type_story})

      sprint1 = project.cards.create!(:name => 'sprint1', :card_type => type_sprint)

      view = CardListView.find_or_construct(project, {:name => 'story list', :style => :grid, :group_by => "status", :lanes => "#{sprint1.number}", :filters => ["[Type][is][story]"], :color_by => 'status' })
      view.save!

      @tab = CardListView.find_or_construct(project, {:name => 'task board', :style => :grid, :group_by => "status", :lanes => "#{sprint1.number}", :filters => ["[Type][is][story]"], :color_by => 'status' })
      @tab.tab_view = true
      @tab.save!

      project.ordered_tab_identifiers = ["All", @tab.favorite.id.to_s, "History"]
      project.save!
    end

    template_file = YamlExporter.export("sample_project", @test_dir)
    spec = YAML.render_file_and_load(template_file)
    assert spec

    ordered_tab_identifiers = @project.ordered_tab_identifiers

    create_project do |new_project|
      ProjectCreator.new.merge!(new_project, spec)

      #tab order
      assert_equal 3, new_project.ordered_tab_identifiers.size
      assert_equal 'All', new_project.ordered_tab_identifiers[0]
      assert_equal 'task board', new_project.tabs.find_by_id(new_project.ordered_tab_identifiers[1]).favorited.name
      assert_equal 'History', new_project.ordered_tab_identifiers[2]

      #favorites
      assert_equal 1, new_project.favorites.size
      view = new_project.favorites.first.favorited
      assert_equal 'story list', view.name
      assert_equal 'grid', view.style.to_s
      assert_equal ['[Type][is][story]'], view.to_params[:filters]
      assert_equal 'status', view.color_by
      assert_equal 'status', view.group_lanes.lane_property_definition.name

      #tabs
      assert_equal 1, new_project.tabs.size
      tab_view = new_project.tabs.first.favorited
      assert_equal 'task board', tab_view.name
      assert_equal 'grid', view.style.to_s
      assert_equal ['[Type][is][story]'], view.to_params[:filters]
      assert_equal 'status', view.color_by
      assert_equal 'status', view.group_lanes.lane_property_definition.name
    end
  end

  def test_card_type_properties_order
    @project = with_new_project(:name => "proj1", :identifier => "proj1") do |project|
      dev = setup_user_definition('dev')
      id = setup_text_property_definition('id')
      release = setup_numeric_property_definition 'Release', ['1', '2']
      type = project.card_types.first
      type.property_definitions = [release, dev, id]
    end

    template_file = YamlExporter.export("proj1", @test_dir)
    spec = YAML.render_file_and_load(template_file)

    create_project do |new_project|
      ProjectCreator.new.merge!(new_project, spec)
      type = new_project.card_types.first
      assert_equal ['Release', 'dev', 'id'], type.property_definitions.map(&:name)
    end
  end
end
