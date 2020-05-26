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

class FeedsCache
  include CachingUtils

  def initialize(feeds, site_url)
    @feed = feeds
    @site_url = site_url
  end

  def get
    read || write
  end

  def read
    Cache.get(cache_key)
  end

  alias :cached? :read

  def write
    render_feeds.tap do |content|
      Cache.put(cache_key, content)
      Cache.put(digest_key, digest(content))
    end
  end

  def content_digest
    Cache.get(digest_key) { digest(render_feeds) }
  end

  private

  def cache_key
    digest(join(@feed.deliverable.class.name,
                @feed.deliverable.identifier,
                @feed.deliverable.cache_key.feed_key.to_s,
                @site_url,
                CONTEXT_PATH,
                "v1", # use this to invalidate when making structural changes
                "feeds#{@feed.last_page? ? '' : @feed.page}.cache"))
  end

  def digest_key
    cache_key + "/file_digest"
  end

  def render_feeds
    @cached_feed_content ||= do_render_feeds
  end

  def do_render_feeds
    controller = FeedsController.new
    controller.response = ActionController::Response.new
    controller.instance_variable_set(:@project, @feed.deliverable)
    view = FeedView.new(@feed.deliverable, controller, @site_url)
    view.capture do
      view.render(:partial => 'feeds/feed.rxml',  :locals => {:feed => @feed, :view_helper => view})
    end
  end
end
