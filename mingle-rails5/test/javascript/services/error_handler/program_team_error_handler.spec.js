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
import ProgramTeamErrorHandler from "../../../../app/javascript/services/error_handler/program_team_error_handler";

let sandbox = sinon.createSandbox();

describe('ProgramTeamErrorHandler', function () {
  before(() => {
    this.programTeamErrorHandler = new ProgramTeamErrorHandler();
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should invoke callback with correct message for response code 422', () => {
    let callbackSpy = sandbox.spy();
    this.programTeamErrorHandler.handle({status: 422, data: 'errorMessage'}, callbackSpy);

    assert.equal(1, callbackSpy.callCount);
    assert.deepEqual({success: false, error: 'errorMessage'}, callbackSpy.args[0][0]);
  });

  it('should invoke callback with action specific message for unhandled response codes', () => {
    let callbackSpy = sandbox.spy();
    this.programTeamErrorHandler.handle({status: 500}, callbackSpy, 'bulkRemove');
    this.programTeamErrorHandler.handle({status: 500}, callbackSpy, 'addMember');
    this.programTeamErrorHandler.handle({status: 500}, callbackSpy, 'bulkUpdate');

    assert.equal(3, callbackSpy.callCount);
    assert.deepEqual({success: false, error: 'Something went wrong while removing members.'}, callbackSpy.args[0][0]);
    assert.deepEqual({success: false, error: 'Something went wrong while adding members.'}, callbackSpy.args[1][0]);
    assert.deepEqual({success: false, error: 'Something went wrong while updating members.'}, callbackSpy.args[2][0]);

  });

});
