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

class KanbanTemplateTest < ActiveSupport::TestCase

  def test_kanban_template_should_have_cards
    spec_dir = File.join(Rails.root, 'templates', 'specs')
    template_file = Dir.glob(File.join(spec_dir, 'kanban_template.yml')).first
    spec = YAML.render_file_and_load(template_file)
    cards_in_to_do = spec['cards'].select { |card| card['properties']['status'].eql?('To Do') }
    cards_in_doing = spec['cards'].select { |card| card['properties']['status'].eql?('Doing') }

    assert_equal 2, cards_in_to_do.size
    assert_equal 2, cards_in_doing.size
  end


  def test_kanban_template_should_have_wip_limits
    spec_dir = File.join(Rails.root, 'templates', 'specs')
    template_file = Dir.glob(File.join(spec_dir, 'kanban_template.yml')).first
    spec = YAML.render_file_and_load(template_file)
    kanban_tab = spec['tabs'].first

    assert_equal 2, kanban_tab['wip_limits'].size
    assert_equal 'Count', kanban_tab['wip_limits']['To do']['type']
    assert_equal 2, kanban_tab['wip_limits']['To do']['limit']

    assert_equal 'Count', kanban_tab['wip_limits']['Doing']['type']
    assert_equal 2, kanban_tab['wip_limits']['Doing']['limit']

  end

end
