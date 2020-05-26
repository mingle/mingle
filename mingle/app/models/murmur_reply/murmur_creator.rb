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

class MurmurCreator
  include UserAccess, MetricsHelper, AttachmentsHelper
   EMAIL_SOURCE = 'email'

  def initialize(auto_reply_notifier=MurmurAutoReplyNotification.new)
    @auto_reply_notifier = auto_reply_notifier
  end

  def create(murmur_data)
    return unless MingleConfiguration.saas?

    murmur = Murmur.find_by_id(murmur_data.murmur_id)
    if !murmur
      send_auto_reply_notification(murmur_data, :invalid_operation)
      return nil
    end
    murmur.project.with_active_project do |project|
      User.with_current_by_id(murmur_data.user_id) do |user|
        if is_card_murmur?(murmur)
          create_card_murmur(murmur, murmur_data, project)
        else
          create_global_murmur(murmur, murmur_data, project)
        end
      end
    end
  end

  private
  def is_card_murmur?(murmur)
    murmur.is_a?(CardCommentMurmur)
  end

  def user_authorized?(project, action)
    authorized_for?(project, action)
  end

  def valid_user_access?(project, murmur_data, action)
    if !user_authorized?(project, action)
      send_auto_reply_notification(murmur_data, :invalid_operation)
      return false
    end
    return true
  end

  def empty_murmur_text?(murmur, murmur_data)
    empty_murmur_text = murmur_data.scrubbed_murmur_text.empty?
    send_auto_reply_notification(murmur_data, :empty_murmur_error) if empty_murmur_text
    empty_murmur_text
  end

  def valid_murmur_creation?(murmur, murmur_data, project)
    valid_user_access?(project, murmur_data, 'murmurs:create') && !empty_murmur_text?(murmur, murmur_data)
  end

  def card_exists?(murmur, murmur_data)
    card_exists = !murmur.origin_id.nil?
    send_auto_reply_notification(murmur_data, :invalid_operation) if !card_exists
    card_exists
  end

  def create_global_murmur(murmur, murmur_data, project)
    return nil unless valid_murmur_creation?(murmur, murmur_data, project)
    send_auto_reply_attachments_notification(murmur_data)
    murmur_reply = project.murmurs.create!({:murmur => murmur_data.scrubbed_murmur_text, :author_id => murmur_data.user_id, :replying_to_murmur_id => murmur.id, :source => EMAIL_SOURCE})
    add_monitoring_event('create_global_murmur_via_email', {'project_name' => murmur.project.name, 'email_client_info' => murmur_data.email_client_info})
    murmur_reply
  end

  def create_card_murmur(murmur, murmur_data, project)
    return nil unless valid_user_access?(project, murmur_data, 'cards:add_comment') && card_exists?(murmur, murmur_data)
    card = murmur.origin
    if (empty_murmur_text?(murmur, murmur_data))
      if (murmur_data.attachment_uploaders.size > 0)
        send_auto_reply_notification(murmur_data, :attachments_on_empty_murmur)
        create_card_attachments(card, project, murmur_data.attachment_uploaders)
      end
      return nil
    end
    card.add_comment({:content => murmur_data.scrubbed_murmur_text, :replying_to_murmur_id => murmur.id, :source => EMAIL_SOURCE})
    card.save!
    create_card_attachments(card, project, murmur_data.attachment_uploaders)
    add_monitoring_event('create_card_murmur_via_email', {'project_name' => card.project.name, 'email_client_info' => murmur_data.email_client_info})
    card.origined_murmurs.last
  end

  def create_card_attachments(card, project, attachment_uploaders)
    return unless MingleConfiguration.saas? && attachment_uploaders.present?
    succeeded = 0
    failed = 0
    attachment_uploaders.each do |attachment_uploader|
      begin
        s3 = attachment_uploader.execute
        create_attachment_and_attaching(project, card, nil, s3)
        succeeded += 1
      rescue StandardError => e
        failed += 1
        Rails.logger.error("Failed to execute murmur attachment upload. (attachment):#{attachment_uploader.inspect}  error:#{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
    event_properties = {'project_name' => card.project.name}
    event_properties['failed'] = failed if failed > 0
    event_properties['succeeded'] = succeeded if succeeded > 0
    add_monitoring_event('create_card_attachment_via_email', event_properties)
  end

  def send_auto_reply_attachments_notification(murmur_data)
    if MingleConfiguration.saas? && murmur_data.attachment_uploaders.present? && murmur_data.attachment_uploaders.size >= 1
      send_auto_reply_notification(murmur_data, :global_murmur_attachment_error)
    end
  end

  def send_auto_reply_notification(murmur_data, error_type)
    @auto_reply_notifier.send_auto_reply(murmur_data.recipient, murmur_data.from, murmur_data.subject, error_type) if @auto_reply_notifier
  end
end
