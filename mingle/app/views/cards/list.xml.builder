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

xml.instruct!
card_attrs = {'type' => 'array'}
card_attrs.merge!('page_count' => @view.paginator.page_count) if params[:show_page_count]

card_serialization_options = { :builder => xml, :version => params[:api_version], :view_helper => self }
card_serialization_options.merge!(:slack => true) if %w(true t 1).include?(params[:include_transition_ids])
xml.cards(card_attrs) do
  @view.cards.each do |card|
    cache_xml(Keys::CardXml.new.path_for(Project.current, card, params[:include_transition_ids])) do
      card.to_xml(card_serialization_options)
    end
  end
end
