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

module CardListSupport

  def display_tree_setup
    return true unless @view.requires_tree?

    if @project.tree_configurations.empty?
      html_flash.now[:info] = "There are no trees for #{@project.name.escape_html}. "
      if authorized?(:controller => 'card_trees', :action => 'new')
        html_flash.now[:info] += render_to_string(:inline  => %{<%= link_to 'Create the first tree', :controller => 'card_trees', :action => 'new' %> now.})
      else
        html_flash.now[:info] += "Only a project administrator can create and configure a tree."
      end
      render :text => '', :layout => true
      return false
    end
    if @view.tree_name.blank?
      flash.now[:error] = !params[:tree_name] ? "You must select a tree first" : @view.workspace.validation_errors.map(&:escape_html)
      params[:tree_name] = nil
      params[:style] = 'list'
      list
      return false
    else
      @tree = @project.tree_configurations.detect { |tree| tree.name.downcase == @view.tree_name.downcase }
      unless @tree
        flash.now[:notice] = "#{@view.tree_name} does not exist."
        render :text => '', :layout => true
        return
      end
      @tab_name = @view.to_params[:tab]
      @display_tree = @view.display_tree
      card_context.current_list_navigation_card_numbers = @view.cards.map(&:number)
    end

    return true
  end

  def current_tree
    @view && !@view.tree_name.blank? ? @view.tree_name : CardContext::NO_TREE
  end

end
