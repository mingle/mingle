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
class ProgramDependenciesControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller ProgramDependenciesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member = login_as_member

    @program = create_program
  end

  def test_loading_dependencies_board
    project = with_new_project do |project|
      project.add_member(@member)
      card1 = project.cards.create!(:name => "card 1", :card_type_name => "card")
      card1.raise_dependency(:name => "dependency-name", :desired_end_date => "01/01/2015", :resolving_project_id => project.id).save!
    end
    @program.projects << project

    get :dependencies, :program_id => @program.identifier
    assert_response :success
    assert_select '.dependency-name', {:count => 1, :text => "dependency-name"}
  end

  def test_user_program_dependency_view_is_created_if_did_not_exist_previously
    assert_nil @program.dependency_views.find_by_user_id(User.current)

    get :dependencies, :program_id => @program.identifier

    view = @program.dependency_views.find_by_user_id(User.current)
    assert_not_nil view
  end

  def test_user_dependency_view_params_are_updated
    get :dependencies, :program_id => @program.identifier, :filter => "resolving"
    get :dependencies, :program_id => @program.identifier, :filter => "raising", :unknown => "something"

    view = @program.dependency_views.current
    assert_equal "raising", view.filter
  end

  def test_popup_history_should_render_link_to_version_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      project = with_new_project do |project|
        project.add_member(@member)
        card1 = project.cards.create!(:name => "card 1", :card_type_name => "card")
        card1.raise_dependency(:name => "dependency-name", :desired_end_date => "01/01/2015", :resolving_project_id => project.id).save!
      end
      @program.projects << project
      dependency = @program.dependencies.first
      dependency.description = 'new description'
      dependency.save
      dependency.description = 'description'
      dependency.save
      login_as_admin

      get :popup_history, :id => dependency.id, :program_id => @program.identifier
      assert_response :success
      dependency.versions.reject(&:latest_version?).each do |dependency_version|
        assert @response.body =~ /<a data-dependency-number="#{dependency.number}" data-dependency-popup-url="\/dependencies\/popup_show" data-dependency-version="#{dependency_version.version}" href="javascript:void\(0\)" onclick="\$j\(this\)\.showDependencyPopup\(\);; return false;">Version #{dependency_version.version}<\/a>/
      end
    end
  end

  def test_popup_show_should_render_readonly_dependency_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      project = with_new_project do |project|
        project.add_member(@member)
        card1 = project.cards.create!(:name => "card 1", :card_type_name => "card")
        card1.raise_dependency(:name => "dependency-name", :desired_end_date => "01/01/2015", :resolving_project_id => project.id).save!
      end
      @program.projects << project
      dependency = @program.dependencies.first
      login_as_admin

      get :popup_show, :number => dependency.number, :program_id => @program.identifier
      assert_response :success
      assert_nil @response.body =~ /class="dependency-name view-mode-only"/
      assert_nil @response.body =~ /class="dependency-description-content view-mode-only"/
    end
  end
end
