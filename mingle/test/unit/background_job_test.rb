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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class BackgroundJobTest < ActiveSupport::TestCase

  def setup
    @origin = MingleConfiguration.multitenant_messaging
    MingleConfiguration.multitenant_messaging = nil
    @alarms = []
  end

  def teardown
    MingleConfiguration.multitenant_messaging = @origin
  end

  class BgSpecificError < RuntimeError
  end

  def test_should_not_hide_background_job_error
    job_activity = Proc.new do
      raise BgSpecificError.new
    end
    job = BackgroundJob.new(job_activity)
    assert_raise BgSpecificError do
      job.run_once
    end
  end

  def test_should_call_the_task_in_run_once
    ran = false
    BackgroundJob.new(lambda { ran = true }).run_once
    assert ran
  end

  def test_should_publish_alarm_when_there_is_error_raised
    e = BgSpecificError.new
    assert_raise BgSpecificError do
      BackgroundJob.new(lambda { raise e }, 'worker', self).run_once
    end

    assert_equal 1, @alarms.size
    assert_equal(e, @alarms.first[:error])
    assert_equal({:task => 'worker'}, @alarms.first[:context])
  end

  def notify(error, context)
    @alarms << {:error => error, :context => context}
  end

end
