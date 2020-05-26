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
import ObjectiveEdit from '../../../../app/javascript/components/objectives/ObjectiveEdit.vue'
import sinon from "sinon";
import assert from "assert";
import {shallow, createLocalVue} from '@vue/test-utils'

let sandbox = sinon.createSandbox();
let localVue = createLocalVue();

describe('ObjectiveEditWithoutCkeditor.vue', function () {
  let contentCss = ['https://content_1.css/', 'https://content_2.css/'];
  beforeEach(() => {
    this.storeDispatchStub = sandbox.stub();
    this.getDataStub = sandbox.stub();
    this.ckEditorReplaceSpy = sandbox.spy(CKEDITOR, 'replace');
    this.objectiveData = {
      name: 'Foo',
      number: 1234,
      value_statement: 'Objective value statement',
      property_definitions: {Size: {name: 'Size', value: 1, allowed_values:[1,2,3]}, Value: {name: 'Value', value: 2, allowed_values:[1,2,3]}}
    };
    let cssStyles = contentCss.map((cssUrl) => {
      let anchor = document.createElement('a');
      anchor.href = cssUrl;
      return anchor;
    });
    sandbox.stub(document, 'querySelectorAll').withArgs('link[rel="stylesheet"]').returns(cssStyles);

    this.ckEditorInstances = {};
    CKEDITOR.instances = this.ckEditorInstances;
    this.ckEditorEventBinderSpy = sandbox.spy();
    this.ckEditorInstances.objective_value_statement_editor = { on: this.ckEditorEventBinderSpy , getData: this.getDataStub};
    this.objectiveEditComponent = shallow(ObjectiveEdit,{
      localVue:localVue,
      propsData:{ objective: this.objectiveData, objectiveProperties: {
        value: this.objectiveData.value, size: this.objectiveData.size}
      },
      mocks:{
        $store:{
          state: { foo: "bar", defaultObjectiveType: {value_statement: 'default value statement'}},
          dispatch: this.storeDispatchStub
        }
      }
    });
  });

  afterEach(() => {
    sandbox.restore();
    this.storeDispatchStub.reset();
    this.getDataStub.reset();
  });

  describe('Renders', () => {
    it('save button when the popup mode is EDIT', () => {
      assert.ok(this.objectiveEditComponent.find('.save'));
    });

    it('save and close button when the popup mode is EDIT', () => {
      assert.ok(this.objectiveEditComponent.find('.save-and-close'));
    });

    it('cancel button without close icon when popupMode is EDIT', (done) => {
      this.objectiveEditComponent.vm.$store.state.popupMode = "EDIT"

      setTimeout(()=> {
        assert.ok(this.objectiveEditComponent.find('.cancel').exists());
        assert.ok(!this.objectiveEditComponent.find('.cancel .fa.fa-times').exists());
        done();
      });
    });

    it('cancel button with close icon when popupMode is ADD', (done) => {
      this.objectiveEditComponent.setProps({popupMode:'ADD'});

      setTimeout(()=> {
        assert.ok(this.objectiveEditComponent.find('.cancel .fa.fa-times').exists());
        done();
      });
    });

    it('add button when the popup mode is ADD', (done) => {
      assert.ok(!this.objectiveEditComponent.find('.add').exists());

      this.objectiveEditComponent.setProps({popupMode:'ADD'});

      setTimeout(()=> {
        assert.ok(this.objectiveEditComponent.find('.add').exists());
        done();
      });
    });

    it('should not render SAVE and SAVE-AND-CLOSE button when the popup mode is ADD', (done) => {
      this.objectiveEditComponent.setProps({popupMode:'ADD'});

      setTimeout(()=> {
        assert.ok(!this.objectiveEditComponent.find('.save').exists());
        assert.ok(!this.objectiveEditComponent.find('.save-and-close').exists());
        done();
      });
    });

    it('objective name should not allow more than 80 char', () => {
      assert.equal(this.objectiveEditComponent.find('.header .name').attributes().maxlength, '80');
    });
  });

  describe('Interactions', () => {
    describe('Click', () => {
      it('on save button should invoke saveObjective', () => {
        let saveObjectiveStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ saveObjective: saveObjectiveStub });
        this.objectiveEditComponent.find('.save').trigger('click');

        assert.equal(saveObjectiveStub.callCount, 1);
      });

      it('on save and close button should invoke saveObjective', () => {
        let saveObjectiveStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ saveObjective: saveObjectiveStub });
        this.objectiveEditComponent.find('.save-and-close').trigger('click');

        assert.equal(saveObjectiveStub.callCount, 1);
      });

      it('on cancel button should invoke destroyCkEditorWithEvent with cancel event for EDIT mode', () => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ destroyCkEditorWithEvent: destroyCkEditorWithEventStub });
        assert.equal(destroyCkEditorWithEventStub.callCount, 0);

        this.objectiveEditComponent.find('.cancel').trigger('click');

        assert.equal(destroyCkEditorWithEventStub.callCount, 1);
        assert.equal(destroyCkEditorWithEventStub.args[0][0], 'cancel');
      });

      it('on cancel button should invoke destroyCkEditorWithEvent with close event for ADD mode', () => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent = shallow(ObjectiveEdit,{
          localVue:localVue,
          propsData:{ objective: this.objectiveData },
          computed:{isEditMode:()=> false},
          methods:{destroyCkEditorWithEvent:destroyCkEditorWithEventStub},
          mocks:{
            $store:{
              state: { foo: "bar" , popupMode: "EDIT"},
              dispatch: this.storeDispatchStub
            }
          }
        });
        assert.equal(destroyCkEditorWithEventStub.callCount, 0);

        this.objectiveEditComponent.find('.cancel').trigger('click');

        assert.equal(destroyCkEditorWithEventStub.callCount, 1);
        assert.equal(destroyCkEditorWithEventStub.args[0][0], 'close');
      });

      it('on add button should invoke createObjective', () => {
        let createObjectiveStub = sandbox.stub();
        this.objectiveEditComponent.setProps({popupMode:"ADD"});
        this.objectiveEditComponent.setMethods({ createObjective: createObjectiveStub });
        this.objectiveEditComponent.find('.add').trigger('click');

        assert.equal(createObjectiveStub.callCount, 1);
      });
    });
  });

  describe("Methods", () => {
    describe('SaveObjective', () => {
      beforeEach(() => {
        this.payload = {scopedMessage:true, objectiveData:{}, eventName: 'Save and Close'};
        this.payload.objectiveData =  {
          name: "New name", value_statement: "Changed objective value statement",
          property_definitions:{Size:{name:'Size', value:33},Value:{name:'Value', value:22}}
        };
        this.ckEditorInstances = {};
        this.ckEditorInstanceId = this.objectiveEditComponent.vm.ckEditorInstanceId;
        CKEDITOR.instances = this.ckEditorInstances;
        this.ckEditorInstances.objective_value_statement_editor = { getData: this.getDataStub};
        this.clickEvent = {
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

      it("should dispatch correct action on the store", (done) => {
        this.storeDispatchStub.returns(
          Promise.resolve({ success: true, data: this.payload.objectiveData })
        );

        this.getDataStub.returns(this.payload.objectiveData.value_statement);
        this.objectiveEditComponent.setData({
          name:this.payload.objectiveData.name, content: this.payload.objectiveData.value_statement,
          objectiveProperties: this.payload.objectiveData.property_definitions
        });

        this.objectiveEditComponent.vm.saveObjective(this.clickEvent);

        assert.equal(this.storeDispatchStub.callCount, 1);
        assert.equal(this.getDataStub.callCount, 1);


        assert.equal(this.storeDispatchStub.args[0][0], 'updateCurrentObjective');
        let objectiveData = this.storeDispatchStub.args[0][1].objectiveData;
        assert.equal(objectiveData.name, this.payload.objectiveData.name);
        assert.equal(objectiveData.value_statement, this.payload.objectiveData.value_statement);
        assert.deepEqual(objectiveData.property_definitions, this.payload.objectiveData.property_definitions);


        setTimeout(() => {
          //Do not remove. Async promise resolution fails other test, if this block does not execute
          done();
        });
      });

      it("should invoke destroyCkEditorWithEvent with correct event when update succeeds", (done) => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ destroyCkEditorWithEvent: destroyCkEditorWithEventStub });
        this.storeDispatchStub.returns(
          Promise.resolve({ success: true, data: this.payload.objectiveData })
        );
        this.objectiveEditComponent.setData({content: this.payload.objectiveData.value_statement});

        assert.equal(destroyCkEditorWithEventStub.callCount, 0);

        let event  = {target:{className:'progressbar target class name',hasClassName:sandbox.stub(), getWidth:sandbox.stub(), positionedOffset:sandbox.stub()}};
        event.target.hasClassName.returns(false);
        event.target.positionedOffset.returns({left: '0'});
        this.objectiveEditComponent.vm.saveObjective(event);

        setTimeout(() => {
          assert.equal(destroyCkEditorWithEventStub.callCount, 1);
          assert.equal(destroyCkEditorWithEventStub.args[0][0], 'updated');
          done();
        });
      });

      it("should not invoke destroyCkEditorWithEvent when update fail", (done) => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ destroyCkEditorWithEvent: destroyCkEditorWithEventStub });
        this.storeDispatchStub.returns( Promise.reject('Rejected'));
        this.objectiveEditComponent.content = this.payload.objectiveData.value_statement;

        assert.equal(destroyCkEditorWithEventStub.callCount, 0);
        this.objectiveEditComponent.vm.saveObjective(this.clickEvent);

        setTimeout(() => {
          assert.equal(destroyCkEditorWithEventStub.callCount, 0);
          done();
        });
      });

      it('should emit close event when event target is save and close button', (done) => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ destroyCkEditorWithEvent: destroyCkEditorWithEventStub });
        this.storeDispatchStub.returns(
          Promise.resolve({ success: true, data: this.payload.objectiveData })
        );
        this.objectiveEditComponent.content = this.payload.objectiveData.value_statement;
        assert.equal(destroyCkEditorWithEventStub.callCount, 0);

        let event  = {target:{className:'progressbar target class name', hasClassName:sandbox.stub(), getWidth:sandbox.stub(), positionedOffset:sandbox.stub()}};
        event.target.hasClassName.returns(true);
        event.target.positionedOffset.returns({left: '0'});
        this.objectiveEditComponent.vm.saveObjective(event);

        setTimeout(() => {
          assert.equal(destroyCkEditorWithEventStub.callCount, 1);
          assert.equal(destroyCkEditorWithEventStub.args[0][0], 'close');
          done();
        })
      });

      it('should set progressBarTarget', () => {
        this.storeDispatchStub.returns(
            Promise.resolve({ success: true, data: this.payload.objectiveData })
        );
        this.objectiveEditComponent.content = this.payload.objectiveData.value_statement;

        let event  = {target:{className:'progressbar target class name', hasClassName:sandbox.stub()}};

        assert.equal('.save-objective', this.objectiveEditComponent.vm.progressBarTarget);
        this.objectiveEditComponent.vm.saveObjective(event);

        assert.equal('.progressbar.target.class.name', this.objectiveEditComponent.vm.progressBarTarget);

      });
    });
    describe('DestroyCkEditorWithEvent', () => {
      it("should destroy ckeditor instance with correct event", () => {
        let ckEditorInstanceDestroy = sandbox.spy();
        this.ckEditorInstances[this.ckEditorInstanceId] = { destroy: ckEditorInstanceDestroy };
        this.objectiveEditComponent.vm.destroyCkEditorWithEvent('updated');

        assert.ok(this.objectiveEditComponent.emitted().updated);
        assert.equal(ckEditorInstanceDestroy.callCount, 1);
      });
    });
    describe('GetMessageBoxConfig', () => {
      it('should give default tooltip message config', () => {
        let expected = {position:{left:0}};
        let actual = this.objectiveEditComponent.vm.getTooltipMessageConfig;

        assert.deepEqual(actual, expected);8
      });
      it('should give updated tooltip message config', () => {
        this.objectiveEditComponent.setData({messageBoxPositionFromLeft: 23});
        let expected = {position:{left:23}};
        let actual = this.objectiveEditComponent.vm.getTooltipMessageConfig;

        assert.deepEqual(actual, expected);
      });
    });

    describe('ResizeCkEditor', () => {
      it('should invoke CKEDITOR resize method with proper height and size', () => {
        let ckEditorResizeSpy = sandbox.spy();
        let ckeditorSizeStub = sandbox.stub();
        ckeditorSizeStub.returns({width:300, height:200});

        this.ckEditorInstances[this.objectiveEditComponent.vm.ckEditorInstanceId] = { resize: ckEditorResizeSpy};
        this.objectiveEditComponent.setMethods({ckeditorSize: ckeditorSizeStub});

        this.objectiveEditComponent.vm.resizeCkEditor();

        assert.equal(ckEditorResizeSpy.callCount, 1);
        assert.deepEqual(ckEditorResizeSpy.args[0], [300,200]);
      });
    });

    describe('CkeditorSize', () => {
      it('should return height and width for CKEDITOR', () => {
        this.objectiveEditComponent.vm.$el.getHeight = () => 500;
        this.objectiveEditComponent.vm.$el.getWidth = ()=> 700 ;
        assert.deepEqual(this.objectiveEditComponent.vm.ckeditorSize(), {height:320, width: 670});
      });
    });

    describe('EditorContent', () => {
      it('should return backlog objective value statment when popupMode is EDIT', () => {
        let actualContent = this.objectiveEditComponent.vm.editorContent();
        assert.equal(actualContent, this.objectiveData.value_statement);
      });
    });

    describe('CreateObjective', () => {
      beforeEach(() => {
        this.payload = {
          name: "New name", value_statement: "Changed objective value statement",
          objectiveProperties:{Size: {name: 'Size', value: 1, allowed_values:[1,2,3]}, Value: {name: 'Value', value: 2, allowed_values:[1,2,3]}}
        };
        this.clickEvent = {
          target: {
            className:'target class name',
            getWidth() {
              return 1;
            },
            positionedOffset(){
              return {left:2};
            }
          }
        };
        this.ckEditorInstances = {};
        this.ckEditorInstanceId = this.objectiveEditComponent.vm.ckEditorInstanceId;
        CKEDITOR.instances = this.ckEditorInstances;
        this.ckEditorInstances.objective_value_statement_editor = { getData: this.getDataStub};

      });

      it("should dispatch correct action on the store", (done) => {
        this.getDataStub.returns(this.payload.value_statement);

        this.storeDispatchStub.returns(
          Promise.resolve({ success: true, data: this.payload })
        );
        this.objectiveEditComponent.setData({
          name:this.payload.name, content: this.payload.value_statement,
          objectiveProperties: this.payload.objectiveProperties
        });

        this.objectiveEditComponent.vm.createObjective(this.clickEvent);

        assert.equal(this.storeDispatchStub.callCount, 1);
        assert.equal(this.getDataStub.callCount, 1);

        assert.equal(this.storeDispatchStub.args[0][0], 'createObjective');

        assert.deepEqual(this.storeDispatchStub.args[0][1], {
          name:this.payload.name, value_statement:this.payload.value_statement,
          property_definitions:this.payload.objectiveProperties
        });

        setTimeout(() => {
          //Do not remove. Async promise resolution fails other test, if this block does not execute
          done();
        });
      });

      it("should invoke destroyCkEditorWithEvent with correct event when create succeeds", (done) => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ destroyCkEditorWithEvent: destroyCkEditorWithEventStub });
        this.storeDispatchStub.returns(
          Promise.resolve({ success: true, data: this.payload})
        );
        this.objectiveEditComponent.setData({content: this.payload.value_statement});

        assert.equal(destroyCkEditorWithEventStub.callCount, 0);

        this.clickEvent.target.hasClassName = () => returns(false);
        this.objectiveEditComponent.vm.createObjective(this.clickEvent);

        setTimeout(() => {
          assert.equal(destroyCkEditorWithEventStub.callCount, 1);
          assert.equal(destroyCkEditorWithEventStub.args[0][0], 'cancel');
          done();
        });
      });

      it("should invoke set config for progress bar on success", (done) => {
        this.storeDispatchStub.returns(
            Promise.resolve({ success: true, data: this.payload})
        );
        this.objectiveEditComponent.setData({content: this.payload.value_statement});
        this.objectiveEditComponent.vm.createObjective(this.clickEvent);
        assert.ok(this.objectiveEditComponent.vm.displayProgressBar);

        setTimeout(() => {
          assert.ok(!this.objectiveEditComponent.vm.displayProgressBar);
          done();
        });
      });

      it("should not invoke destroyCkEditorWithEvent and sets the data for error tooltip when create fail", (done) => {
        let destroyCkEditorWithEventStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({ destroyCkEditorWithEvent: destroyCkEditorWithEventStub });
        this.storeDispatchStub.returns( Promise.resolve({success:false,message:{type:'error',text:'Something went wrong'}}));
        this.objectiveEditComponent.setData({name:this.payload.name, content: this.payload.value_statement});

        assert.equal(destroyCkEditorWithEventStub.callCount, 0);
        this.objectiveEditComponent.vm.createObjective(this.clickEvent);

        setTimeout(() => {
          assert.equal(this.objectiveEditComponent.vm.messageBoxPositionFromLeft, 2);
          assert.deepEqual(this.objectiveEditComponent.vm.errorMessage, {type:'error', text:'Something went wrong'});
          assert.equal(destroyCkEditorWithEventStub.callCount, 0);
          done();
        });
      });

      it("should set progressBarTarget", () => {
        this.storeDispatchStub.returns( Promise.resolve({success:false,message:{type:'error',text:'Something went wrong'}}));
        assert.equal('.save-objective', this.objectiveEditComponent.vm.progressBarTarget);
        this.objectiveEditComponent.vm.createObjective(this.clickEvent);
        assert.equal('.target.class.name', this.objectiveEditComponent.vm.progressBarTarget);
      });
    });

    describe('UpdateObjectiveProperties', () => {
      it('should update the backlog ObjectiveProperties data', () => {
        this.objectiveEditComponent.setData({objectiveProperties: {value: 20, size: 30}});

        this.objectiveEditComponent.vm.updateObjectiveProperties({value: 34, size: 45});

        assert.deepEqual(this.objectiveEditComponent.vm.objectiveProperties, {value: 34, size: 45});
      });
    })
  });

  describe('Watchers', () => {
    describe('PopupResized', () => {
      it('should invoke resizeCkEditor', () => {
        let resizeCkeditorStub = sandbox.stub();
        this.objectiveEditComponent.setMethods({resizeCkEditor: resizeCkeditorStub});
        this.objectiveEditComponent.setProps({popupResized: true});

        return localVue.nextTick().then(() => {
          assert.equal(resizeCkeditorStub.callCount, 1);
        })
      });
    });
  });
  describe('LifeCycleHook', () => {
    describe('Mount', () => {
      it('should add resizeCkeditor as a listener to CKEDITOR instanceReady event', () => {
        this.ckEditorEventBinderSpy.reset();

        this.objectiveEditComponent = shallow(ObjectiveEdit,{
          localVue:localVue,
          propsData:{ objective: this.objectiveData },
          mocks:{
            $store:{
              state: { foo: "bar" },
              dispatch: this.storeDispatchStub
            }
          }
        });

        assert.equal(this.ckEditorEventBinderSpy.callCount,1);
        assert.equal(this.ckEditorEventBinderSpy.args[0][0], 'instanceReady');
        assert.deepEqual(this.ckEditorEventBinderSpy.args[0][1], this.objectiveEditComponent.vm.resizeCkEditor);

      });
    });
  });
});