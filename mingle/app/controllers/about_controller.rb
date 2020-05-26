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

class AboutController < ApplicationController
  include SkipAuthentication
  allow :get_access_for => [:index, :info, :abtesting_info, :contact_us, :thirdparty]

  def index
    @title = 'About'
  end

  def info
    render :xml => { :version => MINGLE_VERSION, :revision => MINGLE_REVISION }.to_xml(:root => 'info')
  end

  def abtesting_info
    render :xml => ABTesting.group_info.to_xml(:root => 'info')
  end

  def contact_us
    add_monitoring_event(:open_contact_us)
    render_in_lightbox 'shared/contact_us'
  end

  def thirdparty
    @thirdparties = JSON.parse(File.read("NOTICE/thirdparty.json"))
  end

end
