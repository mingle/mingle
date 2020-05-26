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

class MingleSession < ActiveRecord::SessionStore::Session
  cattr_accessor :expires
  self.table_name = 'sessions'

  validates_presence_of :session_id

  def self.expires
    @@expires ||= 1.week
  end

  def self.find_by_session_id(session_id)
    find_by_session_id_and_not_expired(session_id)
  rescue => e
    Rails.logger.error("find_by_session_id error #{e.message}")
    OpenStruct.new(:session_id => 'session_id', :data => {})
  end

  def self.find_by_session_id_and_not_expired(session_id)
    updated_at = (::Clock.now - self.expires)
    where('session_id=? AND updated_at > ?', session_id, updated_at.utc.to_s(:db)).first
  end
end
