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
import ProgramTeamService from "../../../app/javascript/services/program_team_service";
import Api from "../../../app/javascript/services/api";


let sandbox = sinon.createSandbox();

describe('ProgramTeamService', function () {
  beforeEach(() => {
    this.server = sandbox.useFakeServer();
    this.programTeamService = new ProgramTeamService('/base_url', 'csrf-token')
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should extends Api', () => {
    assert.ok(this.programTeamService instanceof Api);
  });
  describe('BulkRemove', () => {
    it('should use correct url and params', () => {
      let expectedParams = ['user1', 'user2','user3'];
      let responsePromise = this.programTeamService.bulkRemove(expectedParams);
      setTimeout( () => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url/bulk_remove", request.url);
        assert.equal('csrf-token', request.requestHeaders['X-CSRF-TOKEN']);
        assert.equal("POST", request.method);
        assert.deepEqual( {members_login:expectedParams}, JSON.parse(request.requestBody));
        request.respond(200, {}, 'Message');
      });
      return responsePromise.then((result) => {
        assert.ok(result.success);
        assert.equal('Message',result.message);
      });
    });

    it('should propagate the error message from bulk_remove api for 422 response code', () => {
      let expectedParams = ['user1', 'user2','user3'];
      let responsePromise = this.programTeamService.bulkRemove(expectedParams);
      setTimeout( () => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url/bulk_remove", request.url);
        assert.equal('csrf-token', request.requestHeaders['X-CSRF-TOKEN']);
        assert.equal("POST", request.method);
        assert.deepEqual( {members_login:expectedParams}, JSON.parse(request.requestBody));
        request.respond(422, {}, 'Error Message');
      });
      return responsePromise.then((result) => {
        assert.ok(!result.success);
        assert.equal('Error Message',result.error);
      });
    });
  });

  describe('addMember', () => {
    it('should use correct url', () => {
      let expectedLogin = 'user_login';
      let expectedRole = 'Program member';
      let responsePromise = this.programTeamService.addMember(expectedLogin,expectedRole);
      setTimeout(() => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url", request.url);
        assert.equal("POST", request.method);
        request.respond(200, {}, 'User');
      });
      return responsePromise.then((result) => {
        assert.ok(result.success);
        assert.equal('User', result.user);
      });
    });

    it('should propagate the error message from create api for 422 response code', () => {
      let expectedLogin = 'user_login';
      let expectedRole = 'Program member';
      let responsePromise = this.programTeamService.addMember(expectedLogin, expectedRole);
      setTimeout( () => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url", request.url);
        assert.equal("POST", request.method);
        request.respond(422, {}, 'Error Message');
      });
      return responsePromise.then((result) => {
        assert.ok(!result.success);
        assert.equal('Error Message',result.error);
      });
    });
  });

  describe('Bulk Update', () => {
    it('should use correct url and params', () => {
      let expectedParams = {members_login:['user_1', 'user_2'], role: 'Program Member'};
      let responsePromise = this.programTeamService.bulkUpdate(expectedParams.members_login, expectedParams.role);
      setTimeout( () => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url/bulk_update", request.url);
        assert.equal('csrf-token', request.requestHeaders['X-CSRF-TOKEN']);
        assert.equal("POST", request.method);
        assert.deepEqual( expectedParams, JSON.parse(request.requestBody));
        request.respond(200, {}, JSON.stringify({message:'Message'}));
      });
      return responsePromise.then((result) => {
        assert.ok(result.success);
        assert.equal('Message',result.message);
      });
    });

    it('should propagate the error message from bulk_update api for 422 response code', () => {
      let expectedParams = {members_login:['user_1', 'user_2'], role: 'Program Member'};
      let responsePromise = this.programTeamService.bulkUpdate(expectedParams.members_login, expectedParams.role);
      setTimeout( () => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url/bulk_update", request.url);
        assert.equal('csrf-token', request.requestHeaders['X-CSRF-TOKEN']);
        assert.equal("POST", request.method);
        assert.deepEqual( expectedParams, JSON.parse(request.requestBody));
        request.respond(422, {}, JSON.stringify({message:'Error Message'}));
      });
      return responsePromise.then((result) => {
        assert.ok(!result.success);
        assert.deepEqual({message:'Error Message'},result.error);
      });
    });
  });


});