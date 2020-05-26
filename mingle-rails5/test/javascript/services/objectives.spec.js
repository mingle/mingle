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
import sinon from 'sinon';
import Tracker from '../../../app/javascript/tracker'
import ObjectivesService from "../../../app/javascript/services/objectives";
import utils from '../../../app/javascript/services/utils/objectives_util'
import Api from "../../../app/javascript/services/api";


let sandbox = sinon.createSandbox();

describe('ObjectiveService', function () {
  let objectivesService, server, tracker;
  beforeEach(() => {
    tracker = new Tracker();
    sandbox.spy(tracker, 'track');
    server = sandbox.useFakeServer();
    objectivesService = new ObjectivesService('/base_url', 'csrf-token', tracker)
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should extends Api', () => {
    assert.ok(objectivesService instanceof Api);
  });
  describe('Reorder', function () {
    it('should use correct url and params', function (done) {
      let expectedParams = {ordered_backlog_objective_numbers: [1, 2, 3, 4]};
      objectivesService.reorder(expectedParams);

      setTimeout(function () {
        let request = server.requests[0];
        assert.equal('/base_url/reorder', request.url);
        assert.equal('csrf-token', request.requestHeaders['X-CSRF-TOKEN']);
        done();
      })
    });
  });

  describe('FetchFor', function () {

    it('should be a successful fetch', function () {
      let responsePromise = objectivesService.fetchFor(1);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        assert.equal("/base_url/1", server.requests[0].url);
        assert.equal("GET", server.requests[0].method);
        server.requests[0].respond(200);
      });
      return responsePromise.then(function (result) {
        assert.ok(result.success);
      });
    });

    it('should give error message for 404 response when the backlog objective is not found', function () {
      let responsePromise = objectivesService.fetchFor(1);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(404);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Objective not found.", result.error);
        assert.equal("deleted", result.errorType);
      });
    });

    it('should give error message for a 5XX error response', function () {
      let responsePromise = objectivesService.fetchFor(1);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(500);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Something went wrong while fetching objective.", result.error);
      });
    });
  });

  describe('delete', function () {
    it('should be a successful delete', function () {
      let responsePromise = objectivesService.delete(1);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        assert.equal("/base_url/1", server.requests[0].url);
        assert.equal("DELETE", server.requests[0].method);
        server.requests[0].respond(204);
      });
      return responsePromise.then(function (result) {
        assert.ok(result.success);
        assert.equal(1, tracker.track.callCount);
        assert.equal(1, tracker.track.args[0].length);
        assert.equal('program_delete_objective', tracker.track.args[0][0]);
      });
    });

    it('should give error message for 404 response', function () {
      let responsePromise = objectivesService.delete(1);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(404);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Objective not found.", result.error);
        assert.equal(0, tracker.track.callCount);
      });
    });

    it('should give error message for a 5XX error response', function () {
      let responsePromise = objectivesService.delete(1);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(500);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal(0, tracker.track.callCount);
        assert.equal("Something went wrong while deleting objective.", result.error);
      });
    });

  });

  describe('Update', function () {
    it('should be successful', function () {
      let changedObjective = {number: 23, value_statement: 'Changed value'};
      let responsePromise = objectivesService.update(changedObjective);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        assert.equal("/base_url/23", server.requests[0].url);
        assert.equal("PUT", server.requests[0].method);
        server.requests[0].respond(200, {}, JSON.stringify(changedObjective));

      });
      return responsePromise.then(function (result) {
        assert.ok(result.success);
        assert.deepEqual(result.data, changedObjective);
      });
    });

    it('should give error message for 404 response', function () {
      let responsePromise = objectivesService.update({number: 23, value_statement: 'Changed value'});
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(404);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Objective not found.", result.error);
      });
    });

    it('should give error message for a 5XX error response', function () {
      let responsePromise = objectivesService.update({number: 23, value_statement: 'Changed value'});
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(500);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Something went wrong while updating objective.", result.error);
      });
    });

    it('should propagate the error message from backlog objective update api for 422 response code', () => {
      let responsePromise = objectivesService.update({number: 23, value_statement: 'Changed value'});
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(422, {}, "Name can't be blank");
      });

      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Name can't be blank", result.error);
      });
    });

  });

  describe('PlanObjectiveFor', function () {
    it('should plan objective', function () {
      let responsePromise = objectivesService.planObjective(1);
      let utilStub = sandbox.stub(utils, 'redirect');

      setTimeout(function () {
        assert.equal(1, server.requests.length);
        assert.equal("/base_url/1/plan", server.requests[0].url);
        assert.equal("POST", server.requests[0].method);
        server.requests[0].respond(200);
      });
      return responsePromise.then(function (result) {
        assert.ok(result.success);
        assert.equal(1, utilStub.callCount)
        assert.equal(1, tracker.track.callCount);
        assert.equal(1, tracker.track.args[0].length);
        assert.equal('program_plan_objective', tracker.track.args[0][0]);
      });
    });

    it('should give error message for 404 response', function () {
      let responsePromise = objectivesService.planObjective(23);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(404);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Objective not found.", result.error);
      });
    });

    it('should give error message for a 5XX error response', function () {
      let responsePromise = objectivesService.planObjective(23);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(500);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Something went wrong while planning objective.", result.error);
      });
    });

  });

  describe('ChangePlan', function () {
    it('should change objective plan', function () {
      let responsePromise = objectivesService.changePlan(1);
      let utilStub = sandbox.stub(utils, 'redirect');

      setTimeout(function () {
        assert.equal(1, server.requests.length);
        assert.equal("/base_url/1/change_plan", server.requests[0].url);
        assert.equal("POST", server.requests[0].method);
        server.requests[0].respond(200);
      });
      return responsePromise.then(function (result) {
        assert.ok(result.success);
        assert.equal(1, utilStub.callCount);
        assert.equal(1, tracker.track.callCount);
        assert.equal(1, tracker.track.args[0].length);
        assert.equal('program_change_objective_plan', tracker.track.args[0][0]);
      });
    });

    it('should give error message for 404 response', function () {
      let responsePromise = objectivesService.changePlan(23);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(404);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Objective not found.", result.error);
      });
    });

    it('should give error message for a 5XX error response', function () {
      let responsePromise = objectivesService.changePlan(23);
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(500);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Something went wrong while planning objective.", result.error);
      });
    });

  });

  describe('Create', () => {
    it('should return the new objective on successful response', () => {
      let objectiveData = {name:'Objective name',value_statement: 'value_statement', value:0, size:0};
      let newObjective = Object.assign({number:1}, objectiveData );
      let responsePromise = objectivesService.create(objectiveData);

      setTimeout(function () {
        assert.equal(server.requests.length, 1);
        assert.equal(server.requests[0].url, '/base_url');
        assert.equal(server.requests[0].method, 'POST');
        assert.deepEqual(server.requests[0].requestBody, JSON.stringify({backlog_objective:objectiveData}));
        server.requests[0].respond(201, {}, JSON.stringify(newObjective));
      });
      return responsePromise.then((response)=>{
        assert.ok(response.success);
        assert.deepEqual(response.data, newObjective);
        assert.equal(1, tracker.track.callCount);
        assert.equal(1, tracker.track.args[0].length);
        assert.equal('program_create_objective', tracker.track.args[0][0]);
      });
    });

    it('should return error on failure', () => {
      let objectiveData = {name:'Duplicate name',value_statement: 'value_statement', value:0, size:0};
      let responsePromise = objectivesService.create(objectiveData);

      setTimeout(function () {
        assert.equal(server.requests.length, 1);
        assert.equal(server.requests[0].url, '/base_url');
        assert.equal(server.requests[0].method, 'POST');
        server.requests[0].respond(422, {}, 'Name already exists in your plan');
      });
      return responsePromise.then((response)=>{
        assert.ok(!response.success);
        assert.equal(response.error, 'Name already exists in your plan');
      });
    });

    it('should return unhandled error message on failure', () => {
      let objectiveData = {name:'Duplicate name',value_statement: 'value_statement', value:0, size:0};
      let responsePromise = objectivesService.create(objectiveData);

      setTimeout(function () {
        assert.equal(server.requests.length, 1);
        assert.equal(server.requests[0].url, '/base_url');
        assert.equal(server.requests[0].method, 'POST');
        server.requests[0].respond(500);
      });
      return responsePromise.then((response)=>{
        assert.ok(!response.success);
        assert.equal(response.error, 'Something went wrong while creating objective.');
      });
    });
  });
});