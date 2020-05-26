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
import createStore from '../../../app/javascript/stores/objectives';

Vue.use(Vuex);

let sandbox = sinon.createSandbox();
let fakeObjectiveService = {
  reorder:()=>{}, fetchFor:()=>{}, delete:()=>{}, update: ()=>{}, planObjective: ()=>{}, create:()=>{}, changePlan:()=>{}
};

describe('ObjectiveStore', function () {
  let objectives, objectivesStore, objectivesServiceStub, reversedObjectives,nextObjectiveNumber;
  beforeEach(() => {
    nextObjectiveNumber = 12;
    objectives = [{name: 'Objective 1', number: 1, position: 1}, {name: 'Objective 2', number: 2, position: 2}, {name: 'Objective 3', number: 3, position: 3}];
    reversedObjectives =  [...objectives].reverse();
    objectivesServiceStub = sandbox.stub();
    objectivesStore = createStore(fakeObjectiveService, {
      objectives: objectives,
      nextObjectiveNumber: nextObjectiveNumber
    });
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('Initialization', function () {
    it('should not disable dragging', function ( ) {
      assert.ok( !objectivesStore.state.disableDragging);
    });

    it('should set initial backlog objectives data', function () {
      assert.deepEqual(objectives, objectivesStore.state.objectives);
    });

    it('should have next backlog objective number', () => {
      assert.equal(objectivesStore.state.nextObjectiveNumber, nextObjectiveNumber);
    });

    it('should set toggles module', () => {
      objectivesStore = createStore(fakeObjectiveService, {
        objectives: objectives,
        nextObjectiveNumber: nextObjectiveNumber,
        toggles: {toggle1: true, toggle2: false}
      });
      assert.ok(objectivesStore.state.toggles.toggle1);
      assert.ok(!objectivesStore.state.toggles.toggle2);
    });
  });

  describe('Getters', () => {
    describe('GroupObjectiveBy', () => {
      beforeEach(() => {
        let objectives = [
          {name: 'Objective 1', number: 1, position: 1, status: 'PLANED'},
          {name: 'Objective 2', number: 2, position: 2, status: 'PLANED'},
          {name: 'Objective 3', number: 3, position: 3, status: 'BACKLOG'}
        ];
        this.objectivesStore  = createStore(fakeObjectiveService, {objectives: objectives,nextObjectiveNumber: nextObjectiveNumber});
      });
      it('should group objectives by given prop', () => {
        this.objectivesStore.getters.groupObjectiveBy('status');

        let expectedGroupedObjectives = {
          PLANED: [{name: 'Objective 1', number: 1, position: 1, status: 'PLANED'}, {
            name: 'Objective 2',
            number: 2,
            position: 2,
            status: 'PLANED'
          }],
          BACKLOG: [{name: 'Objective 3', number: 3, position: 3, status: 'BACKLOG'}]
        };
        assert.deepEqual(expectedGroupedObjectives, this.objectivesStore.getters.groupObjectiveBy('status'));
      });
    });
  });

  describe('Mutations', function () {
    describe('UpdateMessage',function(){
      it('should update message in state', function (done) {
        let expectedMessage = {type: 'success', text: 'some text'};
        objectivesStore.commit('updateMessage', expectedMessage);

        setTimeout(() => {
          assert.deepEqual(expectedMessage, objectivesStore.state.message);
          done();
        });
      });
    });

    describe('deleteObjective', function () {
      it('should remove the objective from the state', function () {
        objectivesStore.commit('deleteObjective', 2);

        assert.equal(2, objectivesStore.state.objectives.length);
        assert.deepEqual(["Objective 1", "Objective 3"], objectivesStore.state.objectives.map(function (o) { return o.name }));
      });
    });

    describe('updateCurrentObjective', function () {
      it('should set current backlog objective on state', function () {
        let value = {number:12, value_statement:'value_statement'};
        objectivesStore.commit('updateCurrentObjective', value);

        assert.deepEqual(objectivesStore.state.currentObjectiveData, value);
      });
    });

    describe('updateObjectives', function() {
      it('should update backlogobjectives with the updated backlogobjective', function(){
        let updatedObjective = { name: 'Updated objective', number: 1}
        assert.deepEqual(["Objective 1", "Objective 2", "Objective 3"], objectivesStore.state.objectives.map(function (o) { return o.name }));
        objectivesStore.commit('updateObjectives', updatedObjective);

        assert.deepEqual(["Updated objective", "Objective 2", "Objective 3"], objectivesStore.state.objectives.map(function (o) { return o.name }));

      });
    });

    describe('UpdateNextObjectiveNumber', () => {
      it('should update nextObjectiveNumber', () => {
        objectivesStore.commit('updateNextObjectiveNumber',23);

        assert.equal(objectivesStore.state.nextObjectiveNumber, 23);
      });
    });

    describe('AddNewObjective', function () {
      it('should add the new backlog objective to backlog objectives state', () => {
        let objectiveData = {name: 'Name', number: 10, position: 2};
        objectivesStore.commit('addNewObjective', objectiveData);
        assert.equal(objectivesStore.state.objectives.indexOf(objectiveData), 0 );
      });
    });
  });

  describe('Actions',function(){
    beforeEach(() => {
      sandbox.stub(objectivesStore, 'commit');
    });

    describe('FetchObjectiveData', function(){
      it('should yield with result from service call and data on successful fetching', function () {
        let expectedResult = {success: true, data: 'data'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'fetchFor').returns(promise);

        return objectivesStore.dispatch('fetchObjective', objectiveNumber).then((result) =>{
          assert.deepEqual(expectedResult, result);
          assert.equal(objectivesStore.commit.callCount, 1);
          assert.equal(objectivesStore.commit.args[0][0], 'updateCurrentObjective');
        });
      });

      it('should update the message and delete the objective when the service returns deleted error', function () {
        let expectedResult = {success: false, error: 'Backlog objective not found', errorType: "deleted"};
        let promise = Promise.resolve(expectedResult);
        sandbox.stub(fakeObjectiveService, 'fetchFor').returns(promise);

        return objectivesStore.dispatch('fetchObjective',1).then((result)=>{
          assert.ok(!result.success);
          assert.equal(objectivesStore.commit.callCount, 2);
          assert.equal(objectivesStore.commit.args[0][0], 'deleteObjective');
          assert.equal(objectivesStore.commit.args[0][1], 1);
          assert.equal(objectivesStore.commit.args[1][0], 'updateMessage');
          assert.deepEqual(objectivesStore.commit.args[1][1], {type: 'error', text: expectedResult.error});
        });
      });

      it('should update the message on the objective when the service returns an error', function () {
        let expectedResult = {success: false, error: 'Something went wrong'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'fetchFor').returns(promise);

        return objectivesStore.dispatch('fetchObjective', objectiveNumber).then((result) =>{
          assert.ok( !result.success);
          assert.equal(objectivesStore.commit.callCount, 1);
          assert.equal(objectivesStore.commit.args[0].length, 2);

          assert.equal(objectivesStore.commit.args[0][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[0][1], {type: "error", text: "Something went wrong"})
        });
      });

    });

    describe('DeleteObjectives', function() {
      it('should yield with result from service call and trigger updateMessage mutation', function () {
        let expectedResult = {success: true};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'delete').returns(promise);

        return objectivesStore.dispatch('deleteObjective', objectiveNumber).then((result) =>{
          assert.equal(expectedResult, result);
          assert.equal(2, objectivesStore.commit.callCount);
          assert.equal(2, objectivesStore.commit.args[0].length);
          assert.equal("deleteObjective", objectivesStore.commit.args[0][0]);
          assert.equal(objectiveNumber, objectivesStore.commit.args[0][1]);

          assert.equal(2, objectivesStore.commit.args[1].length);
          assert.equal("updateMessage", objectivesStore.commit.args[1][0]);
          assert.deepEqual({type: "success", text: "Objective #1 was deleted successfully."}, objectivesStore.commit.args[1][1])
        });
      });

      it('should not trigger delete mutation and updates error message when service responds with failure', function () {
        let expectedResult = {success: false, error: 'something went wrong'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'delete').returns(promise);

        return objectivesStore.dispatch('deleteObjective', objectiveNumber).then((result) =>{
          assert.equal(result, expectedResult);
          assert.equal(1, objectivesStore.commit.callCount);
          assert.equal(2, objectivesStore.commit.args[0].length);
          assert.equal("updateMessage", objectivesStore.commit.args[0][0]);
          let message = objectivesStore.commit.args[0][1];
          assert.equal("error", message.type);
          assert.equal('something went wrong', message.text);
        });
      })
    });

    describe('UpdateCurrentObjective', function() {
      it('should yield with result from service call and trigger updateMessage and updateCurrentObjective mutation', function () {
        let objective = {number:12, value_statement:'Changed value', name:'Name'};
        let expectedResult = {success: true, data:objective};
        let promise = Promise.resolve(expectedResult);

        sandbox.stub(fakeObjectiveService, 'update').returns(promise);

        return objectivesStore.dispatch('updateCurrentObjective', {objectiveData:objective, scopedMessage:true, eventName: 'Save and Close'}).then((result) =>{
          assert.deepEqual(result, {success: true, data: objective});
          assert.equal(objectivesStore.commit.callCount, 3);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[0][0], "updateCurrentObjective");
          assert.equal(objectivesStore.commit.args[0][1], objective);

          assert.equal(objectivesStore.commit.args[1].length, 2);
          assert.equal(objectivesStore.commit.args[1][0], "updateObjectives");
          assert.equal(objectivesStore.commit.args[1][1], objective);

          assert.equal(objectivesStore.commit.args[2].length, 2);
          assert.equal(objectivesStore.commit.args[2][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[2][1], {type: "success", text: `Objective #${objective.number} was updated successfully.`})
        });
      });

      it('should trigger updateMessage mutation when errorType is deleted', function () {
        let objective = {number:12, value_statement:'Changed value', name:'Name'};
        let expectedResult = {success: false, errorType: 'deleted'};
        let promise = Promise.resolve(expectedResult);
        sandbox.stub(fakeObjectiveService, 'update').returns(promise);

        return objectivesStore.dispatch('updateCurrentObjective', {objectiveData:objective, scopedMessage:true}).then((result) =>{
          assert.equal(objectivesStore.commit.callCount, 1);
          assert.equal(objectivesStore.commit.args[0][0], "updateMessage");
          assert.deepEqual(result, {success: false, errorType:'deleted'});
        });
      });

      it('should not trigger updateMessage mutation when eventType is Save', function () {
        let objective = {number:12, value_statement:'Changed value', name:'Name'};
        let expectedResult = {success: false, error: 'something went wrong'};
        let promise = Promise.resolve(expectedResult);
        sandbox.stub(fakeObjectiveService, 'update').returns(promise);

        return objectivesStore.dispatch('updateCurrentObjective', {objectiveData:objective, scopedMessage:true, eventName: 'Save'}).then((result) =>{
          assert.equal(objectivesStore.commit.callCount, 0);
          assert.deepEqual(result, {success: false, message:{type:'error', text:'something went wrong'}});
        });
      })

      it('should trigger updateMessage mutation when eventType is Save and Close', function () {
        let objective = {number:12, value_statement:'Changed value', name:'Name'};
        let expectedResult = {success: true, data:objective};
        let promise = Promise.resolve(expectedResult);
        sandbox.stub(fakeObjectiveService, 'update').returns(promise);

        return objectivesStore.dispatch('updateCurrentObjective', {objectiveData:objective, scopedMessage:true, eventName: 'Save and Close'}).then((result) =>{
          assert.equal(objectivesStore.commit.callCount, 3);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[2][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[2][1], {type: "success", text: `Objective #${objective.number} was updated successfully.`})
        });
      })
    });
    describe('PlanObjective',function(){
      it('should get result from service call and trigger updateMessage mutation and delete the objective from wall when it is a 404', function(){
        let expectedResult = {success:false, error: 'Backlog objective not found.', errorType: 'deleted'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'planObjective').returns(promise);

        return objectivesStore.dispatch('planObjective', objectiveNumber).then((result) =>{
          assert.equal(expectedResult, result);
          assert.equal(objectivesStore.commit.callCount, 2);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[0][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[0][1], {type: "error", text: "Backlog objective not found."})

          assert.equal(objectivesStore.commit.args[1].length, 2);
          assert.equal(objectivesStore.commit.args[1][0], "deleteObjective");
          assert.equal(objectivesStore.commit.args[1][1], objectiveNumber);
        });

      });

      it('should get result from service call and trigger updateMessage mutation when it is a 5xx', function(){
        let expectedResult = {success:false, error: 'error'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'planObjective').returns(promise);

        return objectivesStore.dispatch('planObjective', objectiveNumber).then((result) =>{
          assert.equal(expectedResult, result);
          assert.equal(objectivesStore.commit.callCount, 1);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[0][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[0][1], {type: "error", text: "error"});
        });

      })
    });

    describe('UpdateCurrentObjectiveToDefault',function(){
      it('should trigger updateCurrentObjective mutation', () => {
        let objectiveData = {name:'new backlog objective', number:23, value_statement:'value_statement'};
        objectivesStore.dispatch('updateCurrentObjectiveToDefault', objectiveData);

        assert.equal(objectivesStore.commit.callCount, 1);
        assert.equal(objectivesStore.commit.args[0][0], 'updateCurrentObjective');
        assert.equal(objectivesStore.commit.args[0][1], objectiveData);
      });
    });

    describe('CreateObjective', function () {
      it('should yield with result from service and commit addNewObjective mutation', function () {
        let objective = {value_statement: 'new value statement',value:0,size:2, position:1, name: 'Name', number:2, status:'BACKLOG'};
        let expectedResult = {success: true, data: objective};
        let promise = Promise.resolve(expectedResult);

        sandbox.stub(fakeObjectiveService, 'create').returns(promise);

        return objectivesStore.dispatch('createObjective', {objectiveData: objective}).then((result) => {

          assert.deepEqual(result, {success: true});
          assert.equal(objectivesStore.commit.callCount, 3);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[0][0], "addNewObjective");
          assert.deepEqual(objectivesStore.commit.args[0][1], {name:'Name', position:1, number:2, value: 0, size: 2, status:'BACKLOG'});

          assert.equal(objectivesStore.commit.args[1].length, 2);
          assert.equal(objectivesStore.commit.args[1][0], "updateCurrentObjective");
          assert.deepEqual(objectivesStore.commit.args[1][1], objective);

          assert.equal(objectivesStore.commit.args[2].length, 2);
          assert.equal(objectivesStore.commit.args[2][0], "updateNextObjectiveNumber");
          assert.equal(objectivesStore.commit.args[2][1], 3);
        });
      });

      it('should not trigger addNewObjective mutation when service responds with failure', function () {
        let objective = {value_statement:'value', name:'Name'};
        let promise = Promise.resolve({success: false, error: 'something went wrong'});
        sandbox.stub(fakeObjectiveService, 'create').returns(promise);

        return objectivesStore.dispatch('createObjective', {objectiveData: objective}).then((result) =>{
          assert.deepEqual(result, {success: false, message: {type: 'error', text: 'something went wrong'} });
          assert.equal(objectivesStore.commit.callCount, 0);
        });
      });
    });

    describe('UpdateObjectivesOrder', function () {

      it('should disable dragging till ajax call finishes', function () {
        sandbox.stub(fakeObjectiveService,'reorder').returns(new Promise(()=>{}, ()=>{}));

        objectivesStore.dispatch('updateObjectivesOrder', objectives.reverse());

        assert.ok(objectivesStore.state.disableDragging);
      });

      it('should enable dragging on ajax success', function () {
        let promise = Promise.resolve('Ajax success');
        sandbox.stub(fakeObjectiveService, 'reorder').returns(promise);

        return objectivesStore.dispatch('updateObjectivesOrder', objectives.reverse()).then(() => {
          assert.ok(!objectivesStore.state.disableDragging);
        });
      });

      it('should enable dragging on ajax failure', function () {
        let promise = Promise.reject("Ajax failure");

        sandbox.stub(fakeObjectiveService, 'reorder').returns(promise);

        return objectivesStore.dispatch('updateObjectivesOrder', reversedObjectives).then(() => {
          assert.ok(!objectivesStore.state.disableDragging);
        });
      });

      it('should set updated objective positions on success', function () {
        let promise = Promise.resolve({data: reversedObjectives});
        sandbox.stub(fakeObjectiveService, 'reorder').returns(promise);

        return objectivesStore.dispatch('updateObjectivesOrder', reversedObjectives).then(() => {
          assert.deepEqual(reversedObjectives, objectivesStore.state.objectives);
        });
      });

      it('should retain objective current positions on failure', function () {
        let promise = Promise.reject('Ajax failure');
        sandbox.stub(fakeObjectiveService, 'reorder').returns(promise);

        return objectivesStore.dispatch('updateObjectivesOrder', reversedObjectives).then(() => {
          assert.deepEqual(objectives, objectivesStore.state.objectives);
        });
      });
    });

    describe('ChangeObjectivePlan',function(){
      it('should get result from service call and trigger updateMessage mutation and delete the objective from wall when it is a 404', function(){
        let expectedResult = {success:false, error: 'Objective not found.', errorType: 'deleted'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'changePlan').returns(promise);

        return objectivesStore.dispatch('changeObjectivePlan', objectiveNumber).then((result) =>{
          assert.equal(expectedResult, result);
          assert.equal(objectivesStore.commit.callCount, 2);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[0][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[0][1], {type: "error", text: "Objective not found."});

          assert.equal(objectivesStore.commit.args[1].length, 2);
          assert.equal(objectivesStore.commit.args[1][0], "deleteObjective");
          assert.equal(objectivesStore.commit.args[1][1], objectiveNumber);
        });

      });

      it('should get result from service call and trigger updateMessage mutation when it is a 5xx', function(){
        let expectedResult = {success:false, error: 'error'};
        let promise = Promise.resolve(expectedResult);
        let objectiveNumber = 1;
        sandbox.stub(fakeObjectiveService, 'changePlan').returns(promise);

        return objectivesStore.dispatch('changeObjectivePlan', objectiveNumber).then((result) =>{
          assert.equal(expectedResult, result);
          assert.equal(objectivesStore.commit.callCount, 1);
          assert.equal(objectivesStore.commit.args[0].length, 2);
          assert.equal(objectivesStore.commit.args[0][0], "updateMessage");
          assert.deepEqual(objectivesStore.commit.args[0][1], {type: "error", text: "error"});
        });

      })
    });
  });
});
