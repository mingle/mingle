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

class FeedsCachePopulatingProcessor < Messaging::DeduplicatingProcessor
  QUEUE = "mingle.feed_cache_populating"
  route :from => MingleEventPublisher::CARD_VERSION_QUEUE,      :to => QUEUE
  route :from => MingleEventPublisher::PAGE_VERSION_QUEUE,      :to => QUEUE
  route :from => MingleEventPublisher::REVISION_QUEUE,          :to => QUEUE
  route :from => MingleEventPublisher::OBJECTIVE_VERSION_QUEUE, :to => QUEUE
  route :from => MingleEventPublisher::CARD_COPY_QUEUE,         :to => QUEUE

  def do_process_message(m)
    if m[:project_id] && project = Project.find_by_id(m[:project_id])
      project.with_active_project do
        urls_for_feeds.each do |url|
          write_cache(project, url)
        end
      end
    end
    if m[:deliverable_id] && program = Program.find_by_id(m[:deliverable_id])
      urls_for_feeds.each do |url|
        write_cache(program, url)
      end
    end
  end

  def identity_hash(message)
    {:project_id => message[:project_id].to_s}
  end

  private

  def write_cache(deliverable, url)
    MingleConfiguration.with_site_u_r_l_overridden_to(url) do
      cache = FeedsCache.new(Feeds.new(deliverable), url)
      cache.write
    end
  end

  def urls_for_feeds
    [MingleConfiguration.site_url, MingleConfiguration.api_url].uniq
  end


end
