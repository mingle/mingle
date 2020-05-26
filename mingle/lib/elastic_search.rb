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

require 'elastic_search/http'
require 'elastic_search/indexes'
require 'elastic_search/indexing'
require 'elastic_search/active_record_ext'
require 'elastic_search/aws_es'

class ElasticSearch

  class << self

    alias :request_with_enabled :request
    alias :index_missing_with_enabled? :index_missing?

    def request_with_disabled(*args, &block)
      Kernel.logger.debug("ElasticSearch is disabled, ignore request: #{args.inspect}")
      raise ElasticSearch::DisabledException.new("Elastic search is disabled")
    end

    def index_missing_with_disabled?
      false
    end

    def disable
      alias :request :request_with_disabled
      alias :index_missing? :index_missing_with_disabled?
    end

    def enable
      alias :request :request_with_enabled
      alias :index_missing? :index_missing_with_enabled?
    end
  end


  class ElasticError < StandardError
    def self.from_response(error)
      return IndexAlreadyExistsException.new(error) if error =~ /IndexAlreadyExistsException/
      return SearchPhaseExecutionException.new(error) if error =~ /SearchPhaseExecutionException/
      return IndexMissingException.new(error) if error =~ /IndexMissingException/
      self.new(error)
    end
  end

  class NetworkError < ElasticError; end
  class IndexAlreadyExistsException < ElasticError; end
  class SearchPhaseExecutionException < ElasticError; end
  class IndexMissingException < ElasticError; end
  class DisabledException < ElasticError; end
end

ActiveRecord::Base.send(:include, ElasticSearch::ActiveRecordExt)
