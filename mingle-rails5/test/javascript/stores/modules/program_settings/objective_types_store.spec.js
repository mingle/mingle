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
import createObjectiveTypes from "../../../../../app/javascript/stores/modules/program_settings/objective_types";

let localVue = createLocalVue();
let sandbox = sinon.createSandbox();

let objectiveTypeService = {
  update: () => {
  }
};

let services = {'objectiveTypes': objectiveTypeService};
localVue.use(Vuex);

describe('ObjectiveType Store Module', function () {
  beforeEach(() => {
    this.data = {
      objectiveTypes: [{id: 1, name: 'Objective', value_statement: 'Objective value statement'},
                       {id: 2, name: 'Epic', value_statement: 'Epic value statement'},
                       {id: 3, name: 'Feature', value_statement: 'Feature value statement'}]
    };
    this.store = new Vuex.Store({
      modules: {
        objectiveTypes: createObjectiveTypes(services, this.data)
      }
    });
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('Initialization', () => {
    it('should have objectiveTypes state', () => {
      assert.deepEqual(this.data.objectiveTypes, this.store.state.objectiveTypes.objectiveTypes);
    });
  });

  describe('Mutations', () => {
    describe('updateObjectiveType', () => {
      it('should update the objectiveType in state', () => {
        assert.deepEqual(this.data.objectiveTypes, this.store.state.objectiveTypes.objectiveTypes);
        this.store.commit('updateObjectiveType', {id: 2, name: 'BigEpic', value_statement: 'Value of Big Epic'});

        let expectedObjectiveTypes = [{id: 1, name: 'Objective', value_statement: 'Objective value statement'},
                                      {id: 2, name: 'BigEpic', value_statement: 'Value of Big Epic'},
                                      {id: 3, name: 'Feature', value_statement: 'Feature value statement'}];
        assert.deepEqual(this.store.state.objectiveTypes.objectiveTypes, expectedObjectiveTypes);
      })
    });
  });

  describe('Actions', () => {
    describe('updateObjectiveType', () => {
      it('should invoke the update on service and commit updatedObjective on success', () => {
        let updatedObjectiveType = {id: 2, name: 'NewName', value_statement: 'val statement'};
        let promise = Promise.resolve({success: true, objectiveType: updatedObjectiveType});
        let objectiveTypeServiceStub = sandbox.stub(objectiveTypeService, 'update').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');

        assert.equal(commitStub.callCount, 0);

        return this.store.dispatch('updateObjectiveType', updatedObjectiveType).then((result) => {
          assert.equal(commitStub.callCount, 1);
          assert.equal(commitStub.args[0].length, 2);
          assert.equal(commitStub.args[0][0], 'updateObjectiveType');
          assert.deepEqual(commitStub.args[0][1], updatedObjectiveType);

          assert.equal(objectiveTypeServiceStub.callCount, 1);
          assert.equal(objectiveTypeServiceStub.args[0].length, 1);
          assert.deepEqual(objectiveTypeServiceStub.args[0][0], updatedObjectiveType);

          assert.deepEqual({success: true, objectiveType: updatedObjectiveType}, result);
        });
      });

      it('should not commit updateObjective when the service returns a failure', () => {
        let updatedObjectiveType = {id: 2, name: 'NewName', value_statement: 'val statement'};
        let promise = Promise.resolve({success: false, error: 'some error occurred'});
        let objectiveTypeServiceStub = sandbox.stub(objectiveTypeService, 'update').returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');

        return this.store.dispatch('updateObjectiveType', updatedObjectiveType).then((result) => {
          assert.equal(commitStub.callCount, 0);

          assert.equal(objectiveTypeServiceStub.callCount, 1);

          assert.deepEqual({success: false, error: 'some error occurred'}, result);
        });
      })
    });
  });

  // describe('Actions', () => {
  //   describe('RemoveMembers', () => {
  //     it('should commit removeMembers on ajax success', () => {
  //       let promise = Promise.resolve({success: true, message: 'Success'});
  //       sandbox.stub(programTeamService, 'bulkRemove').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //       assert.equal(0, commitStub.callCount);
  //
  //       return this.store.dispatch('removeMembers', ['user1', 'user2']).then((message) => {
  //         assert.equal(1, commitStub.callCount);
  //         assert.deepEqual({success: true, message: 'Success'}, message);
  //       });
  //     });
  //
  //     it('should not commit removeMembers on ajax failure', () => {
  //       let promise = Promise.resolve({success: false, message: 'failed'});
  //       sandbox.stub(programTeamService, 'bulkRemove').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //
  //       return this.store.dispatch('removeMembers', ['user1', 'user2']).then((message) => {
  //         assert.equal(0, commitStub.callCount);
  //         assert.deepEqual({success: false, message: 'failed'}, message);
  //       });
  //     });
  //   });
  //
  //
  //   describe('addMember', () => {
  //     it('should commit updateRole and addMember on ajax success', () => {
  //       let promise = Promise.resolve({success: true, user: 'UserInfo'});
  //       sandbox.stub(programTeamService, 'addMember').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //       assert.equal(0, commitStub.callCount);
  //
  //       return this.store.dispatch('addMember', ['userLogin', 'userRole]']).then((message) => {
  //         assert.equal(2, commitStub.callCount);
  //         assert.deepEqual({success: true}, message);
  //       });
  //     });
  //
  //     it('should not commit updateRole and addMember on ajax failure', () => {
  //       let promise = Promise.resolve({success: false, error: 'role not defined'});
  //       sandbox.stub(programTeamService, 'addMember').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //
  //       return this.store.dispatch('addMember', ['userLogin', 'userRole']).then((message) => {
  //         assert.equal(0, commitStub.callCount);
  //         assert.deepEqual({success: false, error: 'role not defined'}, message);
  //       });
  //     });
  //   });
  //   describe('fetchProjects', () => {
  //     it('should commit updateProjects on ajax success', () => {
  //       let promise = Promise.resolve({success: true, data: {projects: 'UserData'}});
  //       sandbox.stub(userService, 'fetchProjects').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //       assert.equal(0, commitStub.callCount);
  //
  //       return this.store.dispatch('fetchProjects', 'userLogin').then((message) => {
  //         assert.equal(1, commitStub.callCount);
  //         assert.equal('UserData', message);
  //       });
  //     });
  //   });
  //
  //   describe('FetchUsers', () => {
  //     it('should commit updateUsers on ajax success and set usersFetched to true', () => {
  //       let promise = Promise.resolve({success: true, users: ['Users']});
  //       sandbox.stub(userService, 'fetchUsers').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //       assert.equal(0, commitStub.callCount);
  //
  //       this.store.dispatch('fetchUsers').then((response) => {
  //         assert.equal(1, commitStub.callCount);
  //         assert.deepEqual({success: true, users: ['Users']}, response);
  //         assert.ok(this.store.usersFetched);
  //       });
  //     });
  //
  //     it('should not commit updateUsers on ajax failure', () => {
  //       let promise = Promise.resolve({success: false});
  //       sandbox.stub(userService, 'fetchUsers').returns(promise);
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //       assert.equal(0, commitStub.callCount);
  //
  //       this.store.dispatch('fetchUsers').then((_) => {
  //         assert.equal(0, commitStub.callCount);
  //       });
  //     });
  //
  //     it('should not invoke fetchUsers service when usersFetched is true', () => {
  //       this.store.usersFetched = true;
  //       let fetchUsersStub = sandbox.stub(userService, 'fetchUsers');
  //       let commitStub = sandbox.stub(this.store, 'commit');
  //
  //       this.store.dispatch('fetchUsers').then((_) => {
  //         assert.equal(0, fetchUsersStub.callCount);
  //         assert.equal(0, commitStub.callCount);
  //       });
  //     });
  //   });
  //
  //   describe('Bulk Update', () => {
  //     beforeEach( ()=> {
  //       this.commitStub = sandbox.stub(this.store, 'commit');
  //     });
  //     it('should invoke bulkUpdate service', () => {
  //       let promise = Promise.resolve({success: true, message: 'Success message'});
  //       let bulkUpdateStub = sandbox.stub(programTeamService, 'bulkUpdate');
  //       bulkUpdateStub.returns(promise);
  //
  //       return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((_) => {
  //         assert.equal(1,bulkUpdateStub.callCount );
  //         assert.deepEqual([['user_1', 'user_2'], 'program_member'],bulkUpdateStub.args[0] );
  //       });
  //     });
  //
  //     it('should resolve with success message', () => {
  //       let promise = Promise.resolve({success: true, message: 'Success message'});
  //       sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);
  //
  //       return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((response) => {
  //         assert.deepEqual({success:true, message:'Success message'}, response);
  //       });
  //     });
  //
  //     it('should resolve with failure message', () => {
  //       let promise = Promise.resolve({success: false, error: 'Failure message'});
  //       sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);
  //
  //       return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((response) => {
  //         assert.deepEqual({success:false, message:'Failure message'}, response);
  //       });
  //     });
  //
  //     it('should commit updateMembersRole', () => {
  //       let promise = Promise.resolve({success: true, message: 'Success message'});
  //       sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);
  //
  //
  //       return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((_) => {
  //         assert.equal(1, this.commitStub.callCount);
  //         assert.equal('updateMembersRole', this.commitStub.args[0][0]);
  //         assert.deepEqual({logins: ['user_1', 'user_2'], role: {name: 'Program Member', id:'program_member'}}, this.commitStub.args[0][1]);
  //       });
  //     });
  //
  //     it('should not commit updateMemberRole', () => {
  //       let promise = Promise.resolve({success: false, error: 'Failure message'});
  //       sandbox.stub(programTeamService, 'bulkUpdate').returns(promise);
  //
  //
  //       return this.store.dispatch('bulkUpdate', {logins: ['user_1', 'user_2'], role:{name: 'Program Member', id:'program_member'}}).then((_) => {
  //         assert.equal(0, this.commitStub.callCount);
  //       });
  //     });
  //   });
  // });

});
