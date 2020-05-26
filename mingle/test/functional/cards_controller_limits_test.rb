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

class CardsControllerLimitsTest < ActionController::TestCase

  def setup
    @controller = CardsController.new
    login_as_member
  end

  def test_when_limit_enabled_export_link_is_disabled_if_filtered_cards_above_limit
    with_card_export_limited_to(1) do
      with_first_project do |first_project|
        get :list, :project_id => first_project.identifier
        assert_select 'p.disabled', :text => 'Export cards'
      end
    end
  end

  def test_when_limit_enabled_export_link_exists_if_filtered_cards_below_limit
    with_card_export_limited_to(500) do
      with_first_project do |first_project|
        get :list, :project_id => first_project.identifier
        assert_select 'a.export-cards', :text => 'Export cards'
      end
    end
  end

  def test_when_limit_enabled_bulk_update_is_disabled_if_filtered_cards_above_limit
    with_bulk_update_limited_to(1) do
      with_first_project do |project|

        assert CardViewLimits::MAX_CARDS_TO_BULK_UPDATE < project.cards.size
        error_message = "Bulk update is limited to #{CardViewLimits::MAX_CARDS_TO_BULK_UPDATE} cards"

        with_each_bulk_operation(project) do
          assert_response :success
          assert @response.body.include?(error_message)
        end

      end
    end
  end

  def test_when_limit_enabled_bulk_update_is_allowed_if_filtered_cards_below_limit
    with_bulk_update_limited_to(500) do
      with_first_project do |project|

        assert CardViewLimits::MAX_CARDS_TO_BULK_UPDATE > project.cards.size
        error_message = "Bulk update is limited to #{CardViewLimits::MAX_CARDS_TO_BULK_UPDATE} cards"

        with_each_bulk_operation(project) do
          assert_response :success
          assert !@response.body.include?(error_message)
        end

      end
    end
  end

private

  def with_each_bulk_operation(project, &block)
    all_cards = project.cards.map(&:id).join(",")
    tag = project.tags.find_by_name("first_tag")

    xhr :post, :bulk_set_properties, :project_id => project.identifier, :changed_property => "status", :properties => { 'Status' => 'open' }, :selected_cards => all_cards
    block.call

    xhr :post, :bulk_add_tags, :project_id => project.identifier, :selected_cards => all_cards, :tags => "foo"
    block.call

    post :bulk_remove_tag, :project_id => project.identifier, :tag_id => tag.id, :selected_cards => all_cards
    block.call
  end

  def with_card_export_limited_to(num, enabled=true, &block)
    with_constant_set("CardViewLimits::MAX_CARDS_TO_EXPORT", num) do
      block.call
    end
  end

  def with_bulk_update_limited_to(num, enabled=true, &block)
    with_constant_set("CardViewLimits::MAX_CARDS_TO_BULK_UPDATE", num) do
      block.call
    end
  end

end
