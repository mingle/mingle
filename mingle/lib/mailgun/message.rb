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

module Mailgun
  class Message
    include EmailHelper
    attr_accessor :from, :recipient, :subject, :storage_url,  :timestamp, :id

    def initialize(options={})
      @from = options[:from]
      @recipient = options[:recipient]
      @subject = options[:subject]
      @storage_url = options[:storage_url]
      @timestamp = options[:timestamp]
      @id = options[:id]
    end

    def self.create_from(item, domain)
      headers = item['message']['headers']
      options = {
        :from => TMail::Address.parse(headers['from'].to_ascii),
        :recipient => domain_recipient(item['message']['recipients'], domain),
        :subject => headers['subject'],
        :storage_url => item['storage']['url'],
        :timestamp => item['timestamp'],
        :id => item['id']
      }
      self.new(options)
    end

  end
end
