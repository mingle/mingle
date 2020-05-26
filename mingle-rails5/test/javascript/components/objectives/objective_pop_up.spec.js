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
import ObjectivePopUp from '../../../../app/javascript/components/objectives/ObjectivePopUp.vue'
import sinon from "sinon";
import assert from "assert";
import modal from 'vue-js-modal'
import {shallow,createLocalVue } from '@vue/test-utils'

const localVue = createLocalVue();
localVue.use(modal);
let sandbox = sinon.createSandbox();

describe('ObjectivePopUp.vue', () => {
  let objectiveComponent, modalHideSpy, dispatchStub ;
  beforeEach(function () {
    modalHideSpy = sandbox.spy();
    dispatchStub = sandbox.stub();

    objectiveComponent = shallow(ObjectivePopUp,{
      propsData: {objective: {name: 'Foo', number: 1234, value_statement:'Objective value statement', size:1,value:2}, name: 'objective_popup'},
      localVue: localVue,
      mocks: {
        $store: {
          state: {currentObjectiveData: {size:1,value:2},
                  toggles: {readOnlyModeEnabled: false }},
          dispatch:dispatchStub
        },
        $modal:{
          hide:modalHideSpy
        }
      },
      stubs: {
        'objective-default': '<div class="objective-default-container"/>',
        'objective-edit': '<div class="edit-popup-container"/>',
        'objective-view': '<div class="view-popup-container"/>'
      }
    });
  });

  afterEach(function () {
    sandbox.restore();
  });

  describe('Data', () => {
    it('should initialise popUp in the given mode ', () => {
      objectiveComponent = shallow(ObjectivePopUp,{
        propsData: {objective: {name: 'Foo', number: 1234, value_statement:'Objective value statement', size:1,value:2}, name: 'objective_popup', mode: 'ADD'},
        localVue: localVue
      });
      assert.equal('ADD', objectiveComponent.vm.popupMode);
    });
  });
  describe('When readOnlyMode is toggled off renders', function () {

    it('default data', () => {
      assert.ok(!objectiveComponent.vm.editMode);
    });

    it('objective type name', () => {
      assert.equal('Objective', objectiveComponent.find('.objective-type-container .objective-type-name').text());
    });

    it('close button', () => {
      assert.ok(objectiveComponent.find('.wrapper .close').exists());
    });

    it('should not renders close button when popupMode state is EDIT', (done) => {
      assert.ok(objectiveComponent.find('.wrapper .close').exists());
      objectiveComponent.setData({popupMode: 'EDIT'});
      setTimeout(()=>{
        assert.ok(!objectiveComponent.find('.wrapper .close').exists());
        done();
      });
    });

    it('should not renders close button when popupMode state is ADD', (done) => {
      assert.ok(objectiveComponent.find('.wrapper .close').exists());

      objectiveComponent.setData({popupMode: 'ADD'});
      setTimeout(()=>{
        assert.ok(!objectiveComponent.find('.wrapper .close').exists());
        done();
      });
    });

    it('backlog objective view component by default', () => {
      assert.ok(objectiveComponent.find('.view-popup-container').exists());
    });

    it('backlog objective edit component when popupMode state is EDIT', (done) => {
      assert.ok(!objectiveComponent.find('.edit-popup-container').exists());

      objectiveComponent.setData({popupMode: 'EDIT'});
      setTimeout(() => {
        assert.ok(objectiveComponent.find('.edit-popup-container').exists());
        done();
      })
    });
  });

  describe('When readOnlyMode is toggled on renders', function () {
    it('backlog objective view component', (done) => {
      objectiveComponent = shallow(ObjectivePopUp, {
        propsData: {
          objective: {
            name: 'Foo',
            number: 1234,
            value_statement: 'Objective value statement',
            size: 1,
            value: 2
          }, name: 'objective_popup'
        },
        localVue: localVue,
        mocks: {
          $store: {
            state: {
              currentObjectiveData: {size: 1, value: 2},
              toggles: {readOnlyModeEnabled: true}
            },
            dispatch: dispatchStub
          },
          $modal: {
            hide: modalHideSpy
          }
        },
        stubs: {
          'objective-default': '<div class="objective-default-container"/>',
          'objective-edit': '<div class="edit-popup-container"/>',
          'objective-view': '<div class="view-popup-container"/>'
        }
      });

      assert.ok(!objectiveComponent.find('.edit-popup-container').exists());

      objectiveComponent.setData({popupMode: 'EDIT'});
      setTimeout(() => {
        assert.ok(!objectiveComponent.find('.edit-popup-container').exists());
        assert.ok(objectiveComponent.find('.view-popup-container').exists());
        done();
      });
    });


  });

  describe('Interactions', function () {
    describe('Click', () => {
      it('on close icon should invoke closePopup method', () => {
        let closePopupStub = sandbox.stub();
        objectiveComponent.setMethods({closePopup: closePopupStub});

        let closeButton = objectiveComponent.find('.wrapper .close');
        closeButton.trigger('click');

        assert.equal(closePopupStub.callCount, 1);
      });
    });
  });

  describe('Methods', () => {
    describe('ClosePopup', () => {
      it('should hide the modal and invoke updatePopupMode', () => {
        let updatePopupModeStub = sandbox.stub();
        objectiveComponent.setMethods({updatePopupMode: updatePopupModeStub});

        assert.equal(modalHideSpy.callCount, 0);
        assert.equal(updatePopupModeStub.callCount, 0);

        objectiveComponent.vm.closePopup();

        assert.equal(modalHideSpy.callCount, 1);
        assert.equal(updatePopupModeStub.callCount, 1);

      });
    });
    describe('UpdatePopupMode', () => {
      it('should set popupMode to given mode', () => {

        assert.equal(objectiveComponent.vm.popupMode, 'VIEW');
        objectiveComponent.vm.updatePopupMode('EDIT');

        assert.equal(objectiveComponent.vm.popupMode, 'EDIT');
      });
    });
  });
});
