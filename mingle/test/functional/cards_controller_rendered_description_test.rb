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

class CardsControllerRenderedDescriptionTest < ActionController::TestCase
  include TreeFixtures::PlanningTree, ::RenderableTestHelper::Functional

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @member = login_as_member
    @project = first_project
    @project.activate
  end

  def test_render_card_description
    card = create_card!(:name => 'my card', :description => "{{\n value \n   query: SELECT count(*) \n }}")
    get :rendered_description, :project_id => @project.identifier, :number => card.number
    assert_response :ok
    assert_equal @project.cards.count.to_s, @response.body.strip
  end

  def test_return_404_if_card_not_found
    assert_raises(ActiveRecord::RecordNotFound) do
      get :rendered_description, :project_id => @project.identifier, :number => -1
    end
  end

  def test_blank_description_if_no_description
    card = create_card!(:name => "new card")
    get :rendered_description, :project_id => @project.identifier, :number => card.number
    assert_response :ok
    assert_equal "(no description)", @response.body.strip
  end
end
