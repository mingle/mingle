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

module SharedFeatureHelperPageId

  EDIT_LINK='link=Edit'
  CANCEL_LINK="link=Cancel"
  SAVE_LINK='link=Save'
  DELETE_LINK='link=Delete'
  SAVE_SETTINGS_LINK='link=Save settings'
  SAVE_PERMANENTLY_LINK='link=Save permanently'
  CONTINUE_TO_DELETE_LINK='link=Continue to delete'
  CONTINUE_TO_UPDATE_LINK='link=Continue to update'
  LINK_TO_THIS_PAGE="link=Update URL"
  CLICK_UP_LINK="link=Up"
  RESET_FILTER_LINK="link=Reset filter"
  SHOW_HELP_LINK='link=Show help'
  HIDE_HELP_LINK='link=Hide help'
  CONTENT = 'content'
  ERROR = 'error'
  NOTICE = 'notice'
  INFO = 'info'
  INFO_BOX='info-box'
  WARNING_BOX = 'warning-box'
  WARNING ='warning'
  UP_LINK_HOVER_TEXT = "up-link-hover-text"
  COMMENT_CREATED_BY = 'comment-created-by'
  COMMENT_CONTEXT = 'comment-context'
  DISCUSSION_CONTAINER = 'discussion-container'
  TRANSITION_ONLY_TOOLTIP = 'transition_only_tooltip'
  TRANSITION_HIDDEN_PROTECTED='transition-hidden-protected'
  FLASH = 'flash'
  QUESTION_BOX = 'question_box'
  CONTEXTUAL_HELP_ID="contextual_help_identifier"
  ASSIGN_PROJECT_SUBMIT_ID = 'assign_projects_submit'

  def click_link_text(link_text)
    "link=#{link_text}"
  end

  def click_up_link_text(up_link_text)
    "link=#{up_link_text}"
  end
end
