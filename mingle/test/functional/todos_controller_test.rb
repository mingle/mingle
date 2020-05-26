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

require File.expand_path("../unit_test_helper", File.dirname(__FILE__))

class TodosControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller(TodosController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    Todo.destroy_all
    @member = login_as_member
  end

  def test_bulk_delete
    with_new_project do |project|
      project.add_member(@member)
      project.reload

      todos = %w(one two three).map do |content|
        @member.todos.create :content => content
      end

      xhr :delete, :bulk_delete, :user_id => @member.id, :format => "json", :ids => todos.map(&:id)[0..1].map(&:to_s)
      assert_response :success

      assert_equal ["three"], @member.todos.map(&:content)
    end
  end

  def test_sort
    with_new_project do |project|
      project.add_member(@member)
      project.reload

      todos = %w(one two three).map do |content|
        @member.todos.create :content => content
      end

      assert_equal ["one", "two", "three"], @member.todos.ranked.map(&:content)

      order = @member.todos.ranked.map(&:id).reverse

      xhr :post, :sort, :user_id => @member.id, :format => "json", :todos => order
      assert_response :success

      assert_equal ["three", "two", "one"], @member.todos.ranked.map(&:content)
    end
  end
end
