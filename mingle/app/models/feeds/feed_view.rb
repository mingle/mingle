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

class FeedView < ActionView::Base
  include ApplicationHelper, UrlWriterWithFullPath, FeedsHelper, ActionView::Helpers::CacheHelper, UrlUtils

  def initialize(deliverable, controller, site_url)
    super(File.join(Rails.root, "app", "views"), {})
    @controller = controller
    @url_options = url_as_url_options(site_url)
    @url_options.merge!( :project_id => deliverable.identifier ) if deliverable.class.name == Deliverable::DELIVERABLE_TYPE_PROJECT
    self.template_format = :xml
  end

  def default_url_options(options=nil)
    @url_options
  end
end
