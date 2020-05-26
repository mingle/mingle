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
import BacklogWall from '../../../app/javascript/components/BacklogWall';
import Vue from 'vue';
import assert from "assert";
import VModal from 'vue-js-modal';
import sinon from 'sinon';
import {mount, createLocalVue} from '@vue/test-utils'

let localVue = createLocalVue();
localVue.use(VModal);

let sandbox = sinon.createSandbox();

describe('BacklogWall.vue', () => {
  let programAppComponent, storeCommitStub, storeDispatchStub, showModalStub, storeGettersStub;
  beforeEach(function () {
    storeCommitStub = sandbox.stub();
    storeDispatchStub = sandbox.stub();
    showModalStub = sandbox.stub();
    storeGettersStub = { groupObjectiveBy:sandbox.stub()};
    storeGettersStub.groupObjectiveBy.returns({PLANNED:[{ name: 'Objective 1', number: 1, position: 1 },{ name: 'Objective 3', number: 3, position: 3 }], BACKLOG: [{ name: 'Objective 2', number: 2, position: 2 }]});
    programAppComponent = mount(BacklogWall,{
      localVue,
      propsData:{},
      mocks:{
        $store:{
          state: {
            objectives: [{ name: 'Objective 1', number: 1, position: 1 }, { name: 'Objective 2', number: 2, position: 2 }],
            nextObjectiveNumber:3,
            defaultObjectiveType:{value_statement:'Default value statement', property_definitions:{Property:{name:'Prop1', value:1}}},
            toggles: {readOnlyModeEnabled: false}
          },
          commit: storeCommitStub,
          dispatch: storeDispatchStub,
          getters: storeGettersStub
        },
        $modal:{
          show: showModalStub
        }
      }
    });

  });

  afterEach(function () {
    sandbox.restore();
  });

  describe('Renders', function () {
    it('sets default data', () => {
      let {draggingInProgress, newObjectiveName, objectivePopupName, modalComponent, modalConfig, objectivePopupParams }  = BacklogWall.data();

      assert.ok(!draggingInProgress);
      assert.equal(newObjectiveName, '');
      assert.equal(objectivePopupName, 'objective_popup');
      assert.equal(modalComponent.name, 'objective-popup');
      assert.deepEqual(modalConfig, {resizable: true,minWidth: 800,minHeight: 558,width: 800,height: 558,scrollable: true, reset: true});
      assert.deepEqual(objectivePopupParams, {popupResized: false, mode: 'VIEW'});
    });

    it('should renders swim lanes Backlog and Planned', () => {
      assert.equal(programAppComponent.findAll('.objectives-swim-lane').length, 2);
      assert.equal(programAppComponent.find('.objectives-swim-lane:nth-child(1) .objectives-swim-lane-header').text(), 'Backlog (1)');
      assert.equal(programAppComponent.find('.objectives-swim-lane:nth-child(2) .objectives-swim-lane-header').text(), 'Planned (2)');
    });

    it('Backlog objective component', () => {
      assert.equal(storeGettersStub.groupObjectiveBy.callCount, 1);
      assert.equal(storeGettersStub.groupObjectiveBy.args[0][0], 'status');
      assert.equal(programAppComponent.findAll('.objective').length, 3);
    });

    it('Create Objective Text Box and Button when readOnlyMode is toggled off', () => {
      let inputBox = programAppComponent.find('div.add-objective-container input.new-objective-name');
      let createButton = programAppComponent.find('div.add-objective-container button.create-objective.primary');

      assert.ok(inputBox);
      assert.equal(inputBox.attributes().placeholder, 'Create a new objective for your program');
      assert.equal(createButton.text().trim(), 'CREATE');
      assert.equal(createButton.attributes().disabled, 'disabled');
    });

    it('should not render Create Objective Text Box and Button when readOnlyMode is toggled on', () => {
      programAppComponent = mount(BacklogWall,{
        localVue,
        propsData:{},
        mocks:{
          $store:{
            state: {
              objectives: [{ name: 'Objective 1', number: 1, position: 1 }, { name: 'Objective 2', number: 2, position: 2 }],
              nextObjectiveNumber:3,
              defaultObjectiveType:{value_statement:'Default value statement', property_definitions:{Property:{name:'Prop1', value:1}}},
              toggles: {readOnlyModeEnabled: true}
            },
            commit: storeCommitStub,
            dispatch: storeDispatchStub,
            getters: storeGettersStub
          },
          $modal:{
            show: showModalStub
          }
        }
      });

      let inputBox = programAppComponent.find('div.add-objective-container input.new-objective-name');
      let createButton = programAppComponent.find('div.add-objective-container button.create-objective.primary');

      assert.ok(!inputBox.exists());
      assert.ok(!createButton.exists());
    });

    it('should display cursor in default style when readOnlyMode is toggled on', () => {
      programAppComponent = mount(BacklogWall,{
        localVue,
        propsData:{},
        mocks:{
          $store:{
            state: {
              objectives: [{ name: 'Objective 1', number: 1, position: 1 }, { name: 'Objective 2', number: 2, position: 2 }],
              nextObjectiveNumber:3,
              defaultObjectiveType:{value_statement:'Default value statement', property_definitions:{Property:{name:'Prop1', value:1}}},
              toggles: {readOnlyModeEnabled: true}
            },
            commit: storeCommitStub,
            dispatch: storeDispatchStub,
            getters: storeGettersStub
          },
          $modal:{
            show: showModalStub
          }
        }
      });
      assert.ok(programAppComponent.find('.objective').hasStyle('cursor','default'));
    });

    it('button should be enabled if valid text is set', done => {
      let createButton = programAppComponent.find('div.add-objective-container button.primary');
      programAppComponent.setData({newObjectiveName:'blah'});

      Vue.nextTick(() => {
        assert.ok(!createButton.attributes().disabled);
        programAppComponent.setData({newObjectiveName:'    '});
        Vue.nextTick(() => {
          assert.equal(createButton.attributes().disabled, 'disabled');
          done();
        })
      });
    });
  });

  describe('Interactions', () => {
    describe('Click', () => {
      it('on create button should invoke openAddObjectivePopup', (done) => {
        let openAddObjectivePopupStub = sandbox.stub();
        programAppComponent.setData({newObjectiveName:'blah'});
        programAppComponent.setMethods({openAddObjectivePopup:openAddObjectivePopupStub});

        setTimeout(()=> {
          programAppComponent.find('.create-objective').trigger('click');
          assert.equal(openAddObjectivePopupStub.callCount, 1);
          done();
        });
      });
    });
    describe('Enter', () => {
      it('on new objective name input box should invoke openAddObjectivePopup', (done) => {
        let openAddObjectivePopupStub = sandbox.stub();
        programAppComponent.setData({newObjectiveName:'blah'});
        programAppComponent.setMethods({openAddObjectivePopup:openAddObjectivePopupStub});

        setTimeout(()=> {
          programAppComponent.find('.new-objective-name').trigger('keyup.enter');
          assert.equal(openAddObjectivePopupStub.callCount, 1);
          done();
        });
      });
    });
  });
  describe('Methods', function () {
    describe('OpenAddObjectivePopup ', () => {
      it('should dispatch updateCurrentObjectiveToDefault and show popup in ADD mode', function () {
        programAppComponent.setData({newObjectiveName:'name'});
        assert.equal('VIEW', programAppComponent.vm.objectivePopupParams.mode );

        programAppComponent.vm.openAddObjectivePopup();

        assert.equal(storeDispatchStub.callCount, 1);
        assert.equal(storeDispatchStub.args[0][0], 'updateCurrentObjectiveToDefault');
        assert.deepEqual(storeDispatchStub.args[0][1], {
          name: 'name', number: 3, value_statement: 'Default value statement',
          property_definitions: {Property: {name: 'Prop1', value: 1}}
        });

        assert.equal('ADD',programAppComponent.vm.objectivePopupParams.mode );

        assert.equal(showModalStub.callCount, 1);
        assert.equal(showModalStub.args[0].length, 1);
        assert.deepEqual(showModalStub.args[0][0], 'objective_popup');
      });

      it('should invoke resetNewObjectiveName', () => {
        let resetNewObjectiveNameSpy = sandbox.spy();
        programAppComponent.setData({newObjectiveName:'name'});
        programAppComponent.setMethods({resetNewObjectiveName: resetNewObjectiveNameSpy});

        assert.equal(resetNewObjectiveNameSpy.callCount, 0);
        programAppComponent.vm.openAddObjectivePopup();

        assert.equal(resetNewObjectiveNameSpy.callCount, 1);
      });
    });

    describe('ResetNewObjectiveName', () => {
      it('should set newObjectiveName to empty', () => {
        programAppComponent.setData({newObjectiveName:'name'});
        programAppComponent.vm.resetNewObjectiveName();
        assert.equal(programAppComponent.vm.newObjectiveName, '');
      });
    });

    describe('OpenObjectivePopup ', () => {
      it('should show modal and invoke resetNewObjectiveName', () => {
        let resetNewObjectiveNameSpy = sandbox.spy();
        programAppComponent.setData({newObjectiveName:'name'});
        programAppComponent.setMethods({resetNewObjectiveName: resetNewObjectiveNameSpy});

        assert.equal(resetNewObjectiveNameSpy.callCount, 0);
        assert.equal(showModalStub.callCount, 0);
        programAppComponent.vm.openObjectivePopup();

        assert.equal(resetNewObjectiveNameSpy.callCount, 1);
        assert.equal(showModalStub.callCount, 1);
        assert.equal(showModalStub.args[0][0], 'objective_popup');
      });

      it('should show popup in VIEW mode', () => {
        programAppComponent.setData({objectivePopupParams: {mode:'ADD'}});
        programAppComponent.vm.openObjectivePopup();

        assert.equal('VIEW',programAppComponent.vm.objectivePopupParams.mode);
      });
    });

    describe('ResizeEditor ', () => {
      it('resizeEditor should toggle popupResized on objectivePopupParams', () => {
        assert.ok(!programAppComponent.vm.objectivePopupParams.popupResized);
        programAppComponent.vm.resizeEditor();
        assert.ok(programAppComponent.vm.objectivePopupParams.popupResized);
      });
    });
  });
});
