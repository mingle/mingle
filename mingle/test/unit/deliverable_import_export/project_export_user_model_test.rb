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

class ProjectExportUserModelTest < ActiveSupport::TestCase
  
  def setup
    @project = create_project
    @project.activate
    @project.add_member User.find_by_login('member')
    login_as_member
    create_card! :name => 'first card', :card_type_name => 'Card'
  end

  def test_export_project_should_not_include_non_project_members
    non_project_member = create_user!(:name => 'non_project_member')
    export_file = create_project_exporter!(@project, non_project_member).export
    non_project_member.destroy

    create_project_importer!(User.current, export_file).process!
    assert_nil User.find_by_name('non_project_member')
  end

  def test_export_project_should_only_include_members_belongs_to_the_project
    another_project_user = create_user!(:name => 'another_project_user')
    with_new_project do |project|
      project.add_member(another_project_user)
    end
    export_file = create_project_exporter!(@project, another_project_user).export
    another_project_user.destroy_without_callbacks

    create_project_importer!(User.current, export_file).process!
    assert_nil User.find_by_name(another_project_user.name)
  end

  def test_export_project_should_include_user_in_project_history
    login_as_admin
    history_project_user = create_user!
    @project.add_member(history_project_user)

    login history_project_user.email
    card = @project.cards.first
    assert card.update_attribute(:name, "updated by #{history_project_user.name}")
    
    login_as_admin
    @project.remove_member(history_project_user)

    #load import export user ext
    ImportExport
    assert_include history_project_user.name, User.find_by_sql([User.select_by_project_sql, @project.id]).collect(&:name)

    export_file = create_project_exporter!(@project, history_project_user).export
    history_project_user.destroy

    create_project_importer!(User.current, export_file).process!
    assert User.find_by_name(history_project_user.name)
  end

  def test_select_by_project_sql_of_user_model_should_include_users_in_project_history_of_card_versions
    assert_export_user_should_include_users_in_project_history do |user|
      card = @project.cards.first
      assert card.update_attribute(:name, "updated by #{user.name}")
      login_as_member
      card.update_attribute(:name, 'updated by member')
    end
  end
  
  def test_select_by_project_sql_of_user_model_should_include_users_in_project_history_of_page_versions
    assert_export_user_should_include_users_in_project_history do |user|
      page = @project.pages.create(:name => 'first page')
      assert page.update_attribute(:content, "updated by #{user.name}")
      login_as_member
      page.update_attribute(:content, 'updated by member')
    end
  end
  
  def test_select_by_project_sql_of_user_model_should_include_users_in_project_history_of_property_values
    assert_export_user_should_include_users_in_project_history do |user|
      setup_user_definition('dev')
      card = @project.cards.first
      card.update_attribute(:cp_dev, user)
      card.update_attribute(:cp_dev, User.find_by_login('member'))
    end
  end
  
  def test_select_by_project_sql_of_user_model_should_not_include_user_in_another_project_pages_history
    should_not_inlucded_user = nil
    with_new_project do |project|
      should_not_inlucded_user = create_user!
      login should_not_inlucded_user.email
      project.pages.create(:name => 'first page')
    end
    #todo: fix project#with_active_project should can always re-activate correct previous project
    #when create new project, update/drop card_schema would trigger project activate without deactivate, so the deactivate of with_new_project would not re-activate the correct previous project
    @project.activate
    login_as_member

    ImportExport
    assert_not_include should_not_inlucded_user.name, User.find_by_sql([User.select_by_project_sql, @project.id]).collect(&:name)
  end
  
  def assert_export_user_should_include_users_in_project_history
    user = create_user!

    login_as_admin
    @project.add_member(user)
    
    login user.email
    yield(user)
    @project.remove_member(user)

    #load import export user ext
    ImportExport
    assert_include user.name, User.find_by_sql([User.select_by_project_sql, @project.id]).collect(&:name)
  end  
end
