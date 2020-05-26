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

class SampleProjectSpecs

  def initialize(spec_dir=nil)
    @spec_dir = spec_dir || File.join(Rails.root, 'config', 'sample_project_specs')
  end

  def process(spec_file)
    User.with_first_admin do
      yaml_file = File.join(@spec_dir, spec_file.to_s)
      ProjectCreator.new.create(YAML.render_file_and_load(yaml_file))
    end
  end

end
