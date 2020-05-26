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

class SearchController < ProjectApplicationController
  allow :get_access_for => [:index, :request_popup, :fuzzy_cards, :recent]

  GO_TO_NUMBER_REGEX = /^#(D?)(\d+)$/i

  def index
    @search = Search::Client.new
    card_context.store_tab_params(params, current_tab[:name], CardContext::NO_TREE)
    @results = @search.find( params )
  end

  def request_popup
    is_dependency, number = search_by_number?(params)

    if number.present? && number > 0
      redirect_to :controller => (is_dependency ? "dependencies" : "cards"), :action => "popup_show", :project_id => @project.identifier, :number => number
      return
    else
      render :json => {:error => {:message => "Cannot open card with: #{(params[:q] || "").strip.inspect}"}}.to_json, :status => 422
    end
  end

  def fuzzy_cards
    txt = params[:term]
    query = MingleConfiguration.saas? ? fuzzy_cards_query_for_new_es(txt) : fuzzy_cards_query_for_old_es(txt)
    search(query)
  end

  def recent
    query = MingleConfiguration.saas? ? recent_search_query_for_new_es : recent_search_query_for_old_es
    search(query)
  end


  private

  def search_by_number?(params)
    if !params[:q].strip.blank?
      matchdata = GO_TO_NUMBER_REGEX.match(params[:q].strip)
      [ matchdata[1].present?, matchdata[2].to_i ] if matchdata
    end
  end

  def search_result_help_link
    render_help_link('Search Results Page', :class => 'page-help-in-message-box')
  end

  def date_format_context
    @project
  end

  def fuzzy_cards_query_for_old_es(txt)
    {
        :fields => ["number", "name", "card_type_name"],
        :query => {
            :filtered => {
                :query => {
                    :flt => {
                        :fields => ["name"],
                        :like_text => txt
                    }
                },
                :filter => {
                    :term => {
                        :project_id => Project.current.id
                    }
                }
            }
        }
    }
  end

  def fuzzy_cards_query_for_new_es(txt)
    {
        query: {
            bool: {
                must: [{match: {name: {query: txt, fuzziness: 'AUTO'}}}],
                filter: [{term: {project_id: Project.current.id}},
                         {term: {type: 'cards'}}]
            }
        },
        _source: %w(number name card_type_name),
        size: 5000
    }
  end

  def parsed_result_for_old_es(hit)
    {
        :value => hit['fields']['number'][0],
        :label => hit['fields']['name'][0],
        :type => hit['fields']['card_type_name'][0]
    }
  end

  def parsed_result_for_new_es(hit)
    {
        :value => hit['_source']['number'],
        :label => hit['_source']['name'],
        :type => hit['_source']['card_type_name']
    }
  end

  def recent_search_query_for_old_es
    {
        :fields => ["number", "name", "card_type_name"],
        :sort => [{"_timestamp" => {:order => "desc"}}, {"number" => {:order => "desc"}}],
        :query => {
            :filtered => {
                :query => {
                    :match_all => {}
                },
                :filter => {
                    :term => {
                        :project_id => Project.current.id
                    }
                }
            }
        }
    }
  end

  def recent_search_query_for_new_es
    {
        query: {
            bool: {
                must: [{match_all: {}}],
                filter: [{term: {project_id: Project.current.id}},
                         {term: {type: 'cards'}}]
            }
        },
        _source: %w(number name card_type_name),
        sort: [{timestamp: {order:'desc'}},{number: {order: 'desc'}}],
        size: 5000
    }
  end

  def search(query)
    result = ElasticSearch.search({:size => 5000}, query, Project.current.search_index_name, "cards")
    r = result['hits']['hits'].map do |hit|
      MingleConfiguration.saas? ? parsed_result_for_new_es(hit) : parsed_result_for_old_es(hit)
    end

    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end
end
