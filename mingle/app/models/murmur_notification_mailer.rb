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

class MurmurNotificationMailer < ActionMailer::Base
  include UrlWriterWithFullPath, MailerHelper, ActionView::Helpers::TextHelper, ReplyToMurmurEmailHelper, MurmurNotificationHelper
  add_template_helper(ApplicationHelper)
  add_template_helper(MurmurNotificationHelper)

  def notify(users, project, murmur)
    content_type 'text/html'
    bcc users.map(&:email).reject(&:blank?)
    from murmur_sender(murmur.author.name_and_login)
    subject murmur_subject(murmur, project)
    reply_to(unique_reply_to_email(murmur, users.first)) if MingleConfiguration.saas?
    body :murmur => murmur, :project => project, :user => users.first
  end

  private

  def murmur_subject(murmur, project)
    card_info = has_origin?(murmur) ? "#{murmur.origin.prefixed_number} in " : ''

    "[Mingle] You have been murmured from #{card_info}#{project.name}"
  end
end
