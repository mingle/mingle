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

class CardImportPublisher
  include Messaging::Base

  attr_reader :asynch_request

  def initialize(project, user, tab_separated_import_preview_id, mapping_overrides, ignores, tree_configuration_id)
    @asynch_request = user.asynch_requests.create_card_import_asynch_request(project.identifier)
    @message = message(project, user, tab_separated_import_preview_id, mapping_overrides, ignores, tree_configuration_id)
  end

  def publish_message
    send_message(CardImportProcessor::QUEUE, [@message])
    @message.dup
  end

  private

  def message(project, user, tab_separated_import_preview_id, mapping_overrides, ignores, tree_configuration_id)
    message_params = {
        :project_id                 => project.id,
        :user_id                    => user.id,
        :request_id                 => @asynch_request.id,
        :tab_separated_import_preview_id => tab_separated_import_preview_id,
        :mapping                    => make_indices_xml_friendly(mapping_overrides, 'mapping'),
        :ignore                     => make_indices_xml_friendly(ignores, 'ignore'),
        :tree_configuration_id      => tree_configuration_id
    }.delete_if {|k,v| v.nil?}

    sending_message = Messaging::SendingMessage.new(message_params)
    @asynch_request.update_attributes(:message => message_params)
    sending_message
  end

  def make_indices_xml_friendly(hash, index_prefix)
    return if hash.blank?
    return hash unless Hash === hash
    hash.inject({}) do |xml_friendly_hash,(key,value)|
      xml_friendly_hash[ (key.to_s =~ /^\d/) ? "#{index_prefix}-#{key}" : key] = value
      xml_friendly_hash
    end
  end
end
