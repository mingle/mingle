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
import Vue from 'vue/dist/vue.js';
import VModal from 'vue-js-modal';
import VueResource from 'vue-resource';
import Vuex from 'vuex'
import Tracker from './tracker'
let Mixpanel = require('mixpanel-browser');

import createStore from './stores/objectives'
import BacklogWall from './components/BacklogWall';
import ObjectivesService from './services/objectives'
import vSelect from 'vue-select';
Vue.component('v-select', vSelect);

Vue.use(VModal, {dynamic: true});
Vue.use(VueResource);
Vue.use(Vuex);

document.addEventListener('DOMContentLoaded', () => {
  function initializeTracker() {
    let pagesEl = document.getElementsByTagName("body")[0];
    if (pagesEl) {
      let metricsData = JSON.parse(pagesEl.dataset.metrics);
      return new Tracker(metricsData, Mixpanel);
    } else {
      return new Tracker({}, Mixpanel);
    }
  }

  let pagesEl = document.getElementById("objectives");
  if (pagesEl) {
    let objectivesData = JSON.parse(pagesEl.dataset.objectives),
        nextObjectiveNumber = JSON.parse(pagesEl.dataset.nextObjectiveNumber),
        toggles = pagesEl.dataset.toggles ? JSON.parse(pagesEl.dataset.toggles) : {},
        defaultObjectiveType = JSON.parse(pagesEl.dataset.defaultObjectiveType),
        objectivesBaseUrl = pagesEl.dataset.objectivesBaseUrl,
        objectivesService = new ObjectivesService(
            objectivesBaseUrl,
            document.querySelector('meta[name="csrf-token"]').content,
          initializeTracker());

    new Vue({
      el: pagesEl,
      store: createStore(objectivesService, {
        objectives: objectivesData,
        nextObjectiveNumber: nextObjectiveNumber,
        toggles: toggles,
        defaultObjectiveType: defaultObjectiveType
      }),
      render(h) {
        return h(BacklogWall)
      }
    });
  }
});
