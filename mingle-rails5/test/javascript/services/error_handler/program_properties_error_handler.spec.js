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
import ProgramPropertiesErrorHandler from "../../../../app/javascript/services/error_handler/program_properties_error_handler";

let sandbox = sinon.createSandbox();

describe('ProgramPropertiesErrorHandler', function () {
  before(() => {
    this.programPropertiesErrorHandler = new ProgramPropertiesErrorHandler();
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should invoke callback with correct message for response code 422', () => {
    let callbackSpy = sandbox.spy();
    this.programPropertiesErrorHandler.handle({status: 422, data: 'errorMessage'}, callbackSpy);

    assert.equal(1, callbackSpy.callCount);
    assert.deepEqual({success: false, error: 'errorMessage'}, callbackSpy.args[0][0]);
  });

  it('should invoke callback with action specific message for unhandled response codes', () => {
    let callbackSpy = sandbox.spy();
    this.programPropertiesErrorHandler.handle({status: 500}, callbackSpy, 'create');

    assert.equal(callbackSpy.callCount, 1);
    assert.deepEqual({success: false, error: 'Something went wrong while creating the property.'}, callbackSpy.args[0][0]);
  });

});
