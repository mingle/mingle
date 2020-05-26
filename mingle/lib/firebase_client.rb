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

class FirebaseClient

  include RetryOnNetworkError

  attr_reader :base_url

  class Response
    attr_reader :url
    def initialize(httpresponse, url)
      @httpresponse = httpresponse
      @url = url
    end

    def success?
      code < 300
    end

    def body
      @httpresponse.body
    end

    def code
      @httpresponse.code
    end
  end

  def initialize(base_url, auth=nil)
    @base_url = base_url
    @auth = auth
  end

  def push(key, data)
    url = rest_url(key)

    with_retry do |retries, exception|
      log_failed_try_on_exception(url, data, "POST", retries, exception)
      data.merge!(:"fbPublishedAt" => {:".sv" => "timestamp"}) if data.is_a?(Hash)
      result = HTTParty.post(url,
        :body => data.to_json,
        :headers => { 'Content-Type' => 'application/json' })
      Response.new(result, url)
    end
  end

  def set(key, data)
    url = rest_url(key)

    with_retry do |retries, exception|
      log_failed_try_on_exception(url, data, "PUT", retries, exception)
      data.merge!(:"fbPublishedAt" => {:".sv" => "timestamp"}) if data.is_a?(Hash)
      result = HTTParty.put(url,
        :body => data.to_json,
        :headers => { 'Content-Type' => 'application/json' })
      Response.new(result, url)
    end
  end

  def get(key, query={})
    url = rest_url(key, query)

    with_retry do |retries, exception|
      log_failed_try_on_exception(url, nil, "GET", retries, exception)
      HTTParty.get(url, :headers => { 'Content-Type' => 'application/json' })
    end
  end

  def delete(key)
    url = rest_url(key)
    Rails.logger.info { "Firebase delete data at #{url}" }

    with_retry do |retries, exception|
      log_failed_try_on_exception(url, nil, "DELETE", retries, exception)
      result = HTTParty.delete(url, :headers => { 'Content-Type' => 'application/json' })
      Response.new(result, url)
    end
  end

  private

  def rest_url(key, query={})
    query.merge!({'auth' => @auth}) if @auth
    url = File.join(@base_url, key) + ".json"
    url += "?" + query.to_query if query.keys.size > 0
    url
  end

end
