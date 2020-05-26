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

class ConfigurableTemplateTest < ActiveSupport::TestCase

  def setup
    login_as_member
    @test_spec_dir = File.join(Rails.root, 'test', 'data', 'template_specs')
  end

  def test_qualified
    assert ConfigurableTemplate.new('test_template', @test_spec_dir).qualified?
  end

  def test_qualified_for_non_existent_template
    assert_false ConfigurableTemplate.new('not_exists', @test_spec_dir).qualified?
  end

  def test_copy_into_updates_the_project_with_template_contents
    project = create_project :name => "to be merged"
    project.reload.with_active_project do
      assert_equal 0, project.cards.size
    end

    specs = ConfigurableTemplate.new('test_template', @test_spec_dir)
    specs.copy_into(project)

    project.reload.with_active_project do
      assert_equal 1, project.cards.size
    end
  end

  def test_copy_into_evaluates_any_erb_code_in_template
    project = create_project

    spec = {
      :card_types => [{:name => 'Story'}],
      :cards => [{
        :name => 'evaluated card',
        :description => '<%= 2+2 %> makes 4',
        :card_type_name => 'Story'
      }]
    }

    template_file = File.join(@test_spec_dir, 'evaluated_template.yml')
    begin
    File.open(template_file, 'w') do |f|
      YAML.dump(spec, f)
    end
    specs = ConfigurableTemplate.new('evaluated_template', @test_spec_dir)
      specs.copy_into(project)
    ensure
      FileUtils.rm_f(template_file)
    end

    project.reload.with_active_project do
      assert_equal 1, project.cards.size
      assert_equal "4 makes 4", project.cards.first.description
    end
  end

  def test_copy_into_honors_the_choice_to_not_include_pages_and_cards
    project = create_project

    spec = {
      :card_types => [{:name => 'Story'}],
      :cards => [{
        :name => 'evaluated card',
        :card_type_name => 'Story'
                 }],
      :pages => [{ :name => 'Overview Page',
                 :content => 'hello there'}]
    }

    template_file = File.join(@test_spec_dir, 'evaluated_template.yml')
    begin
    File.open(template_file, 'w') do |f|
      YAML.dump(spec, f)
    end
      specs = ConfigurableTemplate.new('evaluated_template', @test_spec_dir)
      options = { :include_cards => false, :include_pages => false}
      specs.copy_into(project, options)
    ensure
      FileUtils.rm_f(template_file)
    end

    project.reload.with_active_project do
      assert_equal 0, project.cards.size
      assert_equal 0, project.pages.size
    end

  end

  def test_templates_gives_all_templates_in_spec_dir
    template_name = 'holiday_party'
    spec = {
      :project => { :name => template_name, :identifier => template_name },
      :card_types => [{:name => 'finger food'}]
    }

    template_file = File.join(@test_spec_dir, "#{template_name}.yml")
    begin
      File.open(template_file, 'w') do |f|
        YAML.dump(spec, f)
      end
      assert_include template_name, ConfigurableTemplate.templates(@test_spec_dir).map(&:identifier)
    ensure
      FileUtils.rm_f(template_file)
    end
  end

  def test_templates_gives_all_templates_in_spec_dir_in_order_of_kanban_agile_scrum_and_others
    template_names = ['agile_template', 'scrum_template', 'kanban_template']

    begin
      template_names.each do |template_name|
        template_file = File.join(@test_spec_dir, "#{template_name}.yml")
        File.open(template_file, 'w') do |f|
          YAML.dump({}, f)
        end
      end
      assert_equal ['kanban_template', 'agile_template', 'scrum_template', 'test_template'], ConfigurableTemplate.templates(@test_spec_dir).map(&:identifier)

    ensure
      template_names.each do |template_name|
        template_file = File.join(@test_spec_dir, "#{template_name}.yml")
        FileUtils.rm_f(template_file)
      end
    end
  end

  def test_templates_gives_all_template_names_in_humanized_form
    template_name = 'holiday_party'
    spec = {
      :project => { :name => template_name, :identifier => template_name },
      :card_types => [{:name => 'finger food'}]
    }

    template_file = File.join(@test_spec_dir, "#{template_name}_template.yml")
    begin
      File.open(template_file, 'w') do |f|
        YAML.dump(spec, f)
      end

      assert_include "#{template_name}_template", ConfigurableTemplate.templates(@test_spec_dir).map(&:identifier)
      assert_include "Holiday party", ConfigurableTemplate.templates(@test_spec_dir).map(&:name)
    ensure
      FileUtils.rm_f(template_file)
    end
  end
end
