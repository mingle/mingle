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

module TagMgmtAndUsageAction

    def navigate_to_tag_management_for(project)
        project = project.identifier if project.respond_to? :identifier
        @browser.open "/projects/#{project}/tags/list"
    end


    def create_tag_for(project, tag)
        identifier, project = project_and_identifier(project)
        @browser.open "/projects/#{identifier}/tags/new"
        type_tag_name(tag)
        click_create_tag
        project.tags.find_by_name(tag)
    end

    def update_tag_for(project, old_name, new_name)
        identifier, project = project_and_identifier(project)
        @browser.open("/projects/#{identifier}/tags")
        click_edit_for_tag(project, old_name)
        type_tag_name(new_name)
        click_save_tag
    end

    def tag_page(project, page_name, tags)
        project = project.identifier if project.respond_to?(:identifier)
        @browser.open("/projects/#{project}/wiki/#{page_name}")
        tag_with(tags)
    end

    def type_tag_name(tag)
        @browser.type(TagMgmtAndUsagePageId::TAG_NAME_ID, tag)
    end

    def safe_delete_tag(project, tag_name, is_tagging = false)
        identifier, project = project_and_identifier(project)
        @browser.open "/projects/#{identifier}/tags/list"
        @browser.click_and_wait "destroy-#{tag_html_id(project, tag_name)}"
        if is_tagging
            click_continue_to_delete
        end
    end

    def project_and_identifier(project)
        if project.respond_to? :identifier
            [project.identifier, project]
        else
            [project, Project.find_by_identifier(project)]
        end
    end

    def tag_html_id(project, name)
        project.tags.find_by_name(name).html_id
    end

    def click_create_tag
        @browser.click_and_wait TagMgmtAndUsagePageId::CREATE_TAG_LINK
    end

    def click_save_tag
        @browser.click_and_wait TagMgmtAndUsagePageId::SAVE_TAG_LINK
    end

    def click_edit_for_tag(project, tag)
        tag = project.tags.find_by_name(tag) unless tag.respond_to?(:html_id)
        @browser.click_and_wait(edit_tag(tag))
    end

    def click_delete_for_tag(project, tag)
        tag = project.tags.find_by_name(tag) unless tag.respond_to?(:html_id)
        @browser.click_and_wait(delete_tag(tag))
    end

    def click_continue_to_delete
        @browser.click_and_wait TagMgmtAndUsagePageId::CONTINUE_TO_DELETE
    end

    def tag_page(project, page_name, tags)
        project = project.identifier if project.respond_to?(:identifier)
        @browser.open("/projects/#{project}/wiki/#{page_name}")
        tag_with(tags)
    end

    def delete_tags(*tags)
        editor = tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID)
        @browser.click editor.open_edit_link_locator
        tags.flatten.each do |tag|
            html_id = delete_tag_id(tag)
            @browser.with_ajax_wait do
                @browser.click html_id
            end
            if @browser.is_element_present(html_id)
                @browser.with_ajax_wait do
                    @browser.click html_id
                end
            end
            @browser.assert_element_not_present(html_id)
        end
        @browser.click editor.close_button_locator
    end

    class TagsEditor
        def initialize(name, test_helper)
            @name = name
            @test_helper = test_helper
        end

        def method_missing(method, *args, &block)
            if method.to_s =~ /^(.*)_locator$/
                class_name = $1.gsub(/_/, '-')
                options = args.extract_options!
                locator = "css=##{@name}-tags-editor-container .#{class_name}"
                if options[:index] && options[:index].to_i != 0
                    locator << ":nth-child(#{options[:index].to_i + 1})"
                end
                locator
            else
                super(method, *args, &block)
            end
        end
    end

    def tags_editor(name)
        TagsEditor.new(name, self)
    end

    def tag_with(*tags)
        return if (tags.nil? || tags.empty?)
        editor = tags_editor(TagMgmtAndUsagePageId::TAG_LIST_ID)
        if @browser.is_element_present(editor.open_edit_link_locator)
            set_tags(editor, tags, true)
        else
            set_tags(tags_editor(TagMgmtAndUsagePageId::TAGGED_WITH_ID), tags)
        end
    end

    def filter_by_tag(tags)
        return if (tags.nil? || tags.empty?)
        editor = tags_editor(TagMgmtAndUsagePageId::FILTER_TAGS_ID)
        if @browser.is_element_present(editor.open_edit_link_locator)
            set_tags(editor, tags, true)
        else
            raise "no link present to add tags as filter"
        end
    end

    private
    def set_tags(editor, tags, with_ajax=false)
        @browser.click editor.open_edit_link_locator
        @browser.type editor.input_box_locator, tags.join(',')
        if with_ajax
            @browser.with_ajax_wait { @browser.click editor.add_tag_button_locator }
        else
            @browser.click editor.add_tag_button_locator
        end
        @browser.click editor.close_button_locator
    end
end
