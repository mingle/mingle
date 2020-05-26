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

class HttpStub
  attr_reader :requests
  def initialize
    reset
  end

  def post(url, options={})
    @requests << OpenStruct.new({:http_method => :post, :url => url, :body => options[:body], :headers => options[:headers]})
    raise @errors[:post] if(@errors[:post])
    @post_responses[url]
  end

  def put(url, options={})
    @requests << OpenStruct.new({:http_method => :put, :url => url, :body => options[:body], :headers => options[:headers]})
    raise @errors[:put] if(@errors[:put])
  end

  def get(url, options={})
    @requests << OpenStruct.new({:http_method => :get, :url => url, :headers => options[:headers]})
    raise @errors[:get] if(@errors[:get])
    @get_responses[url] || raise('404')
  end

  def delete(url, options={})
    @requests << OpenStruct.new({:http_method => :delete, :url => url, :headers => options[:headers]})
    raise @errors[:delete] if(@errors[:delete])
  end

  def register_get_response(url, response)
    @get_responses[url] = response
  end

  def register_post_response(url, response)
    @post_responses[url] = response
  end

  def last_request
    @requests.last
  end

  def set_error(es)
    @errors = es
  end

  def reset
    @requests = []
    @errors = {}
    @get_responses = {}
    @post_responses = {}
  end
end
