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

class DailyHistoryChartProcessor < Messaging::Processor
  QUEUE = 'mingle.daily_history_chart.single'

  def self.send_message(project, content_provider, chart_raw_content)
    message = Messaging::SendingMessage.new(:project_id => project.id,
      :content_provider_type => content_provider.class.name,
      :content_provider_id => content_provider.id,
      :chart_raw_content => chart_raw_content)
    Rails.logger.debug { "send daily history chart processing message: #{message.inspect}"}
    self.new.send_message(QUEUE, [message])
  end

  def on_message(message)
    Rails.logger.debug { "processing daily history chart processing message: #{message.inspect}"}
    project_id = message[:project_id]
    chart_raw_content = message[:chart_raw_content]
    content_provider_type = message[:content_provider_type]
    content_provider_id = message[:content_provider_id]
    Project.with_active_project(project_id) do |project|
      content_provider = content_provider_type.constantize.find_by_id(content_provider_id)
      chart = Chart.extract(chart_raw_content, 'daily-history-chart', 1, :content_provider => content_provider)
      Rails.logger.info "****Generating cache data for #{content_provider_id}*****"
      chart.generate_cache_data
    end
  end
end
