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

class BlockingTest < ActiveSupport::TestCase

  def teardown
    logout_as_nil
  end

  def test_description_why
    target = OpenStruct.new(:name => 'some target')
    assert_equal "is used in #{'some target'.bold}", Deletion::Blocking.new(target).description
  end

  def test_description_should_be_html_safe_with_user_entered_values_escaped
    target = OpenStruct.new(:name => '<i>target</i>')
    description = Deletion::Blocking.new(target).description
    assert description.html_safe?
    assert_equal "is used in #{'&lt;i&gt;target&lt;/i&gt;'.bold}", description
  end

  def test_description_why_with_used_as
    target = OpenStruct.new(:name => 'some target')
    assert_equal "is used as a component property of #{'some target'.bold}", Deletion::Blocking.new(target, :used_as => "a component property").description
  end

  def test_description_why_with_used_as
    target = OpenStruct.new(:name => 'some favorite')
    assert_equal "is used in favorite #{'some favorite'.bold}", Deletion::Blocking.new(target, :used_in => "favorite").description
  end

  def test_render_with_link_name
    with_new_project do |project|
      target = setup_formula_property_definition('Const Size', "3 * 3")
      assert_equal "is used in favorite #{'Const Size'.bold}. To manage #{'Const Size'.bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{target.id}\" target=\"blocking\">team favorites &amp; tabs management page</a>.", Deletion::Blocking.new(target, :used_in => 'favorite', :link_name => 'team favorites & tabs management').render(view_helper)
    end
  end

  def test_render_returns_html_safe_output_with_user_entered_values_escaped
    with_new_project do |project|
      target = setup_formula_property_definition('<i>target</i>', "3 * 3")
      rendered_message = Deletion::Blocking.new(target, :used_in => 'favorite', :link_name => 'team favorites & tabs management').render(view_helper)
      assert_equal "is used in favorite #{'&lt;i&gt;target&lt;/i&gt;'.bold}. To manage #{'&lt;i&gt;target&lt;/i&gt;'.bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{target.id}\" target=\"blocking\">team favorites &amp; tabs management page</a>.", rendered_message
      assert rendered_message.html_safe?
    end
  end

  def test_formula_property_fixing_link_point_to_its_edit_page
    with_new_project do |project|
      const_size = setup_formula_property_definition('Const Size', "3 * 3")
      assert_equal "is used as a component property of #{'Const Size'.bold}. To manage #{'Const Size'.bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{const_size.id}\" target=\"blocking\">this page</a>.",
                   Deletion::Blocking.new(const_size, :used_as => 'a component property').render(view_helper)
    end
  end

  def test_tabs_and_favorites_fixing_link_point_to_its_list_page
    with_first_project do |project|
      cp_status = project.find_property_definition('status')
      view_params = { :name => 'favorite timmy tab', :columns => 'status' }
      view = CardListView.find_or_construct(project, view_params)
      view.save!
      assert_equal "is used in tab #{'favorite timmy tab'.bold}. To manage #{'favorite timmy tab'.bold}, please go to <a href=\"/projects/#{project.identifier}/favorites/list?id=#{view.id}\" target=\"blocking\">this page</a>.",
                    Deletion::Blocking.new(view, :used_in => 'tab').render(view_helper)
      view.tab_view = true
      view.save!
      assert_equal "is used in tab #{'favorite timmy tab'.bold}. To manage #{'favorite timmy tab'.bold}, please go to <a href=\"/projects/#{project.identifier}/favorites/list?id=#{view.id}\" target=\"blocking\">this page</a>.",
                    Deletion::Blocking.new(view, :used_in => 'tab').render(view_helper)
    end
  end

  def test_personal_favorites_should_not_block_property_definition_deletion
    login_as_member
    with_first_project do |project|
      cp_status = project.find_property_definition('status')
      view_params = { :name => 'favorite timmy', :columns => 'status', :user_id => User.current.id }
      view = CardListView.find_or_construct(project, view_params)
      view.save!
      assert_false Deletion.new(cp_status).blocked?
    end
  end

  def test_user_property_fixing_link_point_to_its_edit_page
    with_new_project do |project|
      owner = setup_user_definition('owner')
      assert_equal "is used in #{'owner'.bold}. To manage #{'owner'.bold}, please go to <a href=\"/projects/#{project.identifier}/property_definitions/edit/#{owner.id}\" target=\"blocking\">this page</a>.", Deletion::Blocking.new(owner).render(view_helper)
    end
  end
end
