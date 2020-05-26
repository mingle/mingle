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
import assert from 'assert';
import sinon from 'sinon';
import Vue from 'vue';
import Vuex from 'vuex';
import createProgramTeamStore from '../../../app/javascript/stores/program_team_store';

Vue.use(Vuex);
let sandbox = sinon.createSandbox();
let programTeamService = {};

describe('ObjectiveStore', function () {
  beforeEach(() => {
    this.members = [
      {name:'User1',login:'user1', role:'Program administrator', email:'user1@example.com'},
      {name:'User2',login:'user2', role:'Program administrator', email:'user2@example.com'},
      {name:'User3',login:'user3', role:'Program administrator', email:'user3@example.com'}
    ];
    this.currentUser = {name:'User1',login:'user1', role:'Program administrator', admin:true};
    let roles = [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}];
    this.programteamStore  = createProgramTeamStore(this.members, roles, this.currentUser, programTeamService);
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should have users state in programTeam module', () => {
    assert.deepEqual(this.members, this.programteamStore.state.programTeam.members)
  });

  it('should have currentUser state in programTeam module', () => {
    assert.deepEqual(this.currentUser, this.programteamStore.state.currentUser)
  });
});
