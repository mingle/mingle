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

class MurmurReplyProcessor
  def self.run_once(options={})
    return unless MingleConfiguration.saas?

    murmur_email_poller = MurmurEmailPoller.new
    murmur_email_poller.on_email(options[:batch_size]) do |murmur_data|
      begin
        MurmurCreator.new.create(murmur_data)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("Failed creating murmur email reply. (murmur_data):#{murmur_data.inspect} error:#{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
