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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

# This test needs to be run from the console
class DependencyTrackerMacroTest < ActionController::TestCase
  include ::RenderableTestHelper

  def setup
    login_as_admin

    @controller = CardsController.new
    @project = with_new_project do |project|
      setup_property_definitions :status => ['Open', 'Closed']


      dependency = project.card_types.create!(:name => 'Dependency')

      ['dependee', 'depender'].each do |prop|
        prop = setup_numeric_text_property_definition(prop)
        prop.card_types = [dependency]
        prop.save!
        @macro_holder = project.cards.create!(:name => 'macro holder', :card_type_name => 'Card')
      end
    end
    @project.activate
  end

  def test_three_dependency_macros_are_registered
    ["dependency-tracker-card", "dependency-tracker-project", "dependency-tracker-program"].each do |name|
      assert MinglePlugins::Macros.registered?(name)
    end
  end

  def test_card_dependency_macro_renders_correctly
    requires_jruby do
      @macro_holder.update_attributes(:description => <<-STUFF)
      {{
        dependency-tracker-card
          met: Status = Closed
          properties: [Type, Status]
      }}
STUFF
      assert_macro_is_rendered
    end
  end

    def test_project_dependency_macro_renders_correctly
      requires_jruby do
        @macro_holder.update_attributes(:description => <<-STUFF)
        {{
          dependency-tracker-project
            met: Status = Closed
            card-type: [Card]
            properties: [Type, Status]
        }}
  STUFF
        assert_macro_is_rendered
      end
    end

      def test_program_dependency_macro_renders_correctly
        requires_jruby do
          @macro_holder.update_attributes(:description => <<-STUFF)
          {{
            dependency-tracker-program
              met: Status = Closed
              projects: [#{@project.identifier}]
              dependency-project: #{@project.identifier}
          }}
    STUFF
          assert_macro_is_rendered
        end
      end

  private
  def assert_macro_is_rendered
    get :show, :project_id => @project.identifier, :number => @macro_holder.number
    assert_response :success
    assert_select 'div.dt-container'
    assert_select 'div.dt-ui script', :text => /DependencyTracker.init/
  end
end
