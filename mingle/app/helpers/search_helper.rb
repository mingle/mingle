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

module SearchHelper
  def render_result(result, referrer)
    result_name = result.type.singularize
    render :partial => result_name,  :locals => { result_name.to_sym => result, :referrer => referrer}
  end

  def search_result_rank(rank, size)
    @query ||= build_query_info(size)
    @query.merge(:rank => rank)
  end

  def build_query_info(size)
    {:size => size, :q => params[:q], :q_type => params[:type], :ts => Clock.now.strftime('%D %T'), :query_id => 'q'.uniquify}.tap do |q|
      Kernel.logger.info({:query => q}.inspect)
    end
  end

  def result_description
    result_descs = @search.models.collect do |m|
      pluralize_exists(@search.count_of(m), m.name.underscore)
    end
    humanize_join(result_descs)
  end

  def tabs
    tab_hash.keys
  end

  def options(tab_name)
    options = {:controller => "search", :action =>"index", :q => params[:q]}
    options.merge!(:type => tab_name) unless is_default(tab_name)
    options
  end

  def is_selected(tab_name)
    selected = search_type == tab_name || (search_type.blank? && is_default(tab_name))
  end

  def display_name(tab_name)
    tab_hash[tab_name]
  end

  def search_type
    params["type"]
  end

  private
  def is_default(tab_name)
    tab_name == "all"
  end

  def tab_hash
    {"all" => "All", "cards" => "Cards", "pages" => "Pages", "murmurs" => "Murmurs", "dependencies" => "Dependencies"}
  end
end
