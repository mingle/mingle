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

class CardsControllerAttachmentsTest < ActionController::TestCase
  include TreeFixtures::PlanningTree, ::RenderableTestHelper::Functional

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def teardown
    Clock.reset_fake
    MingleConfiguration.attachment_size_limit = nil
  end

  def test_create_with_dangling_attachments
    a1 = @project.attachments.create(:file => sample_attachment("1.txt"))
    a2 = @project.attachments.create(:file => sample_attachment("2.txt"))

    options = default_options.merge("pending_attachments" => [a1.id, a2.id])
    options["card"].merge!("name" => "dangling attachments")
    post(:create, options)

    assert_redirected_to :action => :list
    card = @project.cards.find_by_name("dangling attachments")

    assert_equal 2, card.attachments.size
    assert_equal [a1.id, a2.id].sort, card.attachments.map(&:id).sort
  end

  def test_create_should_display_validation_errors_even_when_submitting_with_attachments
    a = @project.attachments.create(:file => sample_attachment("1.txt"))
    invalid_card_with_no_name = {
      "commit" => "Create Card",
      "multipart"=>"true",
      "pending_attachments" => [ a.id ],
      "project_id" => @project.identifier,
      "card" => {
        "name" => "",
        "description" => "",
        "card_type" => @project.card_types.first
      },
      "properties" => {}
    }

    assert_nothing_raised do
      post(:create, invalid_card_with_no_name)
      assert_response :success
    end
  end

  def test_should_be_able_delete_attachment_in_view_mode
    card = create_card!(:name => 'test card')
    card.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    card.save!
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => card.id, :file_name => 'sample_attachment.txt', :format => "json"
    assert_response :success
    assert_equal({"file" => "sample_attachment.txt"}, JSON.parse(@response.body))
  end

  def test_should_provide_error_message_on_invalid_attachment_name
    card = create_card!(:name => 'test card')
    card.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    card.save!
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => card.id, :file_name => 'invalid_attachment.txt', :format => "json"
    assert_response :not_found
  end

  def test_should_update_description_section_if_it_used_recently_deleted_attachment
    card = create_card!(:name => 'test card', :description => '!sample_attachment.gif!')
    card.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    card.save!
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => card.id, :file_name => 'sample_attachment.gif', :format => "json"
    assert_response :success
    assert_equal({"file" => "sample_attachment.gif"}, JSON.parse(@response.body))
  end

  def test_delete_all_attachments
    card = create_card!(:name => 'test card', :description => '!sample_attachment.gif!')
    card.attach_files(sample_attachment('attachment1.gif'), sample_attachment('attachment2.gif'))
    card.save!

    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => card.id, :file_name => '*', :format => "json"
    assert_response :success
    assert_equal({"file" => "*"}, JSON.parse(@response.body))
  end

  private

  def default_options(properties = {})
    {
      "commit" => "Create Card", "multipart"=>"true", :project_id => @project.identifier,
      "card" => {
        "name" => "card with attachment",
        "description" => "some description",
        "card_type" => @project.card_types.first
      },
      "properties" => properties
    }
  end

  def perform_with_default_options(action, attachments, card_id = nil, properties = {})
    options = default_options(properties)

    if attachments[:add]
      options.merge!("attachments" => attachments[:add])
      options.merge!("deleted_attachments" => attachments[:delete])
    else
      options.merge!("attachments" => attachments)
    end
    options.merge!("id" => card_id ) if card_id

    post(action, options)
    @project.cards.find_by_name('card with attachment')
  end
end
