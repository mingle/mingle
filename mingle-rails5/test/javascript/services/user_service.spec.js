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
import UserService from "../../../app/javascript/services/user_service";
import Api from "../../../app/javascript/services/api";


let sandbox = sinon.createSandbox();

describe('UserService', function () {
  beforeEach(() => {
    this.server = sandbox.useFakeServer();
    this.userService = new UserService('/base_url', 'csrf-token', 'program_id')
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should extends Api', () => {
    assert.ok(this.userService instanceof Api);
  });


  describe('fetchUsers', () => {
    it('should use correct url ', () => {
      let responsePromise = this.userService.fetchUsers();
      setTimeout(() => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url?exclude_light_users=true", request.url);
        assert.equal("GET", request.method);
        request.respond(200, {}, 'Users');
      });
      return responsePromise.then((result) => {
        assert.ok(result.success);
        assert.equal('Users', result.users);
      });
    });
  });

  describe('fetchProjects', () => {
    it('should use correct url ', () => {
      let responsePromise = this.userService.fetchProjects('userLogin');
      setTimeout(() => {
        let request = this.server.requests[0];
        assert.equal(1, this.server.requests.length);
        assert.equal("/base_url/userLogin/projects?program_id=program_id", request.url);
        assert.equal("GET", request.method);
        request.respond(200, {}, 'Projects');
      });
      return responsePromise.then((result) => {
        assert.ok(result.success);
        assert.equal('Projects', result.data);
      });
    });
  });
});