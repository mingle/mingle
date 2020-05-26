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

class CardImportProcessor < Messaging::UserAwareProcessor
  QUEUE = 'mingle.card_import'
    
  def on_message(message)
    Kernel.logger.debug "====DEBUG===== CardImportProcessor processing: #{message.inspect}"
    ignore = message[:ignore] ? message[:ignore].keys.map { |key| key[/\d+/].to_i } : []
    mapping_overrides = message[:mapping].keys.sort_by { |key| key[/\d+/].to_i }.collect { |key| message[:mapping][key] } if message[:mapping]
    sending_message = Messaging::SendingMessage.new(message.body_hash.merge(:mapping => mapping_overrides, :ignore => ignore))
    CardImporter.fromActiveMQMessage(sending_message).process!
  end
  
end
