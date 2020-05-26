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
import ObjectivesHandler from "../../../../app/javascript/services/error_handler/objective_error_handler.js";
let sandbox = sinon.createSandbox();

describe('ObjectivesHandler', function () {
    before(() => {
        this.objectivesHandler = new ObjectivesHandler();
    });

    afterEach(() => {
        sandbox.restore();
    });

    it('should invoke callback with correct message for response code 404', () => {
        let callbackSpy = sandbox.spy();
        this.objectivesHandler.handle({status:404}, callbackSpy)

        assert.equal(callbackSpy.callCount,1);
        assert.deepEqual(callbackSpy.args[0][0], {success:false, error:'Objective not found.', errorType:'deleted'});
    });

    it('should invoke callback with correct message for response code 422', () => {
        let callbackSpy = sandbox.spy();
        this.objectivesHandler.handle({status:422, data: 'errorMessage'}, callbackSpy)

        assert.equal(callbackSpy.callCount,1);
        assert.deepEqual(callbackSpy.args[0][0], {success:false, error:'errorMessage'});
    });

    it('should invoke callback with action specific message for unhandled response codes', () => {
        let callbackSpy = sandbox.spy();
        this.objectivesHandler.handle({status:403}, callbackSpy, 'update')
        this.objectivesHandler.handle({status:403}, callbackSpy, 'plan')
        
        assert.equal(callbackSpy.callCount,2);
        assert.deepEqual(callbackSpy.args[0][0], {success:false, error:'Something went wrong while updating objective.'});
        assert.deepEqual(callbackSpy.args[1][0], {success:false, error:'Something went wrong while planning objective.'});
        
    });
});
