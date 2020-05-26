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

module MurmurNotificationHelper
  def notification_style(murmur, discussion, user)
    border_style = murmur == discussion.first ? '' : 'border-top: 1px solid #DFDFDF; padding-top: 1px; margin-top: 1px;'
    background_color = "background-color: #{murmur_highlight_color(murmur, discussion, user)};"
    border_style + background_color
  end

  def murmur_style(murmur, discussion)
    padding_style = 'padding: 15px 15px 5px 15px;'
    font_size = murmur == discussion.first ? 'font-size: 1.1em;' : ''
    padding_style + font_size
  end

  def murmured_at(murmur)
    @project.format_time(murmur.created_at)
  end

  def murmur_url(murmur, url_options)
    is_card_murmur?(murmur) ? url_options.merge(:controller => 'cards', :action => 'show', :number => murmur.origin.number, :project_id => murmur.project.identifier) : url_options.merge(:controller => 'projects', :action => 'show', :murmur_id => murmur.id, :project_id => murmur.project.identifier)
  end

  def format_murmur_notification(discussion_item_html)
    parsed_html = Nokogiri::HTML.parse(discussion_item_html, 'UTF-8')
    inlined_style_html = inline_user_mention_styles(parsed_html)
    formatted_murmur_notification_html = card_link_tooltip(inlined_style_html)
    formatted_murmur_notification_html.xpath('//@class').remove
    formatted_murmur_notification_html.css('body').inner_html.gsub('&amp;','&')
  end

  def discussion(murmur)
    discussion = if has_origin? murmur
                   murmur.origin.discussion
                 else
                   murmur.conversation ? murmur.conversation.murmurs : [murmur]
                 end
    discussion.select { |discussion_murmur| discussion_murmur.created_at <= murmur.created_at }.sort_by(&:created_at).reverse
  end

  def has_origin?(murmur)
    murmur.respond_to?(:origin) && murmur.origin
  end

  private

  def inline_user_mention_styles(parsed_html)
    parsed_html.css('a.at-highlight').each do |user_mention|
      user_mention['style'] = 'color: #3FBEEA; text-decoration: none;'
    end
    parsed_html
  end

  def card_link_tooltip(parsed_html)
    parsed_html.css('a.card-tool-tip').each do |card_link|
      card_number = card_link.text[1..-1].to_i
      card = Card.find_by_number(card_number)
      card_link.set_attribute('title', card ? ERB::Util::html_escape(card.name) : 'Card not found!')
    end
    parsed_html
  end

  def murmur_highlight_color(murmur, discussion, user)
    if murmur == discussion.first
      '#F5F5F5'
    elsif murmur.respond_to?(:mentioned_users) && murmur.mentioned_users.include?(user)
      '#E9F2F8'
    else
      '#FFFFFF'
    end
  end

  private

  def is_card_murmur?(murmur)
    (murmur.respond_to?(:origin) && murmur.origin.number)
  end

end
