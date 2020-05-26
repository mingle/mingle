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
import Vuex from 'vuex';
import {createLocalVue} from '@vue/test-utils'
import createProgramTeam from "../../../../../app/javascript/stores/modules/program_team/program_team";

let localVue = createLocalVue();
let sandbox = sinon.createSandbox();

let programTeamService = {
  bulkRemove: () => {
  },
  addMember: () => {
  },
  bulkUpdate: () => {
  }
};

let userService = {
  fetchUsers: () => {
  },
  fetchProjects: () => {
  }
};

let services = {'programTeamService': programTeamService, 'userService': userService};
localVue.use(Vuex);

describe('ProgramTeam Store Module', function () {
  beforeEach(() => {
    this.members = {
      user1: {name: 'User1', login: 'user1', role: 'Program administrator', email: 'user1@example.com'},
      user2: {name: 'User2', login: 'user2', role: 'Program administrator', email: 'user2@example.com'},
      user3: {name: 'User3', login: 'user3', role: 'Program administrator', email: 'user3@example.com'}
    };
    let roles = [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}];
    this.store = new Vuex.Store({
      modules: {
        programTeam: createProgramTeam(this.members, roles, services)
      }
    });
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('Initialization', () => {
    it('should have users state', () => {
      assert.deepEqual(this.members, this.store.state.programTeam.members);
    });

    it('should have usersFetched set to false', () => {
      assert.ok(!this.store.usersFetched);
    });
  });

  describe('Mutations', () => {
    describe('RemoveMembers', () => {
      it('should remove users from the members and add them to users', () => {
        assert.deepEqual(this.members, this.store.state.programTeam.members);
        assert.deepEqual([], this.store.state.programTeam.users);
        this.store.commit('removeMembers', ['user1', 'user2']);

        let members = {user3:{name: 'User3', login: 'user3', role: 'Program administrator', email: 'user3@example.com'}};
        assert.deepEqual(members, this.store.state.programTeam.members);

        let nonMembers = [
          {name: 'User1', login: 'user1', email: 'user1@example.com'},
          {name: 'User2', login: 'user2', email: 'user2@example.com'}
        ];
        assert.deepEqual(nonMembers, this.store.state.programTeam.users);
      });
    });

    describe('UpdateUsers', () => {
      it('should add only non members to users', () => {
        assert.deepEqual([], this.store.state.programTeam.users);

        this.store.commit('updateUsers', [{name: 'user 2', login: 'user2'}, {
          name: 'user 4',
          login: 'user4',
          email: 'user3@foo.com'
        }]);

        assert.deepEqual([{
          name: 'user 4',
          login: 'user4',
          email: 'user3@foo.com'
        }], this.store.state.programTeam.users);
      });
    });
    describe('addMember', () => {
      beforeEach(() => {
        this.store.state.programTeam.users = [{
          name: 'User 5',
          login: 'User5',
          light: false,
          email: 'user5@example.com'
        }];
      });

      it('should update role in the users state', () => {
        this.store.commit('updateRole', {login: 'User5', role: 'Program administrator'});

        let expectedUsers = [{
          name: 'User 5',
          login: 'User5',
          role: 'Program administrator',
          light: false,
          email: 'user5@example.com'
        }];
        assert.deepEqual(expectedUsers, this.store.state.programTeam.users);
      });

      it('should add member should add to the members state and remove from users', () => {
        let newMember = {
          name: 'User 5',
          login: 'User5',
          role: 'Program member',
          email: 'user5@example.com',
          light: false
        };

        this.store.commit('addMember', newMember);

        let expectedMembers = {
          user1: {name: 'User1', login: 'user1', role: 'Program administrator', email: 'user1@example.com'},
          user2: {name: 'User2', login: 'user2', role: 'Program administrator', email: 'user2@example.com'},
          user3: {name: 'User3', login: 'user3', role: 'Program administrator', email: 'user3@example.com'},
          User5: {name: 'User 5', login: 'User5', role: 'Program member', email: 'user5@example.com', light: false}
        };
        assert.deepEqual(expectedMembers, this.store.state.programTeam.members);
        assert.deepEqual([], this.store.state.programTeam.users);
      });
    });

    describe('fetchProjects', () => {
      beforeEach(() => {
        this.store.state.programTeam.users = [{
          name: 'User1',
          login: 'user_1',
          role: 'Full member',
          email: 'user1@example.com'
        }];
      });

      it('should update projects in users state', () => {
        let userData = {userLogin: 'user_1', projects: 'Projects'};
        this.store.commit('updateProjects', userData);
        let expectedUsers = [{
          name: 'User1',
          login: 'user_1',
          role: 'Full member',
          email: 'user1@example.com',
          projects: 'Projects'
        }];
        assert.deepEqual(expectedUsers, this.store.state.programTeam.users);
      })
    });

    describe('UpdateMemberRole', ()=> {
      it('should update the members role', ()=> {
        assert.equal('Program administrator', this.store.state.programTeam.members.user1.role);
        assert.equal('Program administrator', this.store.state.programTeam.members.user2.role);
        this.store.commit('updateMembersRole',{logins:['user1','user2'],role:'Program member'});

        assert.equal('Program member', this.store.state.programTeam.members.user1.role);
        assert.equal('Program member', this.store.state.programTeam.members.user2.role);
      });
    });
  });

  describe('Actions', () => {
    describe('RemoveMembers', () => {
      it('should commit removeMembers on ajax success', () => {
        let promise = Promise.resolve({success: true, message: 'Success'});
        sandbox.stub(programTeamService, 'bulkRemove').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');
        assert.equal(0, commitStub.callCount);

        return this.store.dispatch('removeMembers', ['user1', 'user2']).then((message) => {
          assert.equal(1, commitStub.callCount);
          assert.deepEqual({success: true, message: 'Success'}, message);
        });
      });

      it('should not commit removeMembers on ajax failure', () => {
        let promise = Promise.resolve({success: false, message: 'failed'});
        sandbox.stub(programTeamService, 'bulkRemove').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');

        return this.store.dispatch('removeMembers', ['user1', 'user2']).then((message) => {
          assert.equal(0, commitStub.callCount);
          assert.deepEqual({success: false, message: 'failed'}, message);
        });
      });
    });


    describe('addMember', () => {
      it('should commit updateRole and addMember on ajax success', () => {
        let promise = Promise.resolve({success: true, user: 'UserInfo'});
        sandbox.stub(programTeamService, 'addMember').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');
        assert.equal(0, commitStub.callCount);

        return this.store.dispatch('addMember', ['userLogin', 'userRole]']).then((message) => {
          assert.equal(2, commitStub.callCount);
          assert.deepEqual({success: true}, message);
        });
      });

      it('should not commit updateRole and addMember on ajax failure', () => {
        let promise = Promise.resolve({success: false, error: 'role not defined'});
        sandbox.stub(programTeamService, 'addMember').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');

        return this.store.dispatch('addMember', ['userLogin', 'userRole']).then((message) => {
          assert.equal(0, commitStub.callCount);
          assert.deepEqual({success: false, error: 'role not defined'}, message);
        });
      });
    });
    describe('fetchProjects', () => {
      it('should commit updateProjects on ajax success', () => {
        let promise = Promise.resolve({success: true, data: {projects: 'UserData'}});
        sandbox.stub(userService, 'fetchProjects').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');
        assert.equal(0, commitStub.callCount);

        return this.store.dispatch('fetchProjects', 'userLogin').then((message) => {
          assert.equal(1, commitStub.callCount);
          assert.equal('UserData', message);
        });
      });
    });

    describe('FetchUsers', () => {
      it('should commit updateUsers on ajax success and set usersFetched to true', () => {
        let promise = Promise.resolve({success: true, users: ['Users']});
        sandbox.stub(userService, 'fetchUsers').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');
        assert.equal(0, commitStub.callCount);

        this.store.dispatch('fetchUsers').then((response) => {
          assert.equal(1, commitStub.callCount);
          assert.deepEqual({success: true, users: ['Users']}, response);
          assert.ok(this.store.usersFetched);
        });
      });

      it('should not commit updateUsers on ajax failure', () => {
        let promise = Promise.resolve({success: false});
        sandbox.stub(userService, 'fetchUsers').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');
        assert.equal(0, commitStub.callCount);

        this.store.dispatch('fetchUsers').then((_) => {
          assert.equal(0, commitStub.callCount);
        });
      });

      it('should not invoke fetchUsers service when usersFetched is true', () => {
        this.store.usersFetched = true;
        let fetchUsersStub = sandbox.stub(userService, 'fetchUsers');
        let commitStub = sandbox.stub(this.store, 'commit');

        this.store.dispatch('fetchUsers').then((_) => {
          assert.equal(0, fetchUsersStub.callCount);
          assert.equal(0, commitStub.callCount);
        });
      });
    });

    describe('Bulk Update', () => {
      beforeEach( ()=> {
        this.commitStub = sandbox.stub(this.store, 'commit');
      });
      it('should invoke bulkUpdate service', () => {
        let promise = Promise.resolve({success: true, message: 'Success message'});
        let bulkUpdateStub = sandbox.stub(programTeamService, 'bulkUpdate');
        bulkUpdateStub.returns(promise);

        return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((_) => {
          assert.equal(1,bulkUpdateStub.callCount );
          assert.deepEqual([['user_1', 'user_2'], 'program_member'],bulkUpdateStub.args[0] );
        });
      });

      it('should resolve with success message', () => {
        let promise = Promise.resolve({success: true, message: 'Success message'});
        sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);

        return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((response) => {
          assert.deepEqual({success:true, message:'Success message'}, response);
        });
      });

      it('should resolve with failure message', () => {
        let promise = Promise.resolve({success: false, error: 'Failure message'});
        sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);

        return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((response) => {
          assert.deepEqual({success:false, message:'Failure message'}, response);
        });
      });

      it('should commit updateMembersRole', () => {
        let promise = Promise.resolve({success: true, message: 'Success message'});
        sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);


        return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((_) => {
          assert.equal(1, this.commitStub.callCount);
          assert.equal('updateMembersRole', this.commitStub.args[0][0]);
          assert.deepEqual({logins: ['user_1', 'user_2'], role: {name: 'Program Member', id:'program_member'}}, this.commitStub.args[0][1]);
        });
      });

      it('should not commit updateMemberRole', () => {
        let promise = Promise.resolve({success: false, error: 'Failure message'});
        sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);


        return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((_) => {
          assert.equal(0, this.commitStub.callCount);
        });
      });
    });
  });

});
