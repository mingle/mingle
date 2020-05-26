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

class SampleProjectSpecsTest < ActiveSupport::TestCase
  def test_creates_project_from_a_spec_file
    sample_project_specs = SampleProjectSpecs.new(File.join(Rails.root, 'test', 'data', 'sample_project_specs'))

    sample_project_specs.process('sample_project.yml')

    sample_project = Project.find_by_identifier('sample_project')

    assert sample_project

    sample_project.with_active_project do |project|
      assert card = project.cards.first
      assert_equal 'Story', card.card_type_name
      assert_equal 'New', card.cp_status
    end
  end

  def test_can_use_erb_tags_in_spec_and_card_without_property
    Clock.fake_now(:year => 2007, :month => 1, :day => 1)
    sample_project_specs = SampleProjectSpecs.new(File.join(Rails.root, 'test', 'data', 'sample_project_specs'))

    sample_project_specs.process('sample_with_erb.yml')

    sample_with_erb = Project.find_by_identifier('sample_with_erb')
    assert sample_with_erb
    sample_with_erb.with_active_project do |project|
      assert card = project.cards.first
      assert_equal 'Story', card.card_type_name
      assert_match /#{Clock.now.strftime('%Y-%M-%d')}/, card.description
    end
  end

end
