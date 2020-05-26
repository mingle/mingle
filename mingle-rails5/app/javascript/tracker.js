/*
*  Copyright 2020 ThoughtWorks, Inc.
*
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/
export default class Tracker {
  constructor(metricsData, mixpanel) {
    this.enabled = metricsData && metricsData.enabled;
    this.mixpanel = mixpanel;
    if (this.enabled) {
      this.mixpanel.init(metricsData.api_key);
      this.mixpanel.register(metricsData.meta_data);
      this.mixpanel.identify(metricsData.user_id);
    }
  }

  track(name, data) {
    if (this.enabled) {
      this.mixpanel.track(name, data);
    }
  }
}
