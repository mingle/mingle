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
import ProgramSettings from '../components/program_settings/ProgramSettings'
import createStore from "../stores/program_settings_store";
import ObjectiveTypesService from "../services/objective_types_service";
import ProgramPropertiesService from "../services/program_properties_service";
import Vuex from 'vuex';

Vue.use(VModal, {dynamic: true});
Vue.use(Vuex);

document.addEventListener('DOMContentLoaded', () => {

  let programSettingsContainer = document.getElementById("program_settings");
  if (programSettingsContainer) {
    let objectiveTypes = JSON.parse(programSettingsContainer.dataset.objectiveTypes);
    let properties = JSON.parse(programSettingsContainer.dataset.properties);
    let program = JSON.parse(programSettingsContainer.dataset.program);
    let services = {objectiveTypes: new ObjectiveTypesService(program.identifier, document.querySelector('meta[name="csrf-token"]').content), programProperties: new ProgramPropertiesService(program.identifier, document.querySelector('meta[name="csrf-token"]').content)};
    new Vue({
      el: programSettingsContainer,
      store: createStore(services, {objectiveTypes: objectiveTypes, properties: properties}),
      components:{ProgramSettings},
      template: '<ProgramSettings/>'
    });
  }
});