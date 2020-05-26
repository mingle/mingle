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
import Vuex from 'vuex';
import {createLocalVue} from '@vue/test-utils'
import createProgramProperties from "../../../../../app/javascript/stores/modules/program_settings/program_properties";

let localVue = createLocalVue();
let sandbox = sinon.createSandbox();
let createStub = sandbox.stub();
let programPropertyService = { create: createStub};

let services = {'programProperties': programPropertyService};
localVue.use(Vuex);

describe('ObjectiveType Store Module', function () {

  beforeEach(() => {
    this.data = {
      properties:[{name:'Size'}, {name: 'Value'}]
    };
    this.store = new Vuex.Store({
      modules: {
        programProperties: createProgramProperties(services,this.data)
      }
    });
  });

  afterEach(() => {
    sandbox.reset();
  });

  describe('Initialization', () => {
    it('should have properties state', () => {

      assert.deepEqual(this.data.properties, this.store.state.programProperties.properties);
    });
  });

  describe('Mutations', () => {
    it('updateProperties should update the properties in store', () => {
      assert.deepEqual(this.data.properties, this.store.state.programProperties.properties);
      this.store.commit('updateProperties', {name:'status'});
      assert.deepEqual(this.data.properties, [{name:'Size'}, {name: 'Value'}, {name: 'status'}]);
    });
  });

  describe('Actions', () => {
    describe('createProperty', () => {
      it('should invoke create on service and commit updateProperties on success', () => {
        let property = {name: "something", description: "It is a property", type: "AnyText"};
        let promise = Promise.resolve({success: true, property: property});
        createStub.returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');

        assert.equal(commitStub.callCount, 0);

        return this.store.dispatch('createProperty', property).then((result) => {
          assert.equal(commitStub.callCount, 1);
          assert.equal(commitStub.args[0].length, 2);
          assert.equal(commitStub.args[0][0], 'updateProperties');
          assert.deepEqual(commitStub.args[0][1], property);

          assert.equal(createStub.callCount, 1);
          assert.equal(createStub.args[0].length, 1);
          assert.deepEqual(createStub.args[0][0], property);

          assert.deepEqual({success: true, property: property}, result);
        });
      });

      it('should not commit updateProperties when the result is failure', () => {
        let property = {name: "something", description: "It is a property", type: "AnyText"};
        let promise = Promise.resolve({success: false, error: 'Something went wrong'});
        createStub.returns(promise);
        let commitStub = sandbox.stub(this.store, 'commit');

        assert.equal(commitStub.callCount, 0);

        return this.store.dispatch('createProperty', property).then((result) => {
          assert.equal(commitStub.callCount, 0);

          assert.equal(createStub.callCount, 1);
          assert.equal(createStub.args[0].length, 1);
          assert.deepEqual(createStub.args[0][0], property);

          assert.deepEqual({success: false, message: {type: 'error', text: 'Something went wrong'}}, result);
        });
      });
    });
  });
});