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

module FeedHelper
    
  ATOM_STYLE_CHANGED = "background-color: LightGoldenRodYellow;"
  
  def bind_font(html, styles = {})
    styles = {'font-family' => 'Verdana'}.merge(styles)
    "<div style='#{styles.inject(''){|memo, entry| memo << "#{entry[0]}: #{entry[1]};"; memo}}'>#{html}</div>"
  end
  
  def created_or_changed(event)
    event.first? ? 'created by' : 'changed by'
  end

  def history_atom_url(request_params)
    request_params_query_string = history_filter_query_string(request_params)
    if authorized?(:controller => 'history', :action => 'subscribe')
      history_encrypted_feed_url(:format => 'atom', :project_id => @project.identifier, :encrypted_history_spec => @project.encrypt(request_params_query_string))
    else
      ret = history_plain_feed_url(:format => 'atom', :project_id => @project.identifier) 
      ret << '?' << request_params_query_string if request_params_query_string
      ret
    end
  end
  
  def history_filter_query_string(options)
    HistoryFilterParams.new(options).serialize
  end

end
