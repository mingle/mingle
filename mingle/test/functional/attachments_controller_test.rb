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

class AttachmentsControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller AttachmentsController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
    @project = first_project
    @project.activate
  end

  def test_creates_unique_filenames_within_project
    login_as_admin
    with_new_project do |project|
      card = project.cards.create!(:name => "duplicate attachment name", :card_type_name => "Card")

      file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")

      2.times do
        xhr :post, :create, :project_id => project.identifier, :upload => file_to_upload, :attachable => { :type => 'card', :id => card.id }
      end

      filenames = card.reload.attachments.map(&:file_name).sort
      assert_equal 2, filenames.size
      assert_equal filenames.size, filenames.uniq.size
      assert_equal "icon.png", filenames.last
      assert (/icon-[\w]{6}\.png/.match(filenames.first))
    end
  end

  def test_creates_attachments_on_dependencies
    login_as_admin
    with_new_project do |project|
      card = project.cards.create!(:name => "first card", :card_type_name => "Card")
      dependency = card.raise_dependency(:name => "has attachment", :desired_end_date => "01/01/2015", :resolving_project_id => project.id)
      dependency.save!

      file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
      xhr :post, :create, :project_id => project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => dependency.id }

      attachments = dependency.reload.attachments.map(&:file_name).sort
      assert_equal 1, attachments.size
      assert_equal "icon.png", attachments.first
    end
  end

  def test_resolving_project_member_can_access_attachments_by_raising_project_on_dependency
      card = @project.cards.create!(:name => "first card", :card_type_name => "Card")
      resolving_user = create_user!
      resolving_project = create_project(:users => [resolving_user])

      dependency = card.raise_dependency(:name => "has attachment", :desired_end_date => "01/01/2015", :resolving_project_id => resolving_project.id)
      dependency.save!
      file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
      xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => dependency.id }
      attachment = dependency.reload.attachments.last

      login(resolving_user)
      get :show, :id => attachment.id, :project_id => @project.identifier
      assert_response :redirect
      assert_include file_to_upload.original_filename, @response.redirected_to
  end

  def test_resolving_project_member_can_create_attachments_on_raising_project_dependency
      card = @project.cards.create!(:name => "first card", :card_type_name => "Card")
      resolving_user = create_user!
      resolving_project = create_project(:users => [resolving_user])

      dependency = card.raise_dependency(:name => "has attachment", :desired_end_date => "01/01/2015", :resolving_project_id => resolving_project.id)
      dependency.save!


      login(resolving_user)
      file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
      xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => dependency.id }

      assert_response :success
  end

  def test_third_project_member_cannot_create_attachments_on_dependencies_between_raising_and_resolving_project
    resolving_project = @project
    unauthorized_user = create_user!
    raising_project = create_project()
    third_project = create_project(:users => [unauthorized_user])

    raising_card = nil
    raising_project.with_active_project do |raising_project|
      raising_card = raising_project.cards.create!(:name => "first card", :card_type_name => "Card")
    end

    raising_and_resolving_project_dependency = raising_card.raise_dependency(:name => "dep", :desired_end_date => "11/01/2015", :resolving_project_id => resolving_project.id)
    raising_and_resolving_project_dependency.save!

    login(unauthorized_user)
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")

    assert_raise ErrorHandler::UserAccessAuthorizationError do
      xhr :post, :create, :project_id => raising_project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => raising_and_resolving_project_dependency.id }
    end
  end

  def test_anon_users_cannot_create_attachments_on_dependencies_when_raising_or_resolving_projects_anon_enabled
    anonymous_user = User.anonymous
    change_license_to_allow_anonymous_access

    resolving_project = @project
    raising_project = create_project
    set_anonymous_access_for(resolving_project, true)

    raising_card = nil
    raising_project.with_active_project do |raising_project|
      raising_card = raising_project.cards.create!(:name => "first card", :card_type_name => "Card")
    end

    raising_and_resolving_project_dependency = raising_card.raise_dependency(:name => "dep", :desired_end_date => "11/01/2015", :resolving_project_id => resolving_project.id)
    raising_and_resolving_project_dependency.save!

    logout_as_nil
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")

    assert_raise ErrorHandler::UserAccessAuthorizationError do
      xhr :post, :create, :project_id => raising_project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => raising_and_resolving_project_dependency.id }
    end
  end

  def test_attachments_on_dependencies_cannot_be_accessed_by_non_raising_or_resolving_members
    card = @project.cards.create!(:name => "first card", :card_type_name => "Card")
    unauthorized_user = create_user!

    dependency = card.raise_dependency(:name => "has attachment", :desired_end_date => "01/01/2015", :resolving_project_id => @project.id)
    dependency.save!
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
    xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => dependency.id }
    attachment = dependency.reload.attachments.last

    login(unauthorized_user)
    assert_raise ErrorHandler::UserAccessAuthorizationError do
      get :show, :id => attachment.id, :project_id => @project.identifier
    end
  end

  def test_anon_users_access_for_attachments_on_dependencies_only_when_raising_or_resolving_project_anon_enabled
    card = @project.cards.create!(:name => "first card", :card_type_name => "Card")
    anonymous_user = User.anonymous

    resolving_project = create_project
    set_anonymous_access_for(resolving_project, true)
    change_license_to_allow_anonymous_access

    dependency = card.raise_dependency(:name => "has attachment", :desired_end_date => "01/01/2015", :resolving_project_id => resolving_project.id)
    dependency.save!

    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
    xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => dependency.id }
    attachment = dependency.reload.attachments.last

    logout_as_nil
    get :show, :id => attachment.id, :project_id => @project.identifier
    assert_response :redirect
    assert_include file_to_upload.original_filename, @response.redirected_to

    set_anonymous_access_for(resolving_project, false)
    get :show, :id => attachment.id, :project_id => @project.identifier
    assert_include 'login', @response.redirected_to[:action]
  end

  def test_raising_project_member_cannot_access_attachments_on_dependencies_which_resolving_project_has_on_a_third_project
    resolving_project = @project
    raising_user = create_user!
    raising_project = create_project(:users => [raising_user])
    third_project = create_project

    raising_card = nil
    raising_project.with_active_project do |raising_project|
      raising_card = raising_project.cards.create!(:name => "first card", :card_type_name => "Card")
    end

    third_project_raising_card = nil
    third_project.with_active_project do |third_project|
      third_project_raising_card = third_project.cards.create!(:name => "third project raising card", :card_type_name => "Card")
    end

    raising_and_resolving_project_dependency = raising_card.raise_dependency(:name => "dep", :desired_end_date => "11/01/2015", :resolving_project_id => resolving_project.id)
    raising_and_resolving_project_dependency.save!

    third_project_dependency = third_project_raising_card.raise_dependency(:name => "Dep with unacessible Attachment", :desired_end_date => "11/01/2015", :resolving_project_id => resolving_project.id)
    third_project_dependency.save!

    login_as_member # Resolving project member login
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
    xhr :post, :create, :project_id => resolving_project.identifier, :upload => file_to_upload, :attachable => { :type => "dependency", :id => third_project_dependency.id }
    attachment = third_project_dependency.reload.attachments.last

    login(raising_user)
    assert_raise ErrorHandler::UserAccessAuthorizationError do
      get :show, :id => attachment.id, :project_id => resolving_project.identifier
    end
  end

  def test_resolving_project_member_cannot_access_attachments_on_cards_on_raising_project
    card = @project.cards.create!(:name => "first card", :card_type_name => "Card")
    resolving_user = create_user!
    resolving_project = create_project(:users => [resolving_user])

    dependency = card.raise_dependency(:name => "dep", :desired_end_date => "01/01/2015", :resolving_project_id => resolving_project.id)
    dependency.save!
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")

    xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :attachable => { :type => "card", :id => card.id }
    attachment = Attachment.find_by_file('icon.png')

    login(resolving_user)
    assert_raise ErrorHandler::UserAccessAuthorizationError do
      get :show, :id => attachment.id, :project_id => @project.identifier
    end
  end

  def test_retrieve_external_attachment
    url = "http://any.url.will.do/foo.jpg"

    klass = AttachmentsController::RetrievedFile

    def klass.wget(url)
      self.fake_response
    end

    card = @project.cards.create!(:name => "external attachment", :card_type_name => "Card")
    xhr :post, :retrieve_from_external, :project_id => @project.identifier, :attachable => {:type => "card", :id => card.id}, :basename => "external-image", :external => url
    assert_response :success
    assert_equal 1, card.reload.attachments.size
    assert_equal "external-image.png", card.attachments.first.file_name
    assert card.attachments.first.file_exists?
  ensure
    def klass.wget(url)
      HTTParty.get(url)
    end
  end

  def test_retrieve_external_attachment_fails
    url = "http://any.url.will.do/foo.jpg"

    klass = AttachmentsController::RetrievedFile

    def klass.wget(url)
      self.fake_response(404)
    end

    card = @project.cards.create!(:name => "external attachment", :card_type_name => "Card")
    xhr :post, :retrieve_from_external, :project_id => @project.identifier, :attachable => {:type => "card", :id => card.id}, :basename => "external-image", :external => url
    assert_response 422
    assert_equal 0, card.reload.attachments.size
  ensure
    def klass.wget(url)
      HTTParty.get(url)
    end
  end

  def test_card_explorer_search_returning_no_cards_should_show_no_results_message
    attachment = @project.attachments.create(:file => sample_attachment('2.jpg'))
    get :show, :id => attachment.id, :project_id => @project.identifier
    assert_response :redirect
  end

  def test_should_create_an_attachment_unassociated_with_any_card_on_create
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
    xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :CKEditorFuncNum => 'null', :attachable => { :type => 'card', :id => nil }
    attachment = Attachment.find_by_file('icon.png')
    assert attachment
    assert attachment.attachings.empty?
  end

  def test_create_given_an_existing_card_associates_the_new_attachment_to_the_card
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
    card = @project.cards.create!(:name => 'attach to me please', :card_type_name => 'Card')
    xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :CKEditorFuncNum => 'null', :attachable => { :type => 'card', :id => card.id }
    attachment = Attachment.find_by_file('icon.png')
    assert attachment
    assert_equal attachment, card.reload.attachments.first
  end

  def test_create_given_an_existing_page_associates_the_new_attachment_to_the_page
    file_to_upload = ActionController::TestUploadedFile.new("#{File.expand_path(Rails.root)}/test/data/icons/icon.png")
    page = @project.pages.create!(:name => 'guns of brixton')
    xhr :post, :create, :project_id => @project.identifier, :upload => file_to_upload, :CKEditorFuncNum => 'null', :attachable => { :type => 'page', :id => page.id }
    attachment = Attachment.find_by_file('icon.png')
    assert attachment
    assert_equal attachment, page.reload.attachments.first
  end

  class AttachmentsController::RetrievedFile
    def self.fake_response(code=200, mime="image/png", content="not really anything at all")
      mock = OpenStruct.new
      mock.code = code
      mock.content_type = mime
      mock.parsed_response = content
      mock
    end
  end

end
