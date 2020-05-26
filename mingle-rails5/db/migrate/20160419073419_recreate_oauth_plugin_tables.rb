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

class RecreateOauthPluginTables < ActiveRecord::Migration[5.0]

  def self.up
    create_table :oauth_clients do |t|
      t.string :name
      t.string :client_id
      t.string :client_secret
      t.string :redirect_uri

      t.timestamps
    end

    create_table :oauth_tokens do |t|
      t.string :user_id
      t.integer :oauth_client_id
      t.string :access_token
      t.string :refresh_token
      t.integer :expires_at

      t.timestamps
    end

    create_table :oauth_authorizations do |t|
      t.string :user_id
      t.integer :oauth_client_id
      t.string :code
      t.integer :expires_at

      t.timestamps
    end
  end

  def self.down
    drop_table :oauth_clients
    drop_table :oauth_tokens
    drop_table :oauth_authorizations
  end

end
