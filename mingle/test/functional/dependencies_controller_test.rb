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

class DependenciesControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller DependenciesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @member = login_as_member
    @project = create_project
    @project.activate
    @project.add_member(@member)
    @project.cards.create!(:name => "first card", :card_type_name => "Card")

    @fake_session = {}
  end

  def teardown
    logout_as_nil
  end

  def test_should_be_able_delete_attachment
    dependency = @project.cards.first.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => @project.id)
    dependency.save!
    dependency.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    dependency.save!
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => dependency.id, :file_name => 'sample_attachment.txt', :format => "json"
    assert_response :success
    assert_equal({"file" => "sample_attachment.txt"}, JSON.parse(@response.body))
  end

  def test_resolving_project_member_should_be_able_delete_attachment_on_dependency
    resolving_user = create_user!
    resolving_project = create_project(:users => [resolving_user])

    dependency = nil
    @project.with_active_project do |project|
      dependency = project.cards.first.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => resolving_project.id)
      dependency.save!
    end
    dependency.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    dependency.save!

    login(resolving_user)
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => dependency.id, :file_name => 'sample_attachment.txt', :format => "json"
    assert_response :success
    assert_equal({"file" => "sample_attachment.txt"}, JSON.parse(@response.body))
  end

  def test_can_only_delete_dependency_from_raising_project
    project2 = with_new_project do |project2|
      project2.add_member(@member, MembershipRole[:project_admin])
    end

    dependency = nil

    project1 = with_new_project do |project1|
      project1.add_member(@member)
      card1 = project1.cards.create :name => "first card", :card_type_name => "Card"

      dependency = card1.raise_dependency(:resolving_project_id => project2.id, :desired_end_date => "2015-01-01", :name => "some dependency")
      dependency.save!

      assert_equal 1, project1.raised_dependencies.count
      assert_equal 1, card1.raised_dependencies.count
      assert_equal 1, project2.reload.resolving_dependencies.count
    end

    project2.with_active_project do
      post :delete, {:number => dependency.number, :project_id => project2.identifier}
      assert_response :forbidden

      assert_equal 1, project2.reload.resolving_dependencies.count
    end

    project1.with_active_project do
      assert_equal 1, project1.raised_dependencies.count
      assert_equal 1, project1.cards.first.raised_dependencies.count
    end
  end

  def test_can_get_dependency_name_and_popup_if_member_of_raising_project
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    @project.activate
    dependency = @project.cards.first.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => resolving_project.id)
    dependency.save!

    get :dependency_name, :number => dependency.number, :project_id => @project.identifier
    assert_response :success
    assert_equal dependency.name, @response.body
    get :popup_show, :number => dependency.number, :project_id => @project.identifier
    assert_response :success

    with_new_project do |project|
      other_project_user = create_user!
      project.add_member(other_project_user)
      login other_project_user

      get :dependency_name, :number => dependency.number, :project_id => project.identifier
      assert_response 401
      assert_equal "You do not have access to this resource", @response.body
      get :popup_show, :number => dependency.number, :project_id => project.identifier
      assert_response 401
      assert_equal "You do not have access to this resource", @response.body
    end
  end

  def test_can_get_dependency_name_and_popup_if_member_of_resolving_project
    resolving_team_member = create_user!
    resolving_project = create_project
    resolving_project.with_active_project do |project|
      project.add_member(resolving_team_member)
      login resolving_team_member
    end

    dependency = @project.with_active_project do
      dep = @project.cards.first.raise_dependency(
        :resolving_project_id => resolving_project.id,
        :desired_end_date => "2015-01-01",
        :name => "some dependency"
      )
      dep.save!
      dep
    end

    get :dependency_name, :number => dependency.number, :project_id => resolving_project.identifier
    assert_response :success
    assert_equal dependency.name, @response.body

    get :popup_show, :number => dependency.number, :project_id => resolving_project.identifier
    assert_response :success
  end

  def test_mingle_admin_should_be_able_to_access_dependency_name_and_popup_without_being_member_of_project
    dependency = @project.cards.first.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => @project.id)
    dependency.save!
    login_as_admin

    get :dependency_name, :number => dependency.number, :project_id => @project.identifier
    assert_response :success
    assert_equal dependency.name, @response.body
    get :popup_show, :number => dependency.number, :project_id => @project.identifier
    assert_response :success
  end

  def test_can_get_dependency_name_and_popup_if_member_of_program
    program = create_program
    program_member = create_user!
    program.add_member(program_member)
    login program_member
    dependency = @project.cards.first.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => @project.id)
    dependency.save!

    get :dependency_name, :number => dependency.number, :project_id => @project.identifier
    assert_response 401
    assert_equal "You do not have access to this resource", @response.body
    get :popup_show, :number => dependency.number, :project_id => @project.identifier
    assert_response 401
    assert_equal "You do not have access to this resource", @response.body

    program.assign(@project)

    get :dependency_name, :number => dependency.number, :project_id => @project.identifier
    assert_response :success
    assert_equal dependency.name, @response.body
    get :popup_show, :number => dependency.number, :project_id => @project.identifier
    assert_response :success
  end

  def test_can_get_dependency_name_and_popup_if_raising_project_anonymous_access
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    with_new_project do |project|
      set_anonymous_access_for(project, true)
      card = project.cards.create :name => "first card", :card_type_name => "Card"
      dependency = card.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => resolving_project.id)
      dependency.save!

      get :dependency_name, :number => dependency.number, :project_id => project.identifier
      assert_equal dependency.name, @response.body
      get :popup_show, :number => dependency.number, :project_id => project.identifier
      assert_response :success
    end
  end

  def test_light_users_can_get_dependency_name_and_popup_if_member_of_resolving_project
    resolving_light_team_member = create_user!
    resolving_light_team_member.update_attribute(:light, true)
    resolving_project = create_project
    resolving_project.with_active_project do |project|
      project.add_member(resolving_light_team_member)
      login resolving_light_team_member
    end

    dependency = @project.with_active_project do
      dep = @project.cards.first.raise_dependency(
        :resolving_project_id => resolving_project.id,
        :desired_end_date => "2015-01-01",
        :name => "some dependency"
      )
      dep.save!
      dep
    end

    get :dependency_name, :number => dependency.number, :project_id => resolving_project.identifier
    assert_response :success
    assert_equal dependency.name, @response.body

    get :popup_show, :number => dependency.number, :project_id => resolving_project.identifier
    assert_response :success
  end

  def test_name_not_found_if_dependency_does_not_exist
    get :dependency_name, :number => nil, :project_id => @project.identifier
    assert_equal "Cannot find dependency D", @response.body

    get :dependency_name, :number => 1, :project_id => @project.identifier
    assert_equal "Cannot find dependency D1", @response.body

    get :dependency_name, :project_id => @project.identifier
    assert_equal "Cannot find dependency D", @response.body
  end

  def test_can_delete_dependency
    with_new_project do |project|
      project.add_member(@member, MembershipRole[:project_admin])
      card1 = project.cards.create :name => "first card", :card_type_name => "Card"
      card2 = project.cards.create :name => "second card", :card_type_name => "Card"

      dependency = card1.raise_dependency(:resolving_project_id => project.id, :desired_end_date => "2015-01-01", :name => "some dependency")
      dependency.save!
      dependency.link_resolving_cards([card2])

      assert_equal 1, project.raised_dependencies.count
      assert_equal 1, card1.raised_dependencies.count
      assert_equal 1, card2.dependencies_resolving.count

      post :delete, {:number => dependency.number, :project_id => project.identifier}
      assert_response :success

      assert_equal 0, project.raised_dependencies.count
      assert_equal 0, card1.reload.raised_dependencies.count
      assert_equal 0, card2.reload.dependencies_resolving.count
    end
  end

  def test_should_create_dependency
    assert_equal 0, @project.raised_dependencies.count
    post :create, { :dependency => { :name => "dependency name", :desired_end_date => "2015-01-01", :raising_card_number => @project.cards.first.number, :raising_project_id => @project.id, :resolving_project_id => @project.id }, :project_id => @project.identifier }
    assert_response :success
    assert_equal 1, @project.raised_dependencies.count
  end

  def test_should_not_create_dependency_without_valid_params
    assert_equal 0, @project.raised_dependencies.count
    post :create, { :dependency => {:desired_end_date => "2015-01-01", :raising_card_number => @project.cards.first.number}, :project_id => @project.identifier }
    assert_response 400
    assert_equal 0, @project.raised_dependencies.count
  end

  def test_should_update_resolving_project
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    dep.resolving_project_id = nil;
    dep.save
    assert_nil dep.resolving_project_id
    post :update_resolving_project, { :number => dep.number, :resolving_project_id => @project.id, :project_id => @project.identifier }
    assert_response :success
    assert_equal @project.id, dep.reload.resolving_project_id
  end

  def test_should_not_update_resolving_project_if_it_doesnt_exist
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    post :update_resolving_project, { :number => dep.number, :resolving_project_id => 9999999999, :project_id => @project.identifier }
    assert_response 400
    assert_equal "Project doesn't exist", JSON.parse(@response.body)['message']
  end

  def test_should_return_404_if_dependency_doesnt_exist
    post :update_resolving_project, { :number => 9001, :project_id => @project.identifier }
    assert_response 404
  end

  def test_should_update_dependency
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    desired_end_date = Date.parse('2015-12-13')
    post :update, { :id => dep.id, :desired_end_date => desired_end_date.strftime(DateTimeConstants::ISO_DATE_FORMAT), :project_id => @project.identifier }
    assert_response :success
    dep.reload
    assert_equal desired_end_date, dep.desired_end_date.to_date
  end

  def test_should_validate_date_param_on_update
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    post :update, { :id => dep.id, :desired_end_date => "1", :project_id => @project.identifier }
    assert_response :unprocessable_entity
  end

  def test_should_prevent_resolving_team_member_from_editing_desired_end_date
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    dep = nil
    @project.with_active_project do |project|
      dep = project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
      dep.save!
    end

    resolving_team_member = create_user!
    resolving_project.add_member(resolving_team_member)
    login resolving_team_member

    post :update, { :id => dep.id, :desired_end_date => "2005-10-03", :project_id => resolving_project.identifier }
    assert_response 401
  end

  def test_should_allow_raising_team_member_or_mingle_admin_to_edit_desired_end_date
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    dep = nil
    @project.activate
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
    dep.save!
    desired_end_date =  Date.parse("2005-10-3")
    post :update, { :id => dep.id, :desired_end_date => desired_end_date.strftime(DateTimeConstants::ISO_DATE_FORMAT), :project_id => @project.identifier }
    assert_response :success
    dep.reload
    assert_equal desired_end_date, dep.desired_end_date.to_date

    login_as_admin
    desired_end_date = Date.parse("2005-10-2")
    post :update, { :id => dep.id, :desired_end_date => desired_end_date.strftime(DateTimeConstants::ISO_DATE_FORMAT), :project_id => @project.identifier }
    assert_response :success
    dep.reload
    assert_equal desired_end_date, dep.desired_end_date.to_date
  end

  def test_update_dependency_name_and_description
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    @project.with_active_project do |proj|
      dep = @project.cards.first.raise_dependency( :name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
      dep.save!
      post :update, { :id => dep.id, :dependency => { :name => 'new name', :description => 'new desc' }, :project_id => @project.identifier }
      assert_response :success
      dep.reload
      assert_equal 'new name', dep.name
      assert_equal 'new desc', dep.description
    end
  end

  def test_update_dependency_name_and_description_handles_error_input
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    @project.with_active_project do |proj|
      dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
      dep.save!
      post :update, { :id => dep.id, :dependency => { :description => 'new desc' }, :project_id => @project.identifier }
      assert_response 422
      dep.reload
      assert_equal 'dependency thing', dep.name
    end
  end

  def test_should_sanitize_dependency_description_when_render_it
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    @project.with_active_project do |proj|
      dep = @project.cards.first.raise_dependency(:name => "dependency thing", :description => "hello <script>alert(1)</script>", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
      dep.save!
      get :popup_show, :number => dep.number, :project_id => proj.identifier
      assert_response :ok
      assert_no_match /hello <script>alert/, unescape_unicode(@response.body)
    end
  end

  def test_should_response_with_sanitized_dependency_description_after_updated_successfully
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    @project.with_active_project do |proj|
      dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
      dep.save!
      post :update, { :id => dep.id, :dependency => { :name => 'new name', :description => 'hello <script>alert</script>' }, :project_id => @project.identifier }
      assert_response :success
      data = JSON.parse(@response.body)
      assert_equal 'hello', data['description'].strip
    end
  end

  def test_should_respond_with_macros_not_supported_in_dependencies
    resolving_project = Project.create(:identifier => "a_resolving_project", :name => "Resolving project")
    @project.with_active_project do |proj|
      dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :description => "{{table query: SELECT number}}", :desired_end_date => "2015-01-01", :resolving_project_id => resolving_project.id)
      dep.save!
      get :popup_show, { :number => dep.number, :project_id => @project.identifier  }
      assert_response :success
      assert_include 'Macros are not supported in Dependencies', @response.body
    end
  end

  def test_index_should_include_only_dependencies_resolved_by_this_project
    another_project = Project.create(:name => "another project", :identifier => "another_project")
    raising_card = another_project.cards.create(:name => "raising card", :card_type_name => "card")
    @project.activate
    @project.cards.first.raise_dependency(:name => "raising dependency", :desired_end_date => "2015-01-01", :resolving_project_id => another_project.id).save!
    @project.resolving_dependencies.create(:name => "resolving dependency", :desired_end_date => "2015-01-01", :raising_card_number => raising_card.number, :raising_project_id => another_project.id, :resolving_project_id => @project.id)
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_match /resolving dependency/, @response.body
    assert_no_match /raising dependency/, @response.body
  end

  def test_planning_a_dependency
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    card1 = @project.cards.create!(:name => "foo", :card_type_name => "card")
    card2 = @project.cards.create!(:name => "foo", :card_type_name => "card")
    post :link_cards, :project_id => @project.identifier, :dependency => { :number => dep.number, :cards => [card1.number, card2.number] }

    assert_response 200
    dep.reload
    assert_equal 2, dep.dependency_resolving_cards.length
  end

  def test_planning_a_dependency_not_allowed_if_raising_card_linked
    raising_card = @project.cards.first
    dep = raising_card.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    card1 = @project.cards.create!(:name => "foo", :card_type_name => "card")
    post :link_cards, :project_id => @project.identifier, :dependency => { :number => dep.number, :cards => [card1.number, raising_card.number] }

    assert_response :unprocessable_entity
    assert_equal 0, dep.reload.dependency_resolving_cards.length
  end

  def test_link_cards_popup_can_take_already_linked_cards
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    card1 = @project.cards.create!(:name => "foo", :card_type_name => "card")
    dep.link_resolving_cards([card1])

    res = post :link_cards_popup, :project_id => @project.identifier, :number => dep.number

    assert_response 200
    assert_include "foo", res.body
  end

  def test_resolving_a_dependency
    with_new_project do |project|
      project.add_member(@member)
      card1 = project.cards.create!(:name => "card 1", :card_type_name => "card")
      card2 = project.cards.create!(:name => "card 2", :card_type_name => "card")
      card3 = project.cards.create!(:name => "card 3", :card_type_name => "card")

      dep = card1.raise_dependency(:name => "dependency", :desired_end_date => "2015-01-01", :resolving_project_id => project.id)
      dep.save!
      dep.link_resolving_cards([card2, card3])

      assert_equal Dependency::ACCEPTED, dep.reload.status

      res = post :toggle_resolved, :project_id => project.identifier, :dependency => {:number => dep.number}
      assert_response :success
      assert_include "lightbox_contents", res.body
      assert_include "dependencies_table", res.body

      assert_equal Dependency::RESOLVED, dep.reload.status
    end
  end

  def test_change_dependency_from_resolved_to_accepted
    raising_card = @project.cards.first
    card1 = @project.cards.create!(:name => "card 2", :card_type_name => "card")

    dep = raising_card.raise_dependency(:name => "dependency", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    dep.link_resolving_cards([card1])
    dep.toggle_resolved_status

    post :toggle_resolved, :project_id => @project.identifier, :dependency => {:number => dep.number}
    assert_response :success
    assert_equal Dependency::ACCEPTED, dep.reload.status
  end

  def test_change_dependency_from_resolved_to_new_if_mark_unresolved_and_resolving_card_has_been_deleted
    raising_card = @project.cards.first
    card1 = @project.cards.create!(:name => "card 2", :card_type_name => "card")

    dep = raising_card.raise_dependency(:name => "dependency", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    dep.link_resolving_cards([card1])
    dep.toggle_resolved_status
    card1.destroy

    assert_equal Dependency::RESOLVED, dep.reload.status

    post :toggle_resolved, :project_id => @project.identifier, :dependency => {:number => dep.number}
    assert_response :success
    assert_equal Dependency::NEW, dep.reload.status
  end

  def test_user_is_allowed_to_edit_dependency_property
    assert_equal true, @controller.send(:allowed_to_edit, @project)
    login create_user!
    assert_equal false, @controller.send(:allowed_to_edit, @project)
  end

  def test_user_dependency_prefs_are_created_if_did_not_exist_previously
    assert_nil @project.dependency_views.find_by_user_id(User.current)

    get :index, :project_id => @project.identifier, :filter => "resolving"

    view = @project.dependency_views.find_by_user_id(User.current)
    assert_not_nil view
    assert_equal "resolving", view.filter
  end

  def test_user_dependency_prefs_are_updated
    get :index, :project_id => @project.identifier, :filter => "resolving"
    get :index, :project_id => @project.identifier, :filter => "raising", :unknown => "something", :dir => "desc"

    view = @project.dependency_views.current
    assert_equal "raising", view.filter
    assert_equal "desc", view.dir
  end

  def test_anonymous_users_can_view_dependencies_tab
    change_license_to_allow_anonymous_access
    logout_as_nil

    with_new_project do |project|
      @project = project

      set_anonymous_access_for(project, true)

      get :index, :project_id => project.identifier
      assert_select '.dependencies-tab a', {:text => "Dependencies"}, "Anonymous user is unable to see the dependencies tab in the header"
      assert_select 'table#dependencies', true, "Anonymous user is unable to view the list of dependencies"
    end

  ensure
    set_anonymous_access_for(@project, false)
    @project.destroy
    reset_license
  end

  def test_should_unlink_a_resolving_card
    dep = @project.cards.first.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!

    card1 = @project.cards.create!(:name => "foo", :card_type_name => "card")
    card2 = @project.cards.create!(:name => "foo", :card_type_name => "card")

    dep.link_resolving_cards([card1, card2])

    post :unlink_card_popup, { :dependency => { :number => dep.number, :card_number => card1.number }, :project_id => @project.identifier }
    assert_response :success
    assert_include "lightbox_contents", @response.body
    assert_include "dependencies_table", @response.body
    assert_equal Dependency::ACCEPTED, dep.reload.status
    assert_equal 1, dep.reload.resolving_cards.length

    res = JSON.parse(@response.body)
    assert_equal 1, res['resolving_cards_statuses'].length
    assert_nil res['resolving_cards_statuses'][card1.number.to_s]

    res = post :unlink_card_popup, { :dependency => { :number => dep.number, :card_number => card2.number }, :project_id => @project.identifier }
    assert_response :success
    assert_equal Dependency::NEW, dep.reload.status
    assert_equal 0, dep.reload.resolving_cards.length
  end

  def test_popup_shows_version_information
    raising_card = @project.cards.first
    dep = raising_card.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    dep.update_attribute(:desired_end_date, "2016-02-02")

    get :popup_show, { :number => dep.number, :version => 1, :project_id => @project.identifier }
    assert_include "old-version-note", @response.body

    dep.update_attribute(:status, "RESOLVED")
    get :popup_show, { :number => dep.number, :version => 3, :project_id => @project.identifier }
    assert_include "Resolved", @response.body

    get :popup_show, { :number => dep.number, :version => 2, :project_id => @project.identifier }
    assert_include "New", @response.body
  end

  def test_popup_shows_latest_if_incorrect_or_latest_version_specified
    raising_card = @project.cards.first
    dep = raising_card.raise_dependency(:name => "dependency thing", :desired_end_date => "2015-01-01", :resolving_project_id => @project.id)
    dep.save!
    dep.update_attribute(:desired_end_date, "2016-02-02")
    get :popup_show, { :number => dep.number, :version => 4, :project_id => @project.identifier  }
    assert_not_include "old-version-note", @response.body

    get :popup_show, { :number => dep.number, :version => 2, :project_id => @project.identifier  }
    assert_not_include "old-version-note", @response.body

    get :popup_show, { :number => dep.number, :project_id => @project.identifier  }
    assert_not_include "old-version-note", @response.body
  end

  def test_popup_show_should_render_readonly_dependency_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      dependency = @project.cards.first.raise_dependency(:desired_end_date => "2015-01-01", :name => "some dependency", :resolving_project_id => @project.id)
      dependency.save!
      login_as_admin

      get :popup_show, :number => dependency.number, :project_id => @project.identifier
      assert_response :success
      assert_nil @response.body =~ /class="dependency-name view-mode-only"/
      assert_nil @response.body =~ /class="dependency-description-content view-mode-only"/
    end
  end

  def test_popup_history_should_render_link_to_version_when_readonly_mode_is_toggled_on
    MingleConfiguration.overridden_to(readonly_mode: true) do
      project = with_new_project do |project|
        project.add_member(@member)
        card1 = project.cards.create!(:name => "card 1", :card_type_name => "card")
        card1.raise_dependency(:name => "dependency-name", :desired_end_date => "01/01/2015", :resolving_project_id => project.id).save!
      end
      dependency = project.dependencies.first
      dependency.description = 'new description'
      dependency.save
      dependency.description = 'description'
      dependency.save
      login_as_admin

      get :popup_history, :id => dependency.id, :project_id => project.identifier
      assert_response :success
      dependency.versions.reject(&:latest_version?).each do |dependency_version|
        assert @response.body =~ /<a data-dependency-number="#{dependency.number}" data-dependency-popup-url="\/projects\/#{project.identifier}\/dependencies\/popup_show" data-dependency-version="#{dependency_version.version}" href="javascript:void\(0\)" onclick="\$j\(this\)\.showDependencyPopup\(\);; return false;">Version #{dependency_version.version}<\/a>/
      end
    end
  end

end
