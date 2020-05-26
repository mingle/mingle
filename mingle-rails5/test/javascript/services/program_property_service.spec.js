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
import ProgramPropertyService from "../../../app/javascript/services/program_properties_service";
import Api from "../../../app/javascript/services/api";


let sandbox = sinon.createSandbox();

describe('ObjectiveService', function () {
  let programPropertyService, server;
  beforeEach(() => {
    server = sandbox.useFakeServer();
    programPropertyService = new ProgramPropertyService('my_program', 'csrf-token')
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should extends Api', () => {
    assert.ok(programPropertyService instanceof Api);
  });

  describe('create', () => {
    it('should use correct url', () => {
      let property = {name: "something", description: "It is a property", type: "AnyText"};

      let responsePromise = programPropertyService.create(property);
      setTimeout(() => {
        let request = server.requests[0];
        assert.equal(1, server.requests.length);
        assert.equal("/api/internal/programs/my_program/objective_property_definitions", request.url);
        assert.equal("POST", request.method);
        request.respond(200, {}, 'Property');
      });
      return responsePromise.then((result) => {
        assert.ok(result.success);
        assert.equal('Property', result.property);
      });
    });

    it('should propagate the error message from create api for 422 response code', () => {
      let property = {name: "something", description: "It is a property", type: "AnyText"};

      let responsePromise = programPropertyService.create(property);
      setTimeout( () => {
        let request = server.requests[0];
        assert.equal(1, server.requests.length);
        assert.equal("/api/internal/programs/my_program/objective_property_definitions", request.url);
        assert.equal("POST", request.method);
        request.respond(422, {}, 'Error Message');
      });
      return responsePromise.then((result) => {
        assert.ok(!result.success);
        assert.equal('Error Message',result.error);
      });
    });
  });
});