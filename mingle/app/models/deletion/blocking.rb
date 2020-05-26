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

class Deletion::Blocking
  def initialize(target, options={})
    @target = target
    @options = options
  end

  def description
    "#{source}is used #{used_as} #{ERB::Util.h(@target.name).bold}".html_safe
  end

  def render(view_helper)
    "#{source}is used #{used_as} #{ERB::Util.h(@target.name).bold}. To manage #{ERB::Util.h(@target.name).bold}, please go to #{view_helper.link_to(link_name, manage_path(view_helper), :target => 'blocking')}.".html_safe
  end

  private

  def link_name
    @options[:link_name] ? @options[:link_name] + ' page' : 'this page'
  end

  def used_as
    case
    when @options[:used_as]
      "as #{@options[:used_as]} of"
    when @options[:used_in]
      "in #{@options[:used_in]}"
    when @options[:used_by]
      "by #{@options[:used_by]}"
    else
      "in"
    end
  end

  def source
    @options[:source] ? @options[:source].bold + ' ' : ''
  end

  def manage_path(view_helper)
    target_route = ActionController::RecordIdentifier.plural_class_name(@target)
    view_helper.send("manage_#{target_route}_path", {:project_id => @target.project.identifier, :id => @target.id})
  end
end
