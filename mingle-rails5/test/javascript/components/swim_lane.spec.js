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
import '../../../app/javascript/extentions/string'
import SwimLane from '../../../app/javascript/components/SwimLane';
import assert from "assert";
import sinon from 'sinon';
import {mount, createLocalVue} from '@vue/test-utils'

let localVue = createLocalVue();

let sandbox = sinon.createSandbox();

describe('SwimLane.vue', function () {
  beforeEach(() => {
    this.storeCommitStub = sandbox.stub();
    this.storeDispatchStub = sandbox.stub();
    this.swimLaneComponent = mount(SwimLane, {
      localVue,
      propsData: {
        objectives: [{
          name: 'Objective 2',
          number: 2,
          position: 2
        }, {name: 'Objective 1', number: 1, position: 1}], swimLaneName: 'BACKLOG'
      },
      mocks: {
        $store: {
          state: {
            toggles: {readOnlyModeEnabled: true}
          },
          commit: this.storeCommitStub,
          dispatch: this.storeDispatchStub,
        }
      }
    });

  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('Renders', () => {
    it('sets default data', () => {
      let {draggingInProgress} = SwimLane.data();
      assert.ok(!draggingInProgress);
    });

    it('should renders swim lane', () => {
      assert.ok(this.swimLaneComponent.findAll('#backlog_swim_lane.objectives-swim-lane').exists());
      assert.ok(this.swimLaneComponent.findAll('.objectives-swim-lane .objectives-swim-lane-header').exists());
    });

    it('should renders swim lane name in title case', () => {
      assert.equal(this.swimLaneComponent.find('.objectives-swim-lane .objectives-swim-lane-header').text(), 'Backlog (2)');
    });

    it('Backlog objective component', () => {
      assert.equal(this.swimLaneComponent.findAll('.objective').length, 2);
    });

    it('should add cell-highlighted class on swim lane', () => {
      assert.ok(!this.swimLaneComponent.findAll('.cell-highlighted').exists());
      this.swimLaneComponent.setData({draggingInProgress: true});

      assert.ok(this.swimLaneComponent.findAll('.cell-highlighted').exists());
    });
  });

  describe('Props', () => {
    describe('OrderedObjectives', () => {
      it('should sort objective by their positions', () => {
        assert.deepEqual(this.swimLaneComponent.vm.orderedObjectives, [
          {name: 'Objective 1', number: 1, position: 1},
          {name: 'Objective 2', number: 2, position: 2}
        ]);
      });

      it('should give empty objective collection when objective property is undefine', () => {
        this.swimLaneComponent.setProps({objectives:undefined});
        assert.deepEqual(this.swimLaneComponent.vm.orderedObjectives, []);
      });
    });
  });

  describe('Methods', () => {
    describe('DraggingStarted', () => {
      it('draggingStarted should set dragging in progress to true', () => {
        assert.ok(!this.swimLaneComponent.vm.draggingInProgress);

        this.swimLaneComponent.vm.draggingStarted();

        assert.ok(this.swimLaneComponent.vm.draggingInProgress);
      });

    });

    describe('DraggingEnded ', () => {
      it('should update objective order', () => {
        this.storeDispatchStub.returns(Promise.resolve(''));
        this.swimLaneComponent.vm.draggingInProgress = true;
        this.swimLaneComponent.vm.draggingEnded({item: {dataset: {objectiveNumber: 10}}});
        assert.ok(!this.swimLaneComponent.vm.draggingInProgress);

        assert.equal(this.storeDispatchStub.callCount, 1);
        assert.equal(this.storeDispatchStub.args[0][0], 'updateObjectivesOrder');
        assert.deepEqual(this.storeDispatchStub.args[0][1], [{
          name: 'Objective 1',
          number: 1,
          position: 1
        }, {name: 'Objective 2', number: 2, position: 2}]);
      });

      it('should update droppedObjectiveNumber', () => {
        this.storeDispatchStub.returns(Promise.resolve(''));
        assert.equal(this.swimLaneComponent.vm.droppedObjectiveNumber, null);

        this.swimLaneComponent.vm.draggingEnded({item: {dataset: {objectiveNumber: 10}}});
        assert.equal(this.swimLaneComponent.vm.droppedObjectiveNumber, 10);

        return localVue.nextTick().then(() => {
          assert.equal(this.swimLaneComponent.vm.droppedObjectiveNumber, null);
        })
      });
    });
  });
});
