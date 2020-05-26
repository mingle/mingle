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

class ConfigurableTemplate
  SPEC_DIR = File.join(Rails.root, 'templates', 'specs')
  IN_PROGRESS_DIR = File.join(Rails.root, 'templates', 'in_progress')

  TEMPLATE_ORDER = {
    'kanban_template' => 1,
    'agile_template' => 2,
    'scrum_template' => 3
  }

  def initialize(template_name, spec_dir=SPEC_DIR)
    @spec_dir = spec_dir
    @template_name = template_name
  end

  def qualified?
    self.class.template_names(@spec_dir).include?(@template_name)
  end

  def copy_into(project, options={})
    template_file = Dir.glob(File.join(@spec_dir, "#{@template_name}.yml")).first
    spec = YAML.render_file_and_load(template_file)
    ProjectCreator.new.merge!(project, spec, options)
  end

  def self.templates(spec_dir=SPEC_DIR)
    template_names(spec_dir).map do |template_name|
      humanized_name = template_name.gsub(/_template/, '').humanize
      OpenStruct.new(:name => humanized_name, :identifier => template_name)
    end
  end

  def self.in_progress_templates
    templates(IN_PROGRESS_DIR)
  end

  def self.in_progress_template(identifier)
    new(identifier, IN_PROGRESS_DIR)
  end

  private
  def self.template_names(spec_dir)
    names = Dir.glob(File.join(spec_dir, '*.yml')).map { |f| File.basename(f, '.yml') }
    names.sort_by {|name| TEMPLATE_ORDER[name] || 99}
  end

end
