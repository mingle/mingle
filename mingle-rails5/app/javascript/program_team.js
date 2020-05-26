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
import VueTables from 'vue-tables-2'
import ProgramTeam from './components/ProgramTeam.vue'
import ProgramTeamService from "./services/program_team_service";
import UserService from "./services/user_service";
import createStore from "./stores/program_team_store";
import Vuex from 'vuex';
import mingleTheme from "./vue-table-mingle-theme"
import mingleTemplate from "./vue-table-mingle-template"
import vClickOutside from 'v-click-outside'
import "src/common.scss";

Vue.use(Vuex);
Vue.use(vClickOutside);
Vue.use(VueTables.ClientTable,{},false, mingleTheme,mingleTemplate);

document.addEventListener('DOMContentLoaded', () => {

  let programTeam = document.getElementById("program_team");
  if (programTeam) {
    let members = JSON.parse(programTeam.dataset.members).reduce((members, member) => { members[member.login] = member; return members  },{}),
        toggles = JSON.parse(programTeam.dataset.toggles),
        roles = JSON.parse(programTeam.dataset.roles),
        baseUri = programTeam.dataset.programMembershipBaseUrl,
        currentUser = JSON.parse(programTeam.dataset.currentUser),
        userService = new UserService('/api/internal/users',document.querySelector('meta[name="csrf-token"]').content, programTeam.dataset.programId),
        programTeamService = new ProgramTeamService(baseUri, document.querySelector('meta[name="csrf-token"]').content);
        let services = {'programTeamService': programTeamService, 'userService': userService};
    new Vue({
      el: programTeam,
      store: createStore(members, roles, currentUser, services, toggles),
      render(h) {
        return h(ProgramTeam)
      }
    });
  }
});