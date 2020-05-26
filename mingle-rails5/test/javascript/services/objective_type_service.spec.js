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
import ObjectivesTypeService from "../../../app/javascript/services/objective_types_service";
import Api from "../../../app/javascript/services/api";


let sandbox = sinon.createSandbox();

describe('ObjectiveService', function () {
  let objectiveTypesService, server;
  beforeEach(() => {
    server = sandbox.useFakeServer();
    objectiveTypesService = new ObjectivesTypeService('my_program', 'csrf-token')
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should extends Api', () => {
    assert.ok(objectiveTypesService instanceof Api);
  });

  describe('Update', function () {
    it('should be successful', function () {
      let changedObjectiveType = {name: 'newName', value_statement: 'Changed value', id: 12};
      let responsePromise = objectiveTypesService.update(changedObjectiveType);
      setTimeout(function () {
        console.log("server.requests.length", server.requests.length);
        assert.equal(1, server.requests.length);
        assert.equal("/api/internal/programs/my_program/objective_types/12", server.requests[0].url);
        assert.equal("PUT", server.requests[0].method);
        server.requests[0].respond(200, {}, JSON.stringify(changedObjectiveType));
      });
      return responsePromise.then(function (result) {
        assert.ok(result.success);
        assert.deepEqual(result.objectiveType, changedObjectiveType);
      });
    });

    it('should give error message for 404 response', function () {
      let responsePromise = objectiveTypesService.update({id: 23, value_statement: 'Changed value', name: 'blah'});
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(404);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("ObjectiveType not found.", result.error);
      });
    });

    it('should give error message for a 5XX error response', function () {
      let responsePromise = objectiveTypesService.update({id: 23, value_statement: 'Changed value', name: 'blah'});
      setTimeout(function () {
        assert.equal(1, server.requests.length);
        server.requests[0].respond(500);
      });
      return responsePromise.then(function (result) {
        assert.ok(!result.success);
        assert.equal("Something went wrong while updating objective default.", result.error);
      });
    });

  });
});