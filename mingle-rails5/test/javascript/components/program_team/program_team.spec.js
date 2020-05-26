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
import vueTables from 'vue-tables-2'
import modal from 'vue-js-modal'
import vClickOutside from 'v-click-outside'
let localVue  = createLocalVue();
localVue.component('vue-tables-2', vueTables);
localVue.use(vueTables.ClientTable);
localVue.use(modal);
localVue.use(vClickOutside);
let sandbox = sinon.createSandbox();

import ProgramTeam from "../../../../app/javascript/components/ProgramTeam";


describe('ProgramTeam.vue', () => {
  let programAppComponent, dispatchStub, modalShowStub;

  function setupUsers(numberOfUsers, areUsersSelected) {
    let users = {};
    for(let i= 0; i < numberOfUsers ; i++ ) {
      let user = {name: `user${i}`, login: `user${i}`, role: "Program admin", email: `user${i}@some.com`};
      if(areUsersSelected)
        user.selected = true;
      users[user.login] = user;
    }
    programAppComponent.setData({members:users});
  }

  beforeEach(() => {
    sandbox.stub(document, 'querySelector').returns({
          getStyle(style) {
            let styles = {margin: '20px', padding: '10px'};
            return styles[style];
          },
          getWidth() {
            return 40;
          }, positionedOffset() {
            return {left: 20, top: 40}
          }
        }
    );
  });
  afterEach(() => {
    sandbox.restore();
  });
  describe('For admin user', ()=> {
    beforeEach(() => {
      dispatchStub = sandbox.stub();
      modalShowStub = sandbox.stub();
      programAppComponent = mount(ProgramTeam, {
        localVue,
        mocks: {
          $store: {
            state: {
              programTeam: {
                members: {
                  user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", projects: "project1", activated:true},
                  user3: {name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", projects: "project3", activated:true},
                  user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", projects: "project2", activated:true},
                  user4: {name: 'user4', login: "user4", role: {name:"Program administrator",id:'program_admin'}, email: "user4@some.com", projects: "project2", activated:true}
                },
                roles: [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}]
              },
              toggles: {addTeamMemberEnabled: true},
              currentUser:{
                admin:true,name:'user4',login:'user4',mingleAdmin:false
              }
            },
            dispatch:dispatchStub

          },
          $modal:{
            show:modalShowStub
          }
        }
      });
    });
    describe('Renders', () => {
      it('should render default headings and select all checkbox heading', () => {
        let tableHeadings = programAppComponent.findAll('.VueTables__heading');
        let selectAllCheckBox = tableHeadings.at(0).find('#select_all_checkbox');

        assert.equal(6, tableHeadings.length);
        assert.ok(selectAllCheckBox.exists());
        assert.ok(!selectAllCheckBox.element.checked);
        assert.equal("Name", tableHeadings.at(1).text());
        assert.equal("Sign-in name", tableHeadings.at(2).text());
        assert.equal("Projects", tableHeadings.at(3).text());
        assert.equal("Role", tableHeadings.at(4).text());
        assert.equal("Email", tableHeadings.at(5).text());
      });

      it('should render table with user list ', () => {

        assert.equal(4, programAppComponent.findAll('tbody tr').length);
        let first_row = programAppComponent.findAll('tr').at(1);
        let second_row = programAppComponent.findAll('tr').at(2);

        assert.ok(!first_row.findAll('td').at(0).element.checked);
        assert.equal("user1", first_row.findAll('td').at(1).text());
        assert.equal("user1", first_row.findAll('td').at(2).text());
        assert.equal("project1", first_row.findAll('td').at(3).text());
        assert.equal("Program administrator", first_row.find('td #user1_role_dropdown .drop-down-toggle').text());
        assert.equal("user1@some.com", first_row.findAll('td').at(5).text());

        assert.ok(!second_row.findAll('td').at(0).element.checked);
        assert.equal("user2", second_row.findAll('td').at(1).text());
        assert.equal("user2", second_row.findAll('td').at(2).text());
        assert.equal("project2", second_row.findAll('td').at(3).text());
        assert.equal("Program administrator", second_row.find('td #user2_role_dropdown .drop-down-toggle').text());
        assert.equal("user2@some.com", second_row.findAll('td').at(5).text());
      });

      it('should add role-updated class on role column for recently updated member', () => {
        programAppComponent.setData({lastUpdatedMember:{login:'user1'}});
        assert.equal(1, programAppComponent.findAll('tbody tr td .role-updated').length);
        let first_row = programAppComponent.findAll('tr').at(1);

        assert.equal("Program administrator", first_row.find('td .role-updated #user1_role_dropdown .drop-down-toggle').text());

      });

      it('should not render change role dropdown for deactivated member', () => {
        let members = {
          user1:{name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", activated:false},
        };
        programAppComponent.setData({members});

        let firstRow = programAppComponent.findAll('tr').at(1);
        assert.ok(!firstRow.findAll('td').at(0).element.checked);
        assert.equal("user1", firstRow.findAll('td').at(1).text());
        assert.equal("user1", firstRow.findAll('td').at(2).text());
        assert.ok(!firstRow.find('td #user1_role_dropdown').exists());

      });

      it('should not render change role dropdown for current user', () => {
        let fourthRow = programAppComponent.findAll('tr').at(4);

        assert.ok(!fourthRow.findAll('td').at(0).element.checked);
        assert.equal("user4", fourthRow.findAll('td').at(1).text());
        assert.equal("user4", fourthRow.findAll('td').at(2).text());
        assert.ok(!fourthRow.find('td #user4_role_dropdown').exists());

      });

      it('should render change role dropdown for current user which is also an Mingle admin', () => {
        programAppComponent = mount(ProgramTeam, {
          localVue,
          mocks: {
            $store: {
              state: {
                programTeam: {
                  members: {
                    user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", projects: "project1",activated:true},
                  },
                  roles: [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}]
                },
                toggles: {addTeamMemberEnabled: true},
                currentUser:{
                  admin:true,name:'user1',login:'user1',mingleAdmin:true
                }
              },
              dispatch:dispatchStub
            },
            $modal:{
              show:modalShowStub
            }
          }
        });
        let fourthRow = programAppComponent.findAll('tr').at(1);

        assert.ok(!fourthRow.findAll('td').at(0).element.checked);
        assert.equal("user1", fourthRow.findAll('td').at(1).text());
        assert.equal("user1", fourthRow.findAll('td').at(2).text());
        assert.ok(fourthRow.find('td #user1_role_dropdown').exists());

      });

      it('should render add team member button for admin', () => {
        assert.ok(programAppComponent.find('button.add-member').exists());
        assert.equal('Add Team Member', programAppComponent.find('button.add-member').text());
      });

      it('should render disabled remove team member button for admin', () => {
        let removeButton = programAppComponent.find('button.remove-member');
        assert.ok(removeButton.exists());
        assert.equal('Remove', removeButton.text());
        assert.equal('disabled',removeButton.attributes().disabled)
      });

      it('should render enabled remove team member button for admin', () => {
        programAppComponent.setData({disableBulkActions:false});

        let removeButton = programAppComponent.find('button.remove-member');
        assert.ok(removeButton.exists());
        assert.ok(!removeButton.attributes().hasOwnProperty('disabled'))
      });

      it('should render disabled change role button', () => {
        let changeRoleButton = programAppComponent.find('#change_member_role button.drop-down-toggle');
        assert.ok(changeRoleButton.exists());
        assert.equal('CHANGE ROLE',changeRoleButton.text());
        assert.ok(changeRoleButton.attributes().hasOwnProperty('disabled'))
      });

      it('should render enabled change button', () => {
        programAppComponent.setData({disableBulkActions:false});

        let changeRoleButton = programAppComponent.find('#change_member_role button.drop-down-toggle');
        assert.ok(changeRoleButton.exists());
        assert.equal('CHANGE ROLE',changeRoleButton.text());
        assert.ok(!changeRoleButton.attributes().hasOwnProperty('disabled'))
      });

      it('should render add team member button if addTeamMemberEnabled', () => {
        programAppComponent = mount(ProgramTeam, {
          mocks: {
            $store: {
              state: {
                programTeam: {
                  members: [{name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com"}],
                  roles: [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}]
                },
                toggles: {addTeamMemberEnabled: false},
                currentUser:{
                  admin:true,name:'user4',login:'user4'
                }
              }
            }
          }
        });

        assert.ok(!programAppComponent.find('button.add-member').exists());
      });

      it('should not render selected member message', () => {
        assert.ok(!programAppComponent.find('.actions .user-selection-message').exists());
      });

      it('should render member selected message', () => {
        let members = {
          user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false},
          user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", selected: true}
        };
        programAppComponent.setData({members});
        sandbox.stub(programAppComponent.vm, 'selectedMembersMessage').returns('One member selected.');
        let element = programAppComponent.find('.actions .user-selection-message');

        assert.ok(element.exists());
        assert.equal('One member selected.',element.text());
      });

      it('should not render select all the users message', () => {
        assert.ok(!programAppComponent.find('.select-all-team-members').exists());
      });

      it('should not render select all the users message when selected members are equal to total team members', () => {
        setupUsers(26, true);
        assert.ok(!programAppComponent.find('.select-all-team-members').exists());
      });

      it('should render select all the users message', () => {
        let members = {
          user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false},
          user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", selected: true}
        };
        programAppComponent.setData({displaySelectAllMembersLink:true, members});

        assert.ok(programAppComponent.find('.select-all-team-members').exists());
        assert.equal(`Select all ${Object.keys(programAppComponent.vm.members).length} members`, programAppComponent.find('.select-all-team-members').text());
      });

      it('should not render message when message is empty', () => {

        assert.ok(!programAppComponent.find('.message-box').exists());
      });

      it('should render message when message is not empty', () => {
        programAppComponent.setData({message:{type:'success', text:'message'}});
        assert.ok(programAppComponent.find('.message-box').exists());
        assert.equal('message', programAppComponent.find('.message-box').text());
      });

      it('should not render progress bar', () => {
        assert.ok(!programAppComponent.find('.linear-progress-bar').exists());
      });

      it('should render progress bar', () => {
        programAppComponent.setData({showProgressBar:true});

        assert.ok(programAppComponent.find('.linear-progress-bar').exists());
      });

      it('should deactivate the row for deactivated user', () => {
          let members = {
              user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", activated: true},
              user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", activated: false}
          };
          programAppComponent.setData({members});

         assert.ok(!programAppComponent.findAll('tr').at(1).hasClass('deactive'));
         assert.ok(programAppComponent.findAll('tr').at(2).classes('deactive'));
      })
    });

    describe('Methods', () => {
      describe('SelectMembersOnPage', () => {
        it('should select all members on the current page', () => {
          setupUsers(26);
          let toggleRemoveButtonStub = sandbox.stub(programAppComponent.vm, 'toggleRemoveButton');
          let selectStub = sandbox.stub(programAppComponent.vm, 'select');

          assert.equal(0, selectStub.callCount);
          programAppComponent.vm.selectMembersOnPage(true);

          assert.equal(25, selectStub.callCount);
          selectStub.args.forEach((arg) => {
            assert.ok(arg[1]);
          });

          assert.equal(1,toggleRemoveButtonStub.callCount );
        });

        it('should un select all members on the current page', () => {
          setupUsers(26, true);
          let selectStub = sandbox.stub(programAppComponent.vm, 'select');

          assert.equal(0, selectStub.callCount);
          programAppComponent.vm.selectMembersOnPage(false);

          assert.equal(25, selectStub.callCount);
          selectStub.args.forEach((arg) => {
            assert.ok(!arg[1]);
          });
        });

        it('should reset displaySelectAllMembersLink when selectAllCheckBox is checked and all members are selected', () => {
          programAppComponent.setData({displaySelectAllMembersLink:true});

          let areAllMembersSelectedStub = sandbox.stub(programAppComponent.vm, 'areAllMembersSelected');
          areAllMembersSelectedStub.returns(true);

          programAppComponent.vm.selectMembersOnPage(true);
          assert.ok(!programAppComponent.vm.displaySelectAllMembersLink);

        });


        it('should set displaySelectAllMembersLink when selectAllCheckBox is checked and few members are selected', () => {

          let areAllMembersSelectedStub = sandbox.stub(programAppComponent.vm, 'areAllMembersSelected');
          areAllMembersSelectedStub.returns(false);

          programAppComponent.vm.selectMembersOnPage(true);

          assert.ok(programAppComponent.vm.displaySelectAllMembersLink);

        });


        it('should reset displaySelectAllMembersLink when selectAllCheckBox is unchecked and few members are selected', () => {
          programAppComponent.setData({displaySelectAllMembersLink:true});

          let areAllMembersSelectedStub = sandbox.stub(programAppComponent.vm, 'areAllMembersSelected');
          areAllMembersSelectedStub.returns(false);

          programAppComponent.vm.selectMembersOnPage(false);
          assert.ok(!programAppComponent.vm.displaySelectAllMembersLink);

        });

        it('should set displaySelectAllMembersLink to false when no members are selected', () => {

          programAppComponent.setData({displaySelectAllMembersLink:true});
          programAppComponent.vm.selectMembersOnPage(false);

          assert.ok(!programAppComponent.vm.displaySelectAllMembersLink);
        });

        it('should invoke reassignProgramMembers', () => {
          let reassignProgramMembersStub = sandbox.stub(programAppComponent.vm, 'reassignProgramMembers');
          programAppComponent.setData({displaySelectAllMembersLink:true});

          assert.equal(0, reassignProgramMembersStub.callCount);
          programAppComponent.vm.selectMembersOnPage(false);

          assert.ok(!programAppComponent.vm.displaySelectAllMembersLink);
          assert.equal(1, reassignProgramMembersStub.callCount);
        });
      });

      describe('selectMember', () => {
        it('should invoke select', () => {
          let selectStub = sandbox.stub(programAppComponent.vm, 'select');

          assert.equal(0, selectStub.callCount);
          programAppComponent.vm.selectMember({login: 'user1', selected: false});

          assert.equal(1, selectStub.callCount);
          assert.equal(1, selectStub.args[0].length);
          assert.deepEqual({login: 'user1', selected: false}, selectStub.args[0][0]);
        });

        it('should invoke resetSelectAll', () => {
          let resetSelectAll = sandbox.stub(programAppComponent.vm, 'resetSelectAll');

          assert.equal(0, resetSelectAll.callCount);
          programAppComponent.vm.selectMember({login: 'user1', selected: false});

          assert.equal(1, resetSelectAll.callCount);
        });

        it('should invoke toggleRemoveButton', () => {
          let toggleRemoveButtonStub = sandbox.stub(programAppComponent.vm, 'toggleRemoveButton');

          assert.equal(0,toggleRemoveButtonStub.callCount );
          programAppComponent.vm.selectMember({login: 'user1', selected: false});

          assert.equal(1,toggleRemoveButtonStub.callCount );
        });

        it('should invoke reassignProgramMembers', () => {
          let reassignProgramMembersStub = sandbox.stub(programAppComponent.vm, 'reassignProgramMembers');

          assert.equal(0, reassignProgramMembersStub.callCount);

          programAppComponent.vm.selectMember({login: 'user1', selected: false});

          assert.equal(1,reassignProgramMembersStub.callCount );
        });

      });

      describe('ToggleRemoveButton', () => {
        it('should set disable toggle to false', () => {
          assert.ok(programAppComponent.vm.disableBulkActions);
          programAppComponent.vm.toggleRemoveButton();
          assert.ok(programAppComponent.vm.disableBulkActions);
        });

        it('should set disable toggle to true', () => {
          let members = {
            user1:{name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: true},
            user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", selected: false},
            user2:{name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: false}
          };
          programAppComponent.setData({members});
          programAppComponent.vm.toggleRemoveButton();

          assert.ok(!programAppComponent.vm.disableBulkActions);
        });
      });

      describe('SelectedMembersCount', () => {
        it('should return selected members count', () => {
          let members = {
            user1:{name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: true},
            user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", selected: false},
            user2:{name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true}
          };

          assert.equal(0, programAppComponent.vm.selectedMembersCount());
          programAppComponent.setData({members});
          assert.equal(2, programAppComponent.vm.selectedMembersCount());
        });

      });

      describe('SelectAllTeamMembers', () => {
        it('should select all team members and set displaySelectAllMembersLink to false', () => {
          let selectStub = sandbox.stub(programAppComponent.vm, 'select');
          setupUsers(30);
          programAppComponent.setData({displaySelectAllMembersLink:true});

          assert.ok(programAppComponent.vm.displaySelectAllMembersLink);
          programAppComponent.vm.selectAllTeamMembers();

          assert.ok(!programAppComponent.vm.displaySelectAllMembersLink);
          assert.equal(30, selectStub.callCount);
          selectStub.args.forEach((arg) => {
            assert.ok(programAppComponent.vm.members.hasOwnProperty(arg[0].login));
            assert.ok(arg[1]);
          });
        });

        it('should invoke reassignProgramMembers', () => {
          let reassignProgramMembersStub = sandbox.stub(programAppComponent.vm, 'reassignProgramMembers');

          assert.equal(0, reassignProgramMembersStub.callCount);

          programAppComponent.vm.selectAllTeamMembers();

          assert.equal(1,reassignProgramMembersStub.callCount );
        });

      });

      describe('RemoveSelectedMembers', () => {
        it('should update message on success', (done) => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'success message' })
          );

          assert.deepEqual({}, programAppComponent.vm.message);
          programAppComponent.vm.removeSelectedMembers();
          setTimeout(() => {
            assert.deepEqual({type:'success', text:'success message'}, programAppComponent.vm.message);
            done();
          });
        });


        it('should disable remove button on success', (done) => {
          programAppComponent.setData({disableBulkActions:false});
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'success message' })
          );

          programAppComponent.vm.removeSelectedMembers();
          setTimeout(() => {
            assert.ok(programAppComponent.vm.disableBulkActions);
            done();
          });
        });

        it('should update message on failure', (done) => {
          dispatchStub.returns(
              Promise.resolve({ success: false, error: 'failure message' })
          );
          assert.deepEqual({}, programAppComponent.vm.message);
          programAppComponent.vm.removeSelectedMembers();
          setTimeout(() => {
            assert.deepEqual({type:'error', text:'failure message'}, programAppComponent.vm.message);
            done();
          });
        });

        it('should not disable remove button on failure', (done) => {
          programAppComponent.setData({disableBulkActions:false});
          dispatchStub.returns(
              Promise.resolve({ success: false, message: 'failure message' })
          );

          programAppComponent.vm.removeSelectedMembers();
          setTimeout(() => {
            assert.ok(!programAppComponent.vm.disableBulkActions);
            done();
          });
        });

        it('should show and hide progress bar before and after ajax call', (done) => {
          assert.ok(!programAppComponent.vm.showProgressBar);

          dispatchStub.returns(
              Promise.resolve({ success: false, message: 'failure message' })
          );
          programAppComponent.vm.removeSelectedMembers();

          assert.ok(programAppComponent.vm.showProgressBar);
          setTimeout(() => {
            assert.ok(!programAppComponent.vm.showProgressBar);
            done();
          });
        });

        it('should invoke getProgramMembers on success', (done) => {
          let getProgramMembers = sandbox.stub(programAppComponent.vm, 'getProgramMembers');
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'success message' })
          );

          assert.equal(0, getProgramMembers.callCount);
          programAppComponent.vm.removeSelectedMembers();

          assert.ok(programAppComponent.vm.showProgressBar);
          setTimeout(() => {
            assert.equal(1, getProgramMembers.callCount);
            done();
          });
        });

        it('should invoke getProgramMembers on failure', (done) => {
          let getProgramMembers = sandbox.stub(programAppComponent.vm, 'getProgramMembers');
          dispatchStub.returns(
              Promise.resolve({ success: false, message: 'failure message' })
          );

          assert.equal(0, getProgramMembers.callCount);
          programAppComponent.vm.removeSelectedMembers();

          assert.ok(programAppComponent.vm.showProgressBar);
          setTimeout(() => {
            assert.equal(0, getProgramMembers.callCount);
            done();
          });
        });

        it('should set progressBarTarget to .remove-member', () => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'success message' })
          );
          programAppComponent.setData({progressBarTarget:''});
          assert.equal('',programAppComponent.vm.progressBarTarget);
          programAppComponent.vm.removeSelectedMembers();
          assert.equal('.remove-member',programAppComponent.vm.progressBarTarget);

        });
      });

      describe('Select', () => {
        it('should toggle member selection', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true},
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.select(members.user1);
          //In IE input checkbox default value is false where as in chrome it's undefine
          programAppComponent.vm.select(Object.assign({},members.user2,{selected:false}));

          assert.ok(programAppComponent.vm.members.user1.selected);
          assert.ok(!programAppComponent.vm.members.user2.selected);
        });

        it('should select member', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true}
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.select(members.user1, true);
          programAppComponent.vm.select(members.user2, true);

          assert.ok(programAppComponent.vm.members.user1.selected);
          assert.ok(programAppComponent.vm.members.user2.selected);
        });

        it('should unselect member', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true}
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.select(members.user1, false);
          programAppComponent.vm.select(members.user2, false);

          assert.ok(!programAppComponent.vm.members.user1.selected);
          assert.ok(!programAppComponent.vm.members.user2.selected);
        });
      });
      describe('ShowConfirmationBox', () => {
        it('should show the confirm-delete modal',()=>{
          programAppComponent.setData({disableBulkActions: false});

          assert.equal(0,modalShowStub.callCount);

          programAppComponent.find('.remove-member').trigger('click');

          assert.equal(1,modalShowStub.callCount);
          assert.equal("confirm-delete",modalShowStub.args[0][0]);
        });

        it('should display message and title in singular when only one user is selected', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true}
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.showConfirmationBox();

          assert.equal("Are you sure you want to remove the selected member from the program?", programAppComponent.vm.confirmationMessage)
          assert.equal("Remove Program Member", programAppComponent.vm.confirmationTitle);
        });

        it('should display message and title in plural when more than one user is selected', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: true},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true}
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.showConfirmationBox();

          assert.equal("Are you sure you want to remove the selected members from the program?", programAppComponent.vm.confirmationMessage)
          assert.equal("Remove Program Members", programAppComponent.vm.confirmationTitle);
        });
      });

      describe('ResetSelectAll', () => {

        it('should check selectAllCheckBox', () => {
          assert.ok(!programAppComponent.vm.$el.querySelector('#select_all_checkbox').checked );

          setupUsers(26,true);
          programAppComponent.vm.resetSelectAll();

          assert.ok(programAppComponent.vm.$el.querySelector('#select_all_checkbox').checked );

        });

        it('should uncheck selectAllCheckBox', () => {
          programAppComponent.vm.$el.querySelector('#select_all_checkbox').click();
          assert.ok(programAppComponent.vm.$el.querySelector('#select_all_checkbox').checked);

          setupUsers(26,false);
          programAppComponent.vm.resetSelectAll();

          assert.ok(!programAppComponent.vm.$el.querySelector('#select_all_checkbox').checked );

        });

      });

      describe('SetSelectAllTo', () => {
        it('should check selectAlCheckBox', () => {
          programAppComponent.vm.setSelectAllTo(false);
          let allCheckBoxes = programAppComponent.vm.$el.querySelector('#select_all_checkbox');

          assert.ok(!allCheckBoxes.checked);
          programAppComponent.vm.setSelectAllTo(true);

          allCheckBoxes = programAppComponent.vm.$el.querySelector('#select_all_checkbox');
          assert.ok(allCheckBoxes.checked);

        });
      });

      describe('SelectedMembersMessage', () => {
        it('should return one member selected', () => {

          sandbox.stub(programAppComponent.vm, 'selectedMembersCount').returns(1);
          assert.equal('One member selected.', programAppComponent.vm.selectedMembersMessage());
        });

        it('should return N member selected', () => {
          sandbox.stub(programAppComponent.vm, 'selectedMembersCount').returns(2);
          assert.equal('2 members selected.', programAppComponent.vm.selectedMembersMessage());
        });
      });

      describe('AreAllMembersSelected', () => {
        it('should return true', () => {
          setupUsers(2,true);
          assert.ok(programAppComponent.vm.areAllMembersSelected());
        });

        it('should return false', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name: "Program administrator", id: 'program_admin'}, email: "user1@some.com", selected: false},
            user3: {name: 'user3', login: "user3", role: {name: "Program administrator", id: 'program_admin'}, email: "user3@some.com", selected: true},
          };
          programAppComponent.setData({members});
          
          assert.ok(!programAppComponent.vm.areAllMembersSelected());
        });
      });

      describe('RoleChanged', () => {
        it('should invoke changeMembersRole', () => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:true}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub});
          assert.equal(0, changeMembersRoleStub.callCount);

          programAppComponent.vm.roleChanged("user1")({name:"Program member", id: 'program_member'});

          assert.equal(1, changeMembersRoleStub.callCount);
          assert.deepEqual({logins:['user1'],role:{name:"Program member", id: 'program_member'}}, changeMembersRoleStub.args[0][0]);
        });

        it('should not changeMembersRole when selected role is same as the current role', () => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:true}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub});
          programAppComponent.vm.roleChanged("user1")({name:"Program administrator", id: 'program_admin'});

          assert.equal(0, changeMembersRoleStub.callCount);
        });

        it('should set lastUpdatedMember on success', (done) => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:true}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub});
          programAppComponent.setData({lastUpdatedMember:{}});
          programAppComponent.vm.roleChanged("user1")({name:"Program member", id: 'program_member'});
          setTimeout(() => {
            let expectedUserLogin = {login:'user1'};
            assert.deepEqual(expectedUserLogin, programAppComponent.vm.lastUpdatedMember);
            done()
          });

        });

        it('should invoke reassignProgramMembers on success', (done) => {
          let changeMembersRoleStub = sandbox.stub();
          let reassignProgramMembersStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:true}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub, reassignProgramMembers:reassignProgramMembersStub});
          assert.equal(0, reassignProgramMembersStub.callCount);
          programAppComponent.vm.roleChanged("user1")({name:"Program member", id: 'program_member'});
          setTimeout(() => {
            assert.equal(1, reassignProgramMembersStub.callCount);
            done();
          });
        });

        it('should not invoke reassignProgramMembers on failure', (done) => {
          let changeMembersRoleStub = sandbox.stub();
          let reassignProgramMembersStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:false}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub, reassignProgramMembers:reassignProgramMembersStub});
          assert.equal(0, reassignProgramMembersStub.callCount);
          programAppComponent.vm.roleChanged("user1")({name:"Program member", id: 'program_member'});
          setTimeout(() => {
            assert.equal(0, reassignProgramMembersStub.callCount);
            done();
          });
        });

        it('should not set lastUpdatedMember on failure', (done) => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:false}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub});
          programAppComponent.setData({lastUpdatedMember:{}});
          programAppComponent.vm.roleChanged("user1")({name:"Program member", id: 'program_member'});
          setTimeout(() => {
            assert.deepEqual({}, programAppComponent.vm.lastUpdatedMember);
            done()
          });
        });
      });
      describe('UpdateRoles', () => {

        it('should invoke changeMemberRole only when there is at least one active member selected', () => {
          let changeMembersRoleStub = sandbox.stub();
          programAppComponent.setMethods({changeMembersRole: changeMembersRoleStub});
          let members = {
            user2: {name: 'user2',login: "user2",role: {name: "Program administrator", id: 'program_admin'},email: "user2@some.com",selected: true,activated: false},
            user1: {role: {name: "Program administrator", id: 'program_admin'},name: 'user1',login: "user1",email: "user1@some.com",activated: false,selected: true },
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: false,activated: true }
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.updateRoles({name: "Program member", id: 'program_member'});

          assert.equal(0, changeMembersRoleStub.callCount);
        });

        it('should invoke changeMembersRole and not change disableBulkActions', (done) => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:false}) );
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub});
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false, activated: true},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", selected: true, activated: true}
          };
          programAppComponent.setData({members:members, disableBulkActions:false});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});

          assert.deepEqual({logins:['user2', 'user3'],role:{name:"Program member",id:'program_member'}}, changeMembersRoleStub.args[0][0]);
          setTimeout(() => {
            assert.ok(!programAppComponent.vm.disableBulkActions);
            done();
          });
        });

        it('should invoke changeMembersRole and set disableBulkActions to true', (done) => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns( Promise.resolve({success:true}));
          programAppComponent.setMethods({changeMembersRole:changeMembersRoleStub});
          let members = {
            user1: {name: 'user1', login: "user1", role: {name:"Program administrator",id:'program_admin'}, email: "user1@some.com", selected: false, activated: true},
            user2: {name: 'user2', login: "user2", role: {name:"Program administrator",id:'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3:{name: 'user3', login: "user3", role: {name:"Program administrator" , id:'program_admin'}, email: "user3@some.com", selected: true, activated: true}
          };
          programAppComponent.setData({members:members, disableBulkActions:false});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});

          assert.deepEqual({logins:['user2', 'user3'],role:{name:"Program member",id:'program_member'}}, changeMembersRoleStub.args[0][0]);

          setTimeout(() => {
            assert.ok(programAppComponent.vm.disableBulkActions);
            done();
          });
        });

        it('should invoke changeMembersRole with only active users', () => {
          let changeMembersRoleStub = sandbox.stub();
          changeMembersRoleStub.returns(Promise.resolve());
          programAppComponent.setMethods({changeMembersRole: changeMembersRoleStub});
          let members = {
            user2: {name: 'user2', login: "user2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: true,activated: false}
          };
          programAppComponent.setData({members: members});
          programAppComponent.vm.updateRoles({name: "Program member", id: 'program_member'});

          assert.deepEqual({
            logins: ['user2'],
            role: {name: "Program member", id: 'program_member'}
          }, changeMembersRoleStub.args[0][0]);
        });

        it('should enable progress bar when at least one active member is selected', () => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'success message' })
          );
          let members = {
            user2: {name: 'user2', login: "user2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: true,activated: false}
          };
          programAppComponent.setData({progressBarTarget:'',showProgressBar:false, members});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});

          assert.equal('.change-member-role .drop-down-toggle',programAppComponent.vm.progressBarTarget);
          assert.ok(programAppComponent.vm.showProgressBar);
        });

        it('should not enable progress bar when deactivated members are selected', () => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'success message' })
          );
          programAppComponent.setData({progressBarTarget:'', showProgressBar:false});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});

          assert.equal('',programAppComponent.vm.progressBarTarget);
          assert.ok(!programAppComponent.vm.showProgressBar);
        });

        it('should reset showProgressBar on success', (done) => {
          dispatchStub.returns(Promise.resolve({ success: true, message: 'success message' }) );
          let members = {
            user2: {name: 'user2', login: "user2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: true,activated: false}
          };
          programAppComponent.setData({members});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});
          setTimeout(() => {
            assert.ok(!programAppComponent.vm.showProgressBar);
            done();
          });
        });

        it('should reset showProgressBar on failure', (done) => {
          dispatchStub.returns(Promise.resolve({ success: false, message: 'failure message' }) );
          let members = {
            user2: {name: 'user2', login: "user2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: true,activated: false}
          };
          programAppComponent.setData({members});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});
          setTimeout(() => {
            assert.ok(!programAppComponent.vm.showProgressBar);
            done();
          });
        });

        it('should set success message', (done) => {
          dispatchStub.returns(Promise.resolve({ success: true, message: 'success message' }) );
          let members = {
            user2: {name: 'user2', login: "user2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: true,activated: false}
          };
          programAppComponent.setData({members});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});
          setTimeout(() => {
            assert.deepEqual({ type: 'success', text: 'success message' }, programAppComponent.vm.message);
            done();
          });
        });

        it('should set error message', (done) => {
          dispatchStub.returns(Promise.resolve({ success: false, message: 'failure message' }) );
          let members = {
            user2: {name: 'user2', login: "user2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com", selected: true, activated: true},
            user3: {name: 'user3',login: "user3",role: {name: "Program administrator", id: 'program_admin'},email: "user3@some.com",selected: true,activated: false}
          };
          programAppComponent.setData({members});
          programAppComponent.vm.updateRoles({name:"Program member",id:'program_member'});
          setTimeout(() => {
            assert.deepEqual({ type: 'error', text: 'failure message' }, programAppComponent.vm.message);
            done();
          });
        });

      });

      describe('ChangeMembersRole', () => {
        it('should dispatch bulkUpdate action', () => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'user1 role has been updated to Program member.' })
          );
          assert.equal(0, dispatchStub.callCount);
          programAppComponent.vm.changeMembersRole({logins:['user1'],role:{name:"Program member", id: 'program_member'}});
          assert.equal(1, dispatchStub.callCount);
          assert.equal('bulkUpdate', dispatchStub.args[0][0]);
          assert.deepEqual({logins:['user1'],role:{name:"Program member", id: 'program_member'}}, dispatchStub.args[0][1]);
        });

        it('should update message on success', () => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'user1 role has been updated to Program member.' })
          );
          return programAppComponent.vm.changeMembersRole({logins:['user1'],role:{name:"Program member", id: 'program_member'}}).then((response) => {
            assert.deepEqual({ success: true, message: 'user1 role has been updated to Program member.' }, response);
          });
        });

        it('should update message on failure', ( ) => {
          dispatchStub.returns(
              Promise.resolve({ success: false, message: 'something went wrong while updating members' })
          );
          return programAppComponent.vm.changeMembersRole({logins:['user1'],role:{name:"Program member", id: 'program_member'}}).then((response) => {
            assert.deepEqual({ success: false, message: 'something went wrong while updating members' },response);
          });
        });

        it('should reset lastUpdatedMember', () => {
          dispatchStub.returns(
              Promise.resolve({ success: true, message: 'user1 role has been updated to Program member.' })
          );
          programAppComponent.setData({lastUpdatedMember:{login:'user2'}});
          programAppComponent.vm.changeMembersRole({logins:['user1'],role:{name:"Program member", id: 'program_member'}})
          assert.deepEqual({},programAppComponent.vm.lastUpdatedMember );
        });
      });
    });
    describe('Interactions', () => {
      describe('Click', () => {
        it('on selectAllCheckBox should invoke selectMembersOnPage', () => {
          let selectMembersOnPageStub = sandbox.stub(programAppComponent.vm, 'selectMembersOnPage');
          assert.equal(0, selectMembersOnPageStub.callCount);
          programAppComponent.vm.$el.querySelector('#select_all_checkbox').click();

          assert.equal(1, selectMembersOnPageStub.callCount);
          assert.ok(selectMembersOnPageStub.args[0][0]);

          programAppComponent.vm.$el.querySelector('#select_all_checkbox').click();
          assert.equal(2, selectMembersOnPageStub.callCount);
          assert.ok(!selectMembersOnPageStub.args[1][0]);
        });

        it('on any user selector checkbox should invoke selectMember', () => {
          let selectMembersOnPageStub = sandbox.stub(programAppComponent.vm, 'selectMember');
          assert.equal(0, selectMembersOnPageStub.callCount);

          programAppComponent.vm.$el.querySelector('#select_user1').click();

          assert.equal(1, selectMembersOnPageStub.callCount);
          assert.deepEqual({
            name: 'user1',
            login: 'user1',
            role: {id:'program_admin', name:'Program administrator'},
            email: 'user1@some.com',
            projects: 'project1',
            activated:true
          }, selectMembersOnPageStub.args[0][0]);

          programAppComponent.vm.$el.querySelector('#select_user2').click();
          assert.equal(2, selectMembersOnPageStub.callCount);
          assert.deepEqual({
            name: 'user2',
            login: 'user2',
            role: {id:'program_admin', name:'Program administrator'},
            email: 'user2@some.com',
            projects: 'project2',
            activated:true
          }, selectMembersOnPageStub.args[1][0]);
        });

        it('on selectAllTeamMembersLink should invoke selectAllTeamMembers', () => {
          programAppComponent.setData({displaySelectAllMembersLink:true});
          let selectAllTeamMembersStub = sandbox.stub(programAppComponent.vm, 'selectAllTeamMembers');
          assert.equal(0, selectAllTeamMembersStub.callCount);

          programAppComponent.find('.select-all-team-members').trigger('click');
          assert.equal(1, selectAllTeamMembersStub.callCount);

        });

        it('open add member pop up modal', (done) => {
          let addButton = programAppComponent.find('button.add-member');

          assert.equal(0, modalShowStub.callCount);
          addButton.trigger('click');
          setTimeout(()=> {
            assert.equal(1, modalShowStub.callCount);
            assert.equal(1, modalShowStub.args[0].length);
            assert.equal('add-member-pop-up', modalShowStub.args[0][0]);
            assert.equal(1, dispatchStub.callCount);
            assert.equal('fetchUsers', dispatchStub.args[0][0]);
            done();
          });
        });
      });
    });

    describe('Computed', () => {
      describe('ShouldDisplaySelectAllMembersLink', () => {
        it('should return true when displaySelectAllMembersLink is true and selected members are less than the total members', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name: "Program administrator", id: 'program_admin'}, email: "user1@some.com", selected: false},
            user3: {name: 'user3', login: "user3", role: {name: "Program administrator", id: 'program_admin'}, email: "user3@some.com", selected: true},
          };
          programAppComponent.setData({members:members, displaySelectAllMembersLink:true});
          assert.ok(programAppComponent.vm.shouldDisplaySelectAllMembersLink);
        });

        it('should return false when displaySelectAllMembersLink is true and all members are selected', () => {
          let members = {
            user1: {name: 'user1', login: "user1", role: {name: "Program administrator", id: 'program_admin'}, email: "user1@some.com", selected: true},
            user3: {name: 'user3', login: "user3", role: {name: "Program administrator", id: 'program_admin'}, email: "user3@some.com", selected: true},
          };
          programAppComponent.setData({members:members, displaySelectAllMembersLink:true});
          assert.ok(!programAppComponent.vm.shouldDisplaySelectAllMembersLink);
        });

      });
    });
  });

  describe('For Non admin user', function () {

    beforeEach(function () {
      programAppComponent = mount(ProgramTeam, {
        localVue,
        mocks: {
          $store: {
            state: {
              programTeam: {
                members: {
                  user1: {name: 'user1', login: "user1", projects: "project1", role: {name: "Program administrator", id: 'program_admin'}, email: "user1@some.com"},
                  user3: {name: 'user3', login: "user3", projects: "", role: {name: "Program administrator", id: 'program_admin'}, email: "user3@some.com"},
                  user2: {name: 'user2', login: "user2", projects: "project2", role: {name: "Program administrator", id: 'program_admin'}, email: "user2@some.com"},
                  user4: {name: 'user4', login: "user4", projects: "project2", role: {name: "Program administrator", id: 'program_admin'}, email: "user4@some.com"}
                },
                roles: [{id: 'program_admin', name: 'Program administrator'}, {id: 'program_member', name: 'Program member'}],
              },
              currentUser:{
                admin:false,name:'user4',login:'user4'
              }
            }

          }

        }
      });
    });

    describe('Renders', () => {
      it('should not render add team member', () => {
        assert.ok(!programAppComponent.find('button.add-member').exists());
      });

      it('should not render remove team member button', () => {
        let removeButton = programAppComponent.find('button.remove-member');
        assert.ok(!removeButton.exists());
      });

      it('should not render change role button', () => {
        let changeRoleButton = programAppComponent.find('#change_member_role button.drop-down-toggle');
        assert.ok(!changeRoleButton.exists());
      });

      it('should not render select all member heading', () => {
        let tableHeadings = programAppComponent.findAll('.VueTables__heading');

        assert.equal(5, tableHeadings.length);
        assert.equal("Name", tableHeadings.at(0).text());
        assert.equal("Sign-in name", tableHeadings.at(1).text());
        assert.equal("Projects", tableHeadings.at(2).text());
        assert.equal("Role", tableHeadings.at(3).text());
        assert.equal("Email", tableHeadings.at(4).text());

      });

      it('should render table with user list without select checkbox', () => {

        assert.equal(4, programAppComponent.findAll('tbody tr').length);
        let first_row = programAppComponent.findAll('tr').at(1);
        let second_row = programAppComponent.findAll('tr').at(2);

        assert.equal("user1", first_row.findAll('td').at(0).text());
        assert.equal("user1", first_row.findAll('td').at(1).text());
        assert.equal("project1", first_row.findAll('td').at(2).text());
        assert.equal("Program administrator", first_row.findAll('td').at(3).text());
        assert.equal("user1@some.com", first_row.findAll('td').at(4).text());

        assert.equal("user2", second_row.findAll('td').at(0).text());
        assert.equal("user2", second_row.findAll('td').at(1).text());
        assert.equal("project2", second_row.findAll('td').at(2).text());
        assert.equal("Program administrator", second_row.findAll('td').at(3).text());
        assert.equal("user2@some.com", second_row.findAll('td').at(4).text());
      });

      it('should not render members role rop down', () => {
        let first_row = programAppComponent.findAll('tr').at(1);
        let second_row = programAppComponent.findAll('tr').at(2);

        assert.ok(! first_row.find('#user1_role_dropdown').exists());
        assert.ok(! second_row.find('#user2_role_dropdown').exists());
      });
    });
  })


});
