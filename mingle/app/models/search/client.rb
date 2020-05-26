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

module Search

  class Client
    PER_PAGE_DEFAULT = 1000

    # options:
    #  => highlight, default true
    #  => results_limit, default PER_PAGE_DEFAULT
    # todo: clean the options to use named param
    def initialize(options={})
      @highlight = from_params_or_default(options, :highlight, true)
      @results_limit = from_params_or_default(options, :results_limit, PER_PAGE_DEFAULT)
    end

    # params:
    #  => q, search terms
    #  => search_fields, default none, array, e.g. ['number', 'name']
    #  => type, default empty, string, one of cards, pages, murmurs
    # todo: clean the options to use named param
    def find(params, options={})
      if String === params
        params = { :q => params }
      end

      return empty_result if params[:q].blank?

      query_options = { :highlight => @highlight }
      query_options.merge!(:search_fields => params[:search_fields] || default_search_fields)
      query_options.merge! options
      response = search(Search::Query.new(params[:q], query_options.merge(type: params[:type], size: @results_limit)), params[:type])

      search_result = Result::ResultSet.new(@results_limit, response['hits']['total'])
      response['hits']['hits'].each do |hit|
        search_result << Result.for(hit)
      end
      search_result
    rescue ElasticSearch::ElasticError => e
      Kernel.log_error(e, "Problem searching for #{params[:q]}")
      empty_result
    end

    private

    def empty_result
      Result::ResultSet.new
    end

    def search(query_body, type)
      ElasticSearch.search({:size => @results_limit}, query_body.to_hash, index_name, type)
    end

    def index_name
      Project.current.search_index_name
    end

    def from_params_or_default(options, key, default=nil)
      options.has_key?(key) ? options[key] : default
    end

    def default_search_fields
      MingleConfiguration.saas? ? [] : %w(name^10 _all)
    end
  end

end
