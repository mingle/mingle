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

require 'ostruct'
class Session < ActiveRecord::SessionStore::Session
  cattr_accessor :expires
  def self.expires
    @@expires ||= 1.week
  end

  def self.find_by_session_id(session_id)
    find_by_session_id_and_not_expired(session_id)
  rescue => e
    Kernel.log_error(e, 'find_by_session error')
    OpenStruct.new(:session_id => 'session_id', :data => {})
  end

  def self.date_format
    #SimpleDateFormat is not threadsafe, create it when use it
    java::text::SimpleDateFormat.new("yyyy-MM-dd HH:mm:ss")
  end

  def self.find_by_session_id_and_not_expired(session_id)
    updated_at = (::Clock.now - self.expires)
    now = ::Clock.now
    if RUBY_PLATFORM =~ /java/
      conn = self.connection
      sql = "SELECT * FROM sessions WHERE session_id = ? AND updated_at > ?"
      statement = conn.jdbc_connection.prepareStatement(sql)
      begin
        statement.setString(1, session_id)

        updated_at = java::sql::Timestamp.new(date_format.parse(updated_at.strftime('%Y-%m-%d %H:%M:%S')).getTime)
        statement.setTimestamp(2, updated_at)
        result_set = statement.executeQuery
        logger.debug { "  SQL with prepareStatement (#{ (Clock.now - now) * 1000 }ms): SQL: #{sql} BINDING: #{[session_id, updated_at].inspect} " }

        #    Column   |            Type             |                       Modifiers
        # ------------+-----------------------------+-------------------------------------------------------
        #  id         | integer                     | not null default nextval('sessions_id_seq'::regclass)
        #  session_id | character varying(255)      | not null
        #  data       | text                        |
        #  updated_at | timestamp without time zone | not null
        begin
          if result_set.next
            id = result_set.getInt("ID");
            data = result_set.getString("DATA");
            updated_at = result_set.getTimestamp("UPDATED_AT").to_s
            instantiate('id' => id, 'data' => data, 'updated_at' => updated_at, 'session_id' => session_id)
          end
        ensure
          result_set.close
        end
      ensure
        statement.close
      end
    else
      self.find(:first, :conditions => ['session_id=? AND updated_at > ?', session_id, updated_at.utc])
    end
  end

  def self.clean_expired_sessions
    unless Install::InitialSetup.need_install?
      logger.info "Clean expired sessions"
      self.delete_all(['updated_at < ?', ::Clock.now - self.expires])
    end
  end

  validates_presence_of :session_id

end
