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

class Discussion
  attr_reader :card

  include Enumerable

  def initialize(card)
    @card = card
  end

  def [](index)
    ensure_discussion_loaded[index]
  end

  def each(&block)
    ensure_discussion_loaded.each(&block)
  end

  def first
    ensure_discussion_loaded.first
  end

  def last
    ensure_discussion_loaded.last
  end

  def size
    ensure_discussion_loaded.size
  end

  def count
    @card.murmurs.count + @card.all_comments_count
  end

  def murmurs
    load_discussion_without_cache
  end

  private

  def ensure_discussion_loaded
    @discussion ||= load_discussion_without_cache
  end

  def project
    @card.project
  end

  def load_discussion_without_cache
    murmurs = @card.origined_murmurs + @card.murmurs
    compare_hash = murmurs.inject({}) { |memo, m| memo[[m.author, m.murmur]] = m; memo }
    comments = @card.comments.map(&:murmur_like)
    comments_not_murmured = comments.reject do |cm|
      match = compare_hash[[cm.author, cm.murmur]]
      match && (match.created_at - cm.created_at).abs < 10.seconds
    end
    (murmurs + comments_not_murmured).sort_by(&:created_at).reverse
  end
end
