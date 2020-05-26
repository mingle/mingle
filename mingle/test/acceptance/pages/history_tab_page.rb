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

module HistoryTabPage


  def assert_history_tab_disabled
    assert_equal("true", @browser.get_eval("this.browserbot.getCurrentWindow().$('history-link').hasClassName('disabled')"))
  end

  def assert_history_tab_enabled
    assert_equal("false", @browser.get_eval("this.browserbot.getCurrentWindow().$('history-link').hasClassName('disabled')"))
  end

  def assert_properties_in_first_filter_widget(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text droplist_link_id(property_name), property_value
    end
  end

  def filter_result_should_contain(property_name, old_value, new_value)
    @browser.assert_text_present "#{property_name} changed from #{old_value} to #{new_value}"
  end

  def filter_result_should_not_contain(property_name, old_value, new_value)
    @browser.assert_text_not_present "#{property_name} changed from #{old_value} to #{new_value}"
  end

  def assert_no_inline_edits_present
    @browser.assert_element_not_present(class_locator("inline-add-new-value"))
  end

  def assert_properties_in_second_filter_widget(properties)
    properties.each do |property_name, property_value|
      @browser.assert_text droplist_link_id(property_name, "acquired"), property_value
    end
  end

  def assert_property_not_present_in_first_filter_widget(property)
    @browser.assert_element_does_not_match('involved_filter_widget', /#{property}/)
  end

  def assert_property_not_present_in_second_filter_widget(property)
    @browser.assert_element_does_not_match('acquired_filter_widget', /#{property}/)
  end

  def assert_value_not_present_in_history_filter_drop_list_for(property_name,property_value,options={})
    definition = @project.find_property_definition_or_nil(property_name, :with_hidden => true)
    context = "#{options[:property_type]}"+"propertydefinition"
    @browser.click("#{context}_#{definition.id}_drop_link")
    @browser.assert_element_not_present("#{context}_#{definition.id}_option_#{property_value}")
  end

  def assert_value_present_in_history_filter_drop_list_for_property_in_first_filter_widget(property_name, property_value, options={})
    definition = @project.find_property_definition_or_nil(property_name, :with_hidden => true)
    context = "#{options[:property_type]}"+"propertydefinition"
    @browser.click("#{context}_#{definition.id}_drop_link")
    filter_locator = "css=##{context}_#{definition.id}_drop_down .dropdown-options-filter"
    @browser.type_in_property_search_filter(filter_locator, options[:search_term] || property_value) if @browser.is_element_present(filter_locator)
    @browser.assert_element_present("#{context}_#{definition.id}_option_#{property_value}")
  end

  def assert_value_present_in_history_filter_drop_list_for_property_in_second_filter_widget(property_name, property_value, options={})
    definition = @project.find_property_definition_or_nil(property_name, :with_hidden => true)
    context = "#{options[:property_type]}"+"propertydefinition"
    @browser.click("acquired_#{context}_#{definition.id}_drop_link")
    filter_locator = "css=#acquired_#{context}_#{definition.id}_drop_down .dropdown-options-filter"
    @browser.type_in_property_search_filter(filter_locator, options[:search_term] || property_value) if @browser.is_element_present(filter_locator)
    @browser.assert_element_present("acquired_#{context}_#{definition.id}_option_#{property_value}")
  end


  def user_should_be_able_to_subscribe_it_successfully
    click_subscribe_via_email
    @browser.assert_text_present("You have subscribed to this via email.")
  end

  def assert_order_of_involved_properties_on_history_filter(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if (property != properties.last)
        property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered("enumeratedpropertydefinition_#{property.id}_span", "enumeratedpropertydefinition_#{next_property[index].id}_span") unless property == properties.last
      end
    end
  end

   def assert_order_of_acquired_properties_on_history_filter(project, *properties)
    project = project.identifier if project.respond_to? :identifier
    next_property = Hash.new
    properties.each_with_index do |property, index|
      if (property != properties.last)
        property = Project.find_by_identifier(project).find_property_definition(property, :with_hidden => true)
        next_property[index] = Project.find_by_identifier(project).find_property_definition_or_nil(properties[index.next], :with_hidden => true) if property != properties.last
        assert_ordered("acquired_enumeratedpropertydefinition_#{property.id}_span", "acquired_enumeratedpropertydefinition_#{next_property[index].id}_span") unless property == properties.last
      end
    end
  end
end

class HistoryAssertion
  include Test::Unit::Assertions, CSSLocatorHelper

  def initialize(browser, versioned_type, identifier)
    @browser                  = browser
    @versioned_type           = versioned_type
    @identifier               = identifier
  end

  def version(version)
    @version                  = version
    self
  end

  def wait_for_histry_to_load
    counter=0
    while @browser.is_element_present('link=refresh') && counter<10 do
      @browser.click("link=refresh")
      sleep 1
      counter+=1
    end
  end

  def shows(history_content)
    supported_content_types   = [:set_properties, :tagged_with, :unset_properties, :tags_removed, :changed, :formula_changed, :from, :to, :message, :link_to_card, :with_text, :in_project,
      :created_by, :modified_by, :comments_added, :attachment_added, :attachment_removed, :attachment_replaced, :property_removed, :from_card_type]
      raise "One of the following is not supported by shows: #{history_content.keys.join(', ')}" unless history_content.keys.all?{|key| supported_content_types.include?(key)}
      raise "Shows requires at least one assertion" if history_content.empty?

      if history_content[:set_properties]
        wait_for_histry_to_load
        history_content[:set_properties].each{|name, value| element_matches_regexp("#{name.to_s} set to #{value}") }
      end

      if history_content[:tagged_with]
        wait_for_histry_to_load
        history_content[:tagged_with].each do |tag|
          element_matches_regexp("Tagged with #{tag}")
        end
      end

      if history_content[:unset_properties]
        wait_for_histry_to_load
        history_content[:unset_properties].each{|name, value| element_matches_regexp("#{name.to_s} changed from #{value} to (not set)")}
      end

      if history_content[:tags_removed]
        wait_for_histry_to_load
        history_content[:tags_removed].each do |tag|
          element_matches_regexp("Tag removed #{tag}")
        end
      end

      if history_content[:changed]
        wait_for_histry_to_load
        change_message        = "#{history_content[:changed]} changed"
        change_message << " from #{history_content[:from]} to #{history_content[:to]}" if history_content[:from] and history_content[:to]
        element_matches_regexp(change_message)
      end
      if history_content[:formula_changed]
        wait_for_histry_to_load
        change_message        = "System generated comment: #{history_content[:formula_changed]} changed"
        change_message << " from #{history_content[:from]} to #{history_content[:to]}" if history_content[:from] and history_content[:to]
        element_matches_regexp(change_message)
      end
      if history_content[:property_removed]
        wait_for_histry_to_load
        element_matches_regexp("System generated comment: Property #{history_content[:property_removed]} is no longer applicable to card type #{history_content[:from_card_type]}.")
      end
      if history_content[:message]
        wait_for_histry_to_load
        element_matches_regexp(history_content[:message])
      end
      if history_content[:link_to_card]
        wait_for_histry_to_load
        assert_equal history_content[:with_text], @browser.get_text(card_link_within_revision_message(history_content))
      end
      if history_content[:created_by]
        @browser.assert_element_matches event_element_id, /Created by #{history_content[:created_by]} .* /
        # element_matches_regexp("Created .* by #{history_content[:created_by]}")
      end
      if history_content[:modified_by]
        wait_for_histry_to_load
        @browser.assert_element_matches event_element_id, /Modified by #{history_content[:modified_by]} .*/
        # element_matches_regexp("Updated .* by #{history_content[:modified_by]}")
      end
      if history_content[:comments_added]
        wait_for_histry_to_load
        element_matches_regexp("Comment added:")
        element_matches_regexp("#{history_content[:comments_added]}")
      end

      if history_content[:attachment_added]
        wait_for_histry_to_load
        element_matches_regexp("Attachment added #{File.basename(history_content[:attachment_added])}")
      end

      if history_content[:attachment_removed]
        wait_for_histry_to_load
        element_matches_regexp("Attachment removed #{File.basename(history_content[:attachment_removed])}")
      end

      if history_content[:attachment_replaced]
        wait_for_histry_to_load
        element_matches_regexp("Attachment replaced #{File.basename(history_content[:attachment_replaced])}")
      end
    end

    def does_not_show(history_content)
      supported_content_types = [:set_properties, :tagged_with, :tags_removed, :changed, :from, :to, :message, :link_to_card, :with_text, :in_project,
        :created_by, :modified_by, :property_removed, :from_card_type]
        raise "One of the following is not supported by shows: #{history_content.keys.join(', ')}" unless history_content.keys.all?{|key| supported_content_types.include?(key)}
        raise "Shows requires at least one assertion" if history_content.empty?

        if history_content[:set_properties]
          history_content[:set_properties].each{|name, value| element_does_not_match_regexp("#{name.to_s} set to #{value}") }
        end
        if history_content[:tagged_with]
          tags                = history_content[:tagged_with].join(', ')
          element_does_not_match_regexp("Tagged with #{tags}")
        end
        if history_content[:tags_removed]
          tags                = history_content[:tags_removed].join(', ')
          element_does_not_match_regexp("Tag(s)* removed #{tags}")
        end
        if history_content[:changed]
          element_does_not_match_regexp("#{history_content[:changed]} changed from #{history_content[:from]} to #{history_content[:to]}")
        end
        if history_content[:message]
          element_does_not_match_regexp(history_content[:message])
        end
        if history_content[:link_to_card]
          @browser.assert_element_not_present card_link_within_revision_message(history_content)
        end
        if history_content[:created_by]
          element_does_not_match_regexp("created by #{ history_content[:created_by]}")
        end
        if history_content[:modified_by]
          element_does_not_match_regexp("changed by #{ history_content[:modified_by]}")
        end
        if history_content[:property_removed]
          element_does_not_match_regexp("System generated comment: Property #{history_content[:property_removed]} is no longer applicable to card type #{history_content[:from_card_type]}.")
        end
      end

      def not_present
        @browser.assert_element_not_present event_element_id
      end

      def present
        @browser.assert_element_present event_element_id
      end

      private
      def element_matches_regexp(regexp_string)
        @browser.assert_element_matches event_element_id, /#{Regexp.escape(regexp_string)}/
      end

      def element_does_not_match_regexp(regexp_string)
        @browser.assert_element_does_not_match event_element_id, /#{Regexp.escape(regexp_string)}/
      end

      def event_element_id
        if @versioned_type == :revision
          "#{@versioned_type.to_s}-#{@identifier}"
        else
          "#{@versioned_type.to_s}-#{@identifier}-#{@version}"
        end
      end

      def card_link_within_revision_message(history_content)
        css_locator "##{event_element_id} .card-link-#{history_content[:link_to_card]}"
      end
    end
