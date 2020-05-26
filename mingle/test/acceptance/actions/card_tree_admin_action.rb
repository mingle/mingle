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

module CardTreeAdminAction
    
    def open_aggregate_property_management_page_for(project, tree)
        project = project.identifier if project.respond_to? :identifier
        @browser.open("/projects/#{project}/card_trees/edit_aggregate_properties/#{tree.id}")
      end

    def navigate_to_tree_configuration_management_page_for(project)
        project = project.identifier if project.respond_to? :identifier
        @browser.open("/projects/#{project}/card_trees/list") 
    end

    def navigate_to_tree_configuration_for(project, tree)
        project = project.identifier if project.respond_to? :identifier
        @browser.open("/projects/#{project}/card_trees/edit/#{tree.id}")
    end

    def create_and_configure_new_card_tree(project, options={})
        location = @browser.get_location
        types = options[:types]
        name = options[:name]
        description = options[:description]
        relationship_names = options[:relationship_names]
        navigate_to_tree_configuration_management_page_for(project) unless location =~ /#{project.identifier}\/card_trees\/list/
        click_create_new_card_tree_link
        type_tree_name(name)
        type_description(description)
        types.each_with_index do |type, index|
            if(index < 2)
                select_type_on_tree_node(index, type)
                type_relationship_name_on_tree_configuration_for(index, relationship_names[index]) if relationship_names != nil and index != 1
            else
                add_new_card_type_node_to(index - 1)
                select_type_on_tree_node(index, type)
                type_relationship_name_on_tree_configuration_for(index-1, relationship_names[index-1]) if relationship_names != nil
            end
        end
        click_save_link
        project.tree_configurations.find_by_name(name)
    end

    def edit_card_tree_configuration(project, tree_name, options = {})
        select_type = 'Select type...'
        location = @browser.get_location
        card_tree_def = project.tree_configurations.find_by_name(tree_name)
        nodes = card_tree_def.all_card_types
        navigate_to_tree_configuration_for(project, card_tree_def) unless location =~ /projects\/#{project.identifier}\/card_trees\/edit\/#{card_tree_def.id}/
        new_name = options[:new_tree_name] || tree_name
        types = options[:types]
        description = options[:description] 
        type_tree_name(new_name)
        type_description(description) if description != nil
        if types != nil
            nodes.each_with_index {|type, index| select_type_on_tree_node(index, select_type)}
            types.each_with_index do |type, index|
                if(index < nodes.size)
                    select_type_on_tree_node(index, type)
                else
                    add_new_card_type_node_to(index - 1)
                    select_type_on_tree_node(index, type)
                end
            end         
        end
        save_tree_permanently
        project.tree_configurations.find_by_name(new_name)
    end

    def remove_a_card_type_and_save_tree_configuraiton(project, tree, card_type)
        location = @browser.get_location
        navigate_to_tree_configuration_for(project, tree) unless location =~ /projects\/#{project}\/card_trees\/edit\/#{tree.id}/
        remove_card_type_tree(project, tree, card_type)   
        save_tree_permanently
    end

    def remove_a_card_type_and_wait_on_confirmation_page(project, tree, card_type)
        location = @browser.get_location
        navigate_to_tree_configuration_for(project, tree) unless location =~ /projects\/#{project}\/card_trees\/edit\/#{tree.id}/
        remove_card_type_tree(project, tree, card_type)   
        retryable(:on => Exception, :tries => 10, :sleep => 1) do
          click_save_link
        end
    end

    def rename_relationship_property(project, tree, relationship_property, new_property_name)
        project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
        tree = project.tree_configurations.find_by_name(tree) unless tree.respond_to?(:name)
        relationship_property = project.find_property_definition_or_nil(relationship_property) unless relationship_property.respond_to?(:name)
        position_of_relationship_property = tree.card_type_index(relationship_property.valid_card_type)
        open_configure_a_tree_through_url(project, tree)
        type_relationship_name_on_tree_configuration_for(position_of_relationship_property, new_property_name)
        save_tree_permanently
    end

    def delete_tree_configuration_for(project, tree_def)
        click_delete_link_for(project, tree_def)
        assert_warning_box_present
        click_on_continue_to_delete_link
    end

    def click_delete_link_for(project, tree_def)
        @browser.open("/projects/#{project.identifier}/card_trees/confirm_delete/#{tree_def.id}")
    end


    def save_tree_permanently
        click_save_link
        click_save_permanently_link if @browser.is_element_present(warning_box_id)
    end

    def click_create_new_card_tree_link
        @browser.click_and_wait(CardTreeAdminPageId::CREATE_NEW_CARD_TREE_LINK)
    end

    def type_tree_name(name)
        @browser.type(CardTreeAdminPageId::TREE_NAME_TEXT_BOX, name)
    end

    def type_description(description)
        @browser.type(CardTreeAdminPageId::TREE_DESCRIPTION_TEXT_BOX, description)
    end

    def add_new_card_type_node_to(type_node_number)
        @browser.click(add_card_type_node_id(type_node_number))
    end

    def remove_card_type_node_from_tree(type_node_number)
        @browser.click(remove_card_type_node_id(type_node_number))
    end

    def add_new_card_type_to_node(project, tree, type, type_node_number, options={})
        open_configure_a_tree_through_url(project, tree)
        add_new_card_type_node_to(type_node_number)
        select_type_on_tree_node(type_node_number + 1, type)
        type_relationship_name_on_tree_configuration_for(type_node_number,  options[:relationship_name]) if options[:relationship_name] != nil
        save_tree_permanently
    end

    def remove_card_type_tree(project, tree, card_type)
        project = Project.find_by_identifier(project) unless project.respond_to?(:identifier)
        tree = project.tree_configurations.find_by_name(tree) unless tree.respond_to?(:name)
        card_type = project.card_types.find_by_name(card_type) unless card_type.respond_to?(:name)
        type_node_number = tree.card_type_index(card_type)
        @browser.click(remove_card_type_node_id(type_node_number))
    end

    def select_type_on_tree_node(type_node_number, type_name)
        click_select_type_link_for(type_node_number)
        @browser.click(select_type_option_on_tree_node_id(type_name,type_node_number))
        @browser.wait_for_element_not_visible(card_type_dropdown_element(type_node_number))
    end

    def click_select_type_link_for(type_node_number, options = {:click_to_open => true})
        @browser.click(select_type_on_tree_node_id(type_node_number))
        if options[:click_to_open]
            @browser.wait_for_element_visible(card_type_dropdown_element(type_node_number))
        else  
            @browser.wait_for_element_not_visible(card_type_dropdown_element(type_node_number))
        end  
    end

     

    def click_on_configure_tree_for(project, tree_def)
        @browser.click_and_wait("//a[contains(@href, '/projects/#{project.identifier}/card_trees/edit/#{tree_def.id}')]")
    end

    def click_on_tree_view_in_card_tree_management_page_for(project, tree_def)
        @browser.click_and_wait("//a[contains(@href, '/projects/#{project.identifier}/cards/tree?tree_name=#{tree_def.name.to_s.gsub(/[' ']/, '+')}')]")
    end

    def click_on_hierarchy_view_in_card_tree_management_page_for(project, tree_def)
        @browser.click_and_wait("//a[contains(@href, '/projects/#{project.identifier}/cards/hierarchy?tree_name=#{tree_def.name.to_s.gsub(/[' ']/, '+')}')]")
    end

    def type_relationship_name_on_tree_configuration_for(type_node_number, name)
        click_edit_relationship_link(:type_node_number => type_node_number)
        @browser.type(relationship_name_textbox_on_tree_configuration(type_node_number), name)
        @browser.press_enter(relationship_name_textbox_on_tree_configuration(type_node_number))
    end

    def click_edit_relationship_link(options)
        @browser.click(edit_relationship_link_id(options))
    end

    def open_configure_a_tree_through_url(project, card_tree_def)
        @browser.open("/projects/#{project.identifier}/card_trees/edit/#{card_tree_def.id}")
    end

    def open_create_new_tree_page_for(project)
        @browser.open("/projects/#{project.identifier}/card_trees/new")
    end
end
