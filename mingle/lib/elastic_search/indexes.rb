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


class ElasticSearch

  class << self
    def index_name
      MingleConfiguration.search_index_name ||  MingleConfiguration.app_namespace || "mingle"
    end

    def index_missing?(index_key=index_name)
      stats = ElasticSearch.request :get, "/_stats"
      stats["indices"][index_key].nil?
    end

    def index_has_no_documents?(index_key=index_name)
      stats = ElasticSearch.request :get, "/_stats"
      stats["indices"][index_key]["total"]["docs"]["count"].to_i == 0
    end
  end
end
