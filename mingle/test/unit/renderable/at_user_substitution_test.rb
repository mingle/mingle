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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class AtUserSubstitutionTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    @substitution = Renderable::AtUserSubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
  end

  def test_substitute_user_profile_link_when_matching_at_user_login
    member = User.find_by_login('member')
    assert_match /hello <a[^>]*>@member<\/a> world/, @substitution.apply("hello @member world")
  end

  def test_substitute_group_link_when_matching_at_group_name
    group = @project.groups.create!(:name => 'devs')

    assert_match /hello <a href="\/projects\/first_project\/groups\/#{group.id}"[^>]*>@devs<\/a> world/, @substitution.apply("hello @devs world")
  end

  def test_substitute_team_link_when_matching_at_team
    group = @project.groups.create!(:name => 'devs')
    assert_match /hello <a href="\/projects\/first_project\/team"[^>]*>@team<\/a> world/, @substitution.apply("hello @team world")
  end

  def test_do_nothing_for_at_random_stuff
    group = @project.groups.create!(:name => 'devs')
    assert_equal "hello @world", @substitution.apply("hello @world")
  end
end
