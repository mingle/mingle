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

class SaasTos < ActiveRecord::Base

  def self.accept( user )
    create_instance_if_needed
    saas_tos = SaasTos.first
    saas_tos.user_email = user.email
    saas_tos.accepted = true
    saas_tos.save!
    Cache.put('saas_tos', saas_tos)
  end

  def self.accepted?
    Cache.get('saas_tos') do
      create_instance_if_needed
      SaasTos.first.accepted
    end
  end

  def self.clear_cache!
    Cache.delete 'saas_tos'
  end

  private
  def self.create_instance_if_needed
    saas_tos = SaasTos.first
    unless saas_tos
      SaasTos.create!(:accepted => false)
    end
  end
end
