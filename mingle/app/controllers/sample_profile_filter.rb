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

require "profile_reporter"

class SampleProfileFilter
  def logger
    Rails.logger
  end

  def filter(controller, &block)
    if report = profiling_report(controller)
      yield
      logger.info("Found profiling report saved, render the report in this request's response")
      render_report(controller, report)
      return
    end

    is_saas_system_user = MingleConfiguration.saas? && User.current.system?
    is_installer_mingle_user = MingleConfiguration.installer? && !User.current.anonymous?

    if is_saas_system_user || is_installer_mingle_user
      sp = controller.params[:__sp] || referer_sp(controller)
      return yield if !sp || sp !~ /\d+/
      interval = sp.to_i * 1.0 / 1000
      logger.
        info("profiling the request with sampling interval #{interval} sec(s)")
      report_output = ::ProfileReporter.profile(interval) do
        yield
      end
      render_report(controller, report_output.string)
    else
      yield
    end
  end

  def render_report(controller, report_output)
    if report_output
      if controller.response.status.to_s =~ /^302 /
        logger.info("It's a redirect response, save profiling report")
        save_profiling_report(controller, report_output)
      else
        logger.info("Append profiling report to response body")
        (controller.response.body += "<!-- #{report_output} -->".html_safe)
      end
    end
  end

  def referer_sp(controller)
    return nil if controller.request.referer.blank?
    referer = URI(controller.request.referer) rescue nil
    if query = referer.try(:query)
      sp = CGI::parse(query)['__sp']
      sp.is_a?(Array) ? sp.first : sp
    end
  end

  def profiling_report(controller)
    flash(controller)[:profiling_report]
  end

  def save_profiling_report(controller, report)
    flash(controller)[:profiling_report] = report
  end

  def flash(controller)
    controller.send(:flash)
  end
end
