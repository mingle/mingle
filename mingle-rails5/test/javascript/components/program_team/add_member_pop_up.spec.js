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
import assert from "assert";
import {mount, createLocalVue} from '@vue/test-utils'
import sinon from 'sinon'
import vueSelect from 'vue-select'
let localVue = createLocalVue();
localVue.component('vue-select', vueSelect);
let sandbox = sinon.createSandbox();

import AddMemberPopUp from "../../../../app/javascript/components/AddMemberPopUp";


describe('AddMemberPopUp.vue', () => {
  let AddMemberPopUpComponent;

  describe('For admin user', function () {
    let storeDispatchStub, hideStub;
    beforeEach(function () {
      storeDispatchStub = sandbox.stub();
      hideStub = sandbox.stub();
      AddMemberPopUpComponent = mount(AddMemberPopUp, {
        localVue,
        mocks: {
          $store: {
            state: {
              programTeam: {
                users: [{name: 'user1', login: 'user1_login', email_id: 'user1_email'},
                  {name: 'user2', login: 'user2_login', email_id: 'user2_email'},
                  {name: 'user3', login: 'user3_login', email_id: 'user3_email'}],
                roles: [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}]
              }
            },
              dispatch: storeDispatchStub
          },
          $modal: {
            hide: hideStub
          }
        },
        propsData: {
          heading: "New Heading"
        },
        data: {
          selectedUser: "",
          projects: "",
          selectedRole: ""
        }
      });
    });
    afterEach(() => {
      sandbox.reset();
    });
    describe('Renders', () => {
      it('select user search box', () => {

        assert.equal(AddMemberPopUpComponent.find('.add-member-heading').text(), "New Heading");
        assert.ok(AddMemberPopUpComponent.find('.select-user .fa.fa-search').exists());
        assert.ok(AddMemberPopUpComponent.find('#select-user .v-select').exists());

      });

      it('field rows for member details are disabled', () => {
        assert.equal(3, AddMemberPopUpComponent.findAll('.member-details .member-input-row.disabled').length);
        assert.equal(1, AddMemberPopUpComponent.findAll('.member-details .member-input-row.role.disabled').length);
      });

      it('should enable role selector when user is selected', () => {
        AddMemberPopUpComponent.setData({selectedUser: {name: 'u', login: 'u'}});

        assert.deepEqual(['member-input-row', 'role'], AddMemberPopUpComponent.find('.member-details .member-input-row.role').classes());
      });

      it('renders add button along with icon', () => {
        assert.ok(AddMemberPopUpComponent.find('.action-bar .add').exists());
        assert.ok(AddMemberPopUpComponent.find('.action-bar .fa.fa-plus').exists());
      });

      it('should enable add button only if user and role are selected', (done) => {
        let addButton = AddMemberPopUpComponent.find('.action-bar button.add');
        assert.ok(addButton.attributes().disabled);

        AddMemberPopUpComponent.setData({selectedUser: "", selectedRole: "program admin"});
        setTimeout(() => {
          assert.ok(addButton.attributes().disabled);
          AddMemberPopUpComponent.setData({selectedUser: {login: "user1"}, selectedRole: "program admin"});

          setTimeout(() => {
            assert.ok(!addButton.attributes().disabled);
            done();
          })
        });
      });

      it('renders cancel button', () => {
        assert.ok(AddMemberPopUpComponent.find('.action-bar .cancel').exists());
      })

    });

    describe('Click', () => {
      it('on click should open dropdown with initial values', (done) => {
        AddMemberPopUpComponent.find('.select-user .dropdown-toggle').trigger('mousedown');
        setTimeout(() => {
          assert(AddMemberPopUpComponent.find('.select-user .v-select').exists());
          assert.equal(AddMemberPopUpComponent.findAll('.select-user .dropdown-menu li').length, 3);
          let dropdownValues = AddMemberPopUpComponent.findAll('.select-user .dropdown-menu li');
          for (let idx = 0; idx <= 2; idx++) {
            let o = dropdownValues.at(idx);
            assert.equal(o.text(), 'user' + (idx + 1));
          }
          done();
        });
      });

      it('on selecting a new user the role value is reset', (done) => {
        storeDispatchStub.returns(Promise.resolve(['project_1','project_2']));

        AddMemberPopUpComponent.vm.selectedRole = 'user_role';
        AddMemberPopUpComponent.vm.selectedUser = {name: 'user 1', login: 'user1'};

        setTimeout(function () {
          assert(AddMemberPopUpComponent.find('.select-user').exists());
          assert.equal(AddMemberPopUpComponent.vm.selectedUser.name, 'user 1');
          assert.equal(AddMemberPopUpComponent.vm.selectedUser.login, 'user1');
          assert.equal(AddMemberPopUpComponent.vm.selectedRole, 'user_role');
          assert.equal(storeDispatchStub.callCount, 1);
          assert.equal(storeDispatchStub.args[0][0], 'fetchProjects');
          assert.equal(AddMemberPopUpComponent.vm.projects, 'project_1, project_2');

          AddMemberPopUpComponent.vm.selectedUser = {name: 'user 2', login: 'user2'};

          setTimeout(function() {
            assert.equal(AddMemberPopUpComponent.vm.selectedUser.name, 'user 2');
            assert.equal(AddMemberPopUpComponent.vm.selectedUser.login, 'user2');
            assert.equal(AddMemberPopUpComponent.vm.selectedRole, '');
            assert.equal(storeDispatchStub.callCount, 2);
            assert.equal(storeDispatchStub.args[1][0], 'fetchProjects');
            assert.equal(AddMemberPopUpComponent.vm.projects, 'project_1, project_2');
            done();
          });
        });
      });

      it('should not dispatch call to the store when the selectedUser is empty',(done)=>{
        storeDispatchStub.returns(Promise.resolve());
         AddMemberPopUpComponent.vm.selectedUser = "user";

        setTimeout(function () {
          assert.equal(storeDispatchStub.callCount, 1);
          AddMemberPopUpComponent.vm.selectedUser = '';

          setTimeout(function () {
            assert.equal(storeDispatchStub.callCount, 1);
            done();
          });
        });
      });

      it('on selecting the same value should not reset role', (done) => {
        storeDispatchStub.returns(Promise.resolve(['projects']));

        AddMemberPopUpComponent.find('.select-user .dropdown-toggle').trigger('mousedown');

        localVue.nextTick(() => {
          AddMemberPopUpComponent.findAll('.select-user .dropdown-menu li').at(0).find('a').trigger('mousedown');
        });
        setTimeout(() => {
          AddMemberPopUpComponent.find('#select-role .dropdown-toggle').trigger('mousedown');
          localVue.nextTick(() => {
            assert.ok(AddMemberPopUpComponent.find('#select-role .v-select').exists());

            AddMemberPopUpComponent.findAll('#select-role .dropdown-menu li').at(0).find('a').trigger('mousedown');
          });

          localVue.nextTick(() => {
            assert.deepEqual(AddMemberPopUpComponent.vm.selectedRole, {value: 'program_admin', label: 'Program administrator'});

            assert.deepEqual(AddMemberPopUpComponent.vm.selectedUser, {
              name: 'user1',
              login: 'user1_login',
              email_id: 'user1_email'
            });
            AddMemberPopUpComponent.find('.select-user .dropdown-toggle').trigger('mousedown');
          });

          localVue.nextTick(() => {
            AddMemberPopUpComponent.findAll('.select-user .dropdown-menu li').at(0).find('a').trigger('mousedown');

          });
          setTimeout(() => {
            assert.deepEqual(AddMemberPopUpComponent.vm.selectedRole, {value: 'program_admin', label: 'Program administrator'});
            done();
          });

        });
      });
    });

    describe('Methods', () => {
      describe('addMember', () => {
        it('should hide the modal and emit updateMessage event on successful ajax message', (done) => {
          storeDispatchStub.returns(
              Promise.resolve({success: true})
          );
          AddMemberPopUpComponent.setData({selectedUser: {name: 'user', login: 'user'}, selectedRole: 'admin', projects: "projects"});
          AddMemberPopUpComponent.find('button.add').trigger('click');

          setTimeout(() => {
            assert.equal(hideStub.callCount, 1);
            assert.ok(!AddMemberPopUpComponent.vm.selectedUser);
            assert.ok(!AddMemberPopUpComponent.vm.selectedRole);
            assert.ok(!AddMemberPopUpComponent.vm.projects);
            done();
          });
        });
      });

      describe('closePopUp', () => {
        it('should hide the modal and reset the data', (done) => {
          AddMemberPopUpComponent.setData({selectedUser: {name: 'user', login: 'user'}, selectedRole: 'admin', projects: "projects"});
          AddMemberPopUpComponent.find('button.cancel').trigger('click');

          setTimeout(() => {
            assert.equal(AddMemberPopUpComponent.vm.selectedUser, "");
            assert.equal(AddMemberPopUpComponent.vm.selectedRole, "");
            assert.equal(AddMemberPopUpComponent.vm.projects, "");
            assert.equal(hideStub.callCount, 1);
            done();
          });
        });
      });
    });
  });
});
