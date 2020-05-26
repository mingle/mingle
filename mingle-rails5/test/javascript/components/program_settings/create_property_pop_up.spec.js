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
import {shallow, createLocalVue} from '@vue/test-utils'
import sinon from 'sinon'
import {EventBus} from '../../../../app/javascript/shared/event_bus'


let localVue = createLocalVue();
let sandbox = sinon.createSandbox();

import CreatePropertyPopUp from "../../../../app/javascript/components/program_settings/CreatePropertyPopUp";


describe('CreatePropertyPopUp.vue', () => {
  let createPropertyComponent;
    let storeDispatchStub, emitStub;
    beforeEach(function () {
      storeDispatchStub = sandbox.stub();
      emitStub = sandbox.stub();
      createPropertyComponent = shallow(CreatePropertyPopUp, {
        localVue,
        mocks: {
          $store: {
            dispatch: storeDispatchStub
          },
          $emit: emitStub
        },
        propsData: {
          heading: "New Heading",
          mode: 'CREATE'
        },
        data: {
          property: {name: "", description: "",type:""}
        }
      });
    });
    afterEach(() => {
      sandbox.reset();
    });
    describe('Renders', () => {
      it('Should render the header with heading and close icon', () => {
        assert.equal(createPropertyComponent.find('.header .heading').text(), 'New Heading');
        assert.ok(createPropertyComponent.find('.header .close.fa.fa-times').exists());
      });

      it('should render the input fields for property name and description', () => {
        assert.ok(createPropertyComponent.find('#name input').exists());
        assert.equal(createPropertyComponent.find('#name .label').text(), 'Name');
        assert.ok(createPropertyComponent.find('#desc textarea').exists());
        assert.equal(createPropertyComponent.find('#desc .label').text(), 'Description');
      });

      it('should render the types of properties',  () => {
        assert.equal(createPropertyComponent.find('#type .label').text(), 'Type');
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").length, 6);
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").at(0).element.value, 'AnyText');
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").at(1).element.value, 'ManagedText');
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").at(2).element.value, 'AnyNumber');
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").at(3).element.value, 'ManagedNumber');
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").at(4).element.value, 'DateType');
        assert.equal(createPropertyComponent.findAll("#type input[type='radio']").at(5).element.value, 'TeamMember');
      });

      it('should render create and cancel buttons',  () => {
        assert.equal(createPropertyComponent.find('.create.primary[disabled]').text(), 'Create');
        assert.equal(createPropertyComponent.find('.cancel').text(), 'Cancel');
      });

      describe('EDIT mode', () => {
        beforeEach( function () {
          createPropertyComponent.setProps({mode: 'EDIT'});
          createPropertyComponent.setData({property: {name: 'Status', description: 'description', type: 'AnyText'}})
        });

        it('should render the property type info when in EDIT mode', () => {
          assert.ok(!createPropertyComponent.find('#type').exists());
          assert.ok(createPropertyComponent.find('#type-info .label').exists());
          assert.equal(createPropertyComponent.find('#type-info .label').text(), 'Type');
          assert.ok(createPropertyComponent.find('#type-info #type-name').exists());
          assert.equal(createPropertyComponent.find('#type-info #type-name').text(), 'AnyText');
        });

        it('should render save button when in EDIT mode',  () => {
          assert.ok(!createPropertyComponent.find('.create.primary').exists());
          assert.equal(createPropertyComponent.find('.save').text(), 'Save');
        });
      });
    });
  describe('Interactions', () => {
    it('should invoke the closePopUp method on clicking the close icon', () => {
      let closePopUpSpy = sandbox.spy();
      createPropertyComponent.setMethods({closePopUp: closePopUpSpy});
      assert.equal(closePopUpSpy.callCount, 0);
      createPropertyComponent.find('.header .close.fa.fa-times').trigger('click');
      assert.equal(closePopUpSpy.callCount, 1);
    });

    it('should invoke the closePopUp method on clicking the cancel button', () => {
      let closePopUpSpy = sandbox.spy();
      createPropertyComponent.setMethods({closePopUp: closePopUpSpy});
      assert.equal(closePopUpSpy.callCount, 0);
      createPropertyComponent.find('.actions .action-bar .cancel').trigger('click');
      assert.equal(closePopUpSpy.callCount, 1);
    });

    it('should invoke createProperty method on clicking create button', () => {
      let createPropertySpy = sandbox.spy();
      createPropertyComponent.setMethods({createProperty: createPropertySpy});

      createPropertyComponent.setData({property: {name: "Name", description: "", type: "AnyText"}});
      createPropertyComponent.find('.create.primary').trigger('click');

      assert.equal(createPropertySpy.callCount, 1);
    });
  });

  describe('Methods',  ()=> {

    describe('closePopUp', () => {
      it('should emit close and reset property Info', () => {
        createPropertyComponent.setData({property: {name: "something", description: "It is a property", type: "AnyText"}, errorMessage: 'error message'});
        createPropertyComponent.vm.closePopUp();

        assert.deepEqual(createPropertyComponent.vm.property, {name: "", description: "",type:""});
        assert.equal(createPropertyComponent.vm.errorMessage, null);
        assert.equal(emitStub.callCount, 1);
        assert.equal(emitStub.args[0][0], 'close');
      });
    });

    describe('createProperty', () => {
      let clickEvent;
      let successMessage = '';
      EventBus.$on('updateMessage',(message)=> {
        successMessage = message;
      });

      beforeEach(function () {
        clickEvent = {
          target: {
            className:'target class name',
            getWidth() {
              return 1;
            },
            positionedOffset(){
              return {left:2};
            },
            hasClassName() {
              return 'save'
            }
          }
        };
      });

      after(() => {
        EventBus.$off('updateMessage');
      });

      it('should dispatch createProperty to the store and update the message when the result is success and close the popUp', (done) => {
        let property = {name: 'Status', description: 'desc', type: 'AnyText'};
        let closePopUpSpy = sandbox.spy();
        createPropertyComponent.setMethods({closePopUp: closePopUpSpy});
        createPropertyComponent.setData({property: property});
        storeDispatchStub.returns(Promise.resolve({success: true, property: property}));

        createPropertyComponent.vm.createProperty(clickEvent);

        setTimeout(() => {
          assert.equal(createPropertyComponent.vm.messageBoxPositionFromLeft, 2);
          assert.equal(storeDispatchStub.callCount, 1);
          assert.equal(storeDispatchStub.args[0][0], 'createProperty');
          assert.deepEqual(storeDispatchStub.args[0][1], property);
          assert.equal(closePopUpSpy.callCount, 1);
          assert.deepEqual(successMessage, {type: 'success', text: `Status property has been created successfully.`});
          done();
        });
      });

      it('should update the failure message with the error when the result is error', (done) => {
        storeDispatchStub.returns(Promise.resolve({success: false, message: {type:'error', text:'Something went wrong'}}));

        createPropertyComponent.vm.createProperty(clickEvent);

        setTimeout(() => {
          assert.deepEqual(createPropertyComponent.vm.errorMessage, {type:'error', text:'Something went wrong'});
          done();
        });
      });

      it('should show the error message and not dispatch createProperty to the store when the name is invalid', (done) => {
        createPropertyComponent.setData({property: {name: "abc&"}});

        createPropertyComponent.vm.createProperty(clickEvent);

        setTimeout(() => {
          assert.equal(createPropertyComponent.vm.messageBoxPositionFromLeft, 2);
          assert.equal(storeDispatchStub.callCount, 0);
          assert.deepEqual(createPropertyComponent.vm.errorMessage, {type: 'error', text: "Name can't contain '&', '=', '#', '\"', '\;', '[' or ']' characters."});
          done();
        });
      });
    });

    describe('GetMessageBoxConfig', () => {
      it('should give default tooltip message config', () => {
        let expected = {position:{left: 0, bottom: 60}};
        let actual = createPropertyComponent.vm.getTooltipMessageConfig;

        assert.deepEqual(actual, expected);
      });
      it('should give updated tooltip message config', () => {
        createPropertyComponent.setData({messageBoxPositionFromLeft: 23});
        let expected = {position:{left: 23, bottom: 60}};
        let actual = createPropertyComponent.vm.getTooltipMessageConfig;

        assert.deepEqual(actual, expected);
      });
    });
    describe('isValidName', () => {
      it('should return true if the name does not contain special characters', () => {
        assert.ok(createPropertyComponent.vm.isValidName('dav123'));
      });
      it('should return false if the name contains any one of given characters', () => {
        // prohibited special characters are #, &, [, ], ;, =, "
        let characters = ['#','&','=','[',']','"',';'];

        characters.forEach((character) => {
          assert.ok(!createPropertyComponent.vm.isValidName('dav'+ character));
        });
      });
    });

  });

  describe('Computed', () => {
    it('disabled should false when both name and type are present', () => {
      assert.ok(createPropertyComponent.vm.disabled);
      createPropertyComponent.setData({property: {name: "Name", description: "",type:""}});
      assert.ok(createPropertyComponent.vm.disabled);
      createPropertyComponent.setData({property: {name: "", description: "",type:"AnyText"}});
      assert.ok(createPropertyComponent.vm.disabled);
      createPropertyComponent.setData({property: {name: "Name", description: "",type:"AnyText"}});
      assert.ok(!createPropertyComponent.vm.disabled);
    });

    it('isCreateMode should be false when the mode is not CREATE', () => {
      assert.ok(createPropertyComponent.vm.isCreateMode);
      createPropertyComponent.setData({mode: 'EDIT'});
      assert.ok(!createPropertyComponent.vm.isCreateMode);
    })
  });
});
