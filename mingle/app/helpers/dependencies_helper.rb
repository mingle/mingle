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

module DependenciesHelper
  include DependencyAccess
  def heading(display_text, column, view)
    column = column.to_s.downcase

    icon = "fa-sort"

    if column == view.sort
      icon = "fa-sort-#{view.dir}"
    end
    if sort_params = view.sort_column_params(column)
      content = [content_tag(:span, display_text), content_tag(:i, "", :class => "fa #{icon}")].join(" ").html_safe

      link_to(content, sort_params.merge(:controller => "dependencies", :action => "index"))
    else
      content_tag(:span, display_text)
    end
  end

  def tab_column_value(column, dependency, project)
    value = dependency.send(column)
    if value.is_a?(Date) || value.is_a?(Time)
      value && @project.format_date(value)
    elsif value.is_a?(Project) || value.is_a?(User)
      value.name
    elsif value.is_a?(Card)
      "##{value.number} #{value.name}"
    elsif value.is_a?(Array)
      content_tag(:ul) do
        value.map do |v|
          content_tag(:li, "##{v.number} #{v.name}")
        end.join.html_safe
      end
    end
  end

  def add_hide_checkbox(column, view)
    check_box_tag("columns[#{view.filter}][]", column, view.columns.include?(column), :class => "add-hide-column")
  end

  def formatted_date(date, date_format_context)
    return "(not set)" unless date
    date_format_context ? date_format_context.format_date(date) : date
  end

  def filter_request_url(params, selected_filter)
    url_for params.merge(:filter => selected_filter, :action => 'index')
  end

  def on_raising_project?
    @project.id == @dependency.raising_project_id
  end

  def on_resolving_project?
    @project.id == @dependency.resolving_project_id
  end

  def within_popups_holder(js)
    "FakePool().#{js}"
  end

  def attach_to_dependency_history_loader(dependency)
    loading_function = remote_function(:method => :get, :url => {:controller => 'dependencies', :action => 'history', :id => dependency.id},
      :update => {:success =>'dependency-history-container'} ,
      :complete => 'DependencyHistory.loadComplete();');
    "DependencyHistory.attach(\"#{loading_function}\");"
  end

  def should_show_load_more(dependencies, lazy_load, limit)
    return false if !lazy_load || !limit || dependencies.size == 0
    return dependencies.size == limit
  end

  def dependencies_to_load(status, lazy_load, limit)
    if lazy_load && limit
      return @view.dependencies_with_status(status, :limit => limit)
    end
    @view.dependencies_with_status(status)
  end

end
