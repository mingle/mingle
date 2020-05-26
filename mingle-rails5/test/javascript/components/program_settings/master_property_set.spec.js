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
import MasterPropertySet from '../../../../app/javascript/components/program_settings/MasterPropertySet'
import assert from "assert";
import sinon from "sinon";
import {shallow, createLocalVue} from '@vue/test-utils'
const localVue = createLocalVue();
let sandbox = sinon.createSandbox();


describe('MasterPropertySet.vue', () => {
  let masterPropertySet, storeDispatchStub, modalStub;
  beforeEach(function () {
    this.storeDispatchStub = sandbox.stub();
    modalStub = sandbox.stub();
    masterPropertySet = shallow(MasterPropertySet, {
      localVue,
      mocks: {
        $store: {
          state: {programProperties: { properties: [{name: 'Size', description:'It is a Size Property'},
                {name: 'Value', description:'It is a Value Property'}]}},
          dispatch: storeDispatchStub
        },
        $modal: {
          show: modalStub
        }
      }
    });
  });

  describe('Renders', () => {
    it('should render all properties from store',  () => {
      assert.equal(masterPropertySet.findAll('.properties .property-name').at(0).text(),'Size');
      assert.equal(masterPropertySet.findAll('.properties .property-name').at(0).element.title,'It is a Size Property');
      assert.equal(masterPropertySet.findAll('.properties .property-name').at(1).text(),'Value');
      assert.equal(masterPropertySet.findAll('.properties .property-name').at(1).element.title,'It is a Value Property');
    });

    it('should render icons for each property', () => {
      assert.ok(masterPropertySet.find('.properties .fa.fa-pencil').exists());
      assert.ok(masterPropertySet.find('.properties .fa.fa-trash').exists());
    });

    it('should render create property option', () => {
      assert.equal(masterPropertySet.find('p.create-property').text(), 'Create new property')
    });
  });

  describe('Methods', () => {
    describe('openCreatePopUp', () => {
      it('should show the property modal in create mode', () => {
        assert.equal(modalStub.callCount, 0);

        masterPropertySet.vm.openCreatePopUp();

        assert.equal(modalStub.callCount, 1);
        assert.equal(modalStub.args[0][0].name, 'CreatePropertyPopUp');
        assert.deepEqual(modalStub.args[0][1], {heading: 'Create New Property', mode: 'CREATE'});
        assert.deepEqual(modalStub.args[0][2], {height :400, width:550, classes: ['create-property-modal'], clickToClose: false});
      });
    });

    describe('openEditPopUp', () => {
      it('should show the property modal in edit mode and pass the current property data', () => {
        let property = {name: 'Status', description: 'description', type: 'AnyText'};
        assert.equal(modalStub.callCount, 0);

        masterPropertySet.vm.openEditPopUp(property);

        assert.equal(modalStub.callCount, 1);
        assert.equal(modalStub.args[0][0].name, 'CreatePropertyPopUp');
        assert.deepEqual(modalStub.args[0][1], {heading: 'Edit Property', mode: 'EDIT', currentPropertyData: property});
        assert.deepEqual(modalStub.args[0][2], {height :270, width:550, classes: ['edit-property-modal'], clickToClose: false});
      });
    });
  });

  describe('Interactions', () => {
    describe('On Click', () => {
     it('create new property should invoke openCreatePopUp', () => {
       let openPopUpSpy = sandbox.spy();
       masterPropertySet.setMethods({ openCreatePopUp: openPopUpSpy});
       assert.equal(openPopUpSpy.callCount, 0);

       masterPropertySet.find('p.create-property').trigger('click');

       assert.equal(openPopUpSpy.callCount, 1);
     });

      it('edit icon should invoke openEditPopUp with property data', () => {
        let openPopUpSpy = sandbox.spy();
        masterPropertySet.setMethods({ openEditPopUp: openPopUpSpy});
        masterPropertySet.setData({properties: [{name: 'Status', description: 'description', type: 'AnyText'}]});
        assert.equal(openPopUpSpy.callCount, 0);

        masterPropertySet.findAll('.fa.fa-pencil').at(0).trigger('click');

        assert.equal(openPopUpSpy.callCount, 1);
        assert.deepEqual(openPopUpSpy.args[0][0], {name: 'Status', description: 'description', type: 'AnyText'});
      });
    });
  });
});
