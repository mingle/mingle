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

module PlannerApplicationHelper
  def programs_path_with_program(program)
    "#{programs_path}##{program.identifier}"
  end

  def new_window_link_to_card(name, card_number, project_identifier)
    link_to name, card_show_path(project_identifier, card_number), :target => "_blank", :class => 'card_link'
  end

  def new_window_link_to_project(name, project_identifier)
    link_to name.escape_html, project_show_path(project_identifier), :target => "_blank", :class => 'project_link'
  end
  
  def format_date(date)
    @plan.format_date(date)
  end

  def readonly_mode?
    MingleConfiguration.readonly_mode?
  end

  module Tabs
    def select_tab(tab_name)
      content_for :selected_tab, tab_name
    end
  end
  include Tabs
  
  include ApplicationHelper::StyledBox

  include ApplicationHelper::FlashMessages  

  module DisablePrimaryButtonOnRemoteCall
    def submit_tag(value = "Save changes", options = {})
      super(value, {"disable_with" => 'Processing...', :name => nil}.merge(options))
    end

    # form_remote_for is using form_remote_tag in rails code
    def form_remote_tag(options = {}, &block)
      super(options, &block)
    end
  end
  include DisablePrimaryButtonOnRemoteCall
end
