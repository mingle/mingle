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
import assert from 'assert'
import DropDown from "../../../app/javascript/components/DropDown"
import {mount, createLocalVue} from '@vue/test-utils'
import vClickOutside from 'v-click-outside'
import sinon from 'sinon'

let sandbox = sinon.createSandbox();
let localVue = createLocalVue();
localVue.use(vClickOutside);

describe('DropDown', function () {
  beforeEach(() => {
    this.dropDownComponent = mount(DropDown, {
      localVue,
      propsData: {
        selectOptions: [{label: 'Label1', value: 'Value1'}, {label: 'Label2', value: 'Value2'}]
      }
    });
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('Initialization', () => {
    beforeEach(() => {
      this.dropDownComponent = mount(DropDown, {localVue});
    });
    it('should have default data', () => {
      assert.ok(!this.dropDownComponent.vm.openDropDownOptions);
      assert.ok(this.dropDownComponent.vm.highlightSelected);
    });

    it('should have default props', () => {
      assert.equal('simple-drop-down', this.dropDownComponent.vm.containerClass);
      assert.equal(0, this.dropDownComponent.vm.selected.length);
      assert.equal(0, this.dropDownComponent.vm.selectOptions.length);
      assert.equal('label', this.dropDownComponent.vm.label);
      assert.equal('value', this.dropDownComponent.vm.value);
      assert.ok(!this.dropDownComponent.vm.disabled);
      assert.equal('Select', this.dropDownComponent.vm.placeHolder);
      assert.equal('function', typeof this.dropDownComponent.vm.onChange);
      assert.deepEqual({maxWidth:'200px',maxHeight:'200px', buttonTypeDropdown:false},this.dropDownComponent.vm.options);
    });

    it('onChange should emit drop-down-option-changed event', () => {
      this.dropDownComponent.vm.onChange('data');
      let emittedEvent = this.dropDownComponent.emitted('drop-down-option-changed');
      assert.equal(1, emittedEvent.length);
      assert.deepEqual(['data'], emittedEvent[0]);
    });
  });

  describe('Renders', () => {

    it('should render drop down container with default class', () => {
      assert.ok(this.dropDownComponent.classes().includes('simple-drop-down'));
    });

    it('should render drop down container with given container class prop', () => {
      this.dropDownComponent.setProps({containerClass: 'drop-down'});
      assert.ok(this.dropDownComponent.classes().includes('drop-down'));
    });

    it('should render enabled drop down toggle', () => {
      this.dropDownComponent.setProps({options:{buttonTypeDropdown:true,maxWidth:'200px'}});
      assert.equal(undefined,this.dropDownComponent.find('button.drop-down-toggle').attributes().disabled);
      assert.equal('200px',this.dropDownComponent.find('button.drop-down-toggle').element.style['max-width']);
    });

    it('should render disabled drop down toggle', () => {
      this.dropDownComponent.setProps({disabled:true,options:{buttonTypeDropdown:true}});
      assert.equal('disabled',this.dropDownComponent.find('button.drop-down-toggle').attributes().disabled);
    });

    it('should not render drop-down-toggle as button', () => {
      this.dropDownComponent.setProps({options:{buttonTypeDropdown:false,maxWidth:'200px'}});
      assert.ok(this.dropDownComponent.find('div.drop-down-toggle').exists());
      assert.equal('200px',this.dropDownComponent.find('div.drop-down-toggle').element.style['max-width']);
    });

    it('should render dropDown toggle with selected value', () => {
      let dropDownComponent = mount(DropDown, {
        localVue,
        propsData: {
          selectOptions: [{label: 'Label1', value: 'Value1'}, {label: 'Label2', value: 'Value2'}]
        },
        computed:{selectedValue(){return 'Selected Value';}}
      });

      this.dropDownToggle = dropDownComponent.find('.drop-down-toggle');
      assert.ok(this.dropDownToggle.exists());
      assert.equal('Selected Value', this.dropDownToggle.text());
    });

    it('should render fa angle down icon when drop down options are not visible', () => {
      this.dropDownToggle = this.dropDownComponent.find('.drop-down-toggle');
      assert.ok(this.dropDownToggle.find('.drop-down-toggle .fa.fa-angle-down').exists());
    });

    it('should render fa angle up icon when drop down options are visible', () => {
      this.dropDownToggle = this.dropDownComponent.find('.drop-down-toggle');
      assert.ok(!this.dropDownToggle.find('.fa.fa-angle-up').exists());
      this.dropDownComponent.setData({openDropDownOptions: true});

      assert.ok(this.dropDownToggle.find('.fa.fa-angle-up').exists());
      assert.ok(!this.dropDownToggle.find('.fa.fa-angle-down').exists());
    });

    it('should not render drop down options', () => {
      assert.ok(!this.dropDownComponent.find('.drop-down-options').exists());
    });

    it('should render drop down options', () => {
      this.dropDownComponent.setData({openDropDownOptions: true});
      let dropDownOptions = this.dropDownComponent.find('.drop-down-options');
      assert.ok(dropDownOptions.exists());
      assert.equal(2, dropDownOptions.findAll('.drop-down-option').length);
      assert.equal('Label1', dropDownOptions.findAll('.drop-down-option').at(0).text());
      assert.equal('Label2', dropDownOptions.findAll('.drop-down-option').at(1).text());
    });

    it('drop down options should not have selected class', () => {
      this.dropDownComponent.setData({openDropDownOptions: true});
      assert.ok(!this.dropDownComponent.find('.drop-down-options .selected').exists())
    });

    it('drop down options should have selected class', () => {
      this.dropDownComponent.setData({openDropDownOptions: true});
      this.dropDownComponent.setMethods({
        isSelected(){
          return true
        }
      });

      assert.equal(2, this.dropDownComponent.findAll('.drop-down-options .selected').length)
    });

  });

  describe('Interactions', () => {
    describe('Click', () => {
      it('on drop down toggle should invoke toggleDropDownOptions method', () => {
        let toggleDropDownOptionsStub = sandbox.stub();
        this.dropDownComponent.setMethods({toggleDropDownOptions: toggleDropDownOptionsStub});

        assert.equal(0, toggleDropDownOptionsStub.callCount);
        this.dropDownComponent.find('.drop-down-toggle').trigger('click');

        assert.equal(1, toggleDropDownOptionsStub.callCount);
      });

      it('on any drop down option should invoke optionSelected', () => {
        let optionSelectedStub = sandbox.stub();
        this.dropDownComponent.setData({openDropDownOptions:true});
        this.dropDownComponent.setMethods({optionSelected:optionSelectedStub});

        assert.equal(0, optionSelectedStub.callCount);

        this.dropDownComponent.findAll('.drop-down-options .drop-down-option').at(0).trigger('click');
        this.dropDownComponent.findAll('.drop-down-options .drop-down-option').at(1).trigger('click');

        assert.equal(2, optionSelectedStub.callCount);
        assert.deepEqual({label:'Label1', value:'Value1'}, optionSelectedStub.args[0][0]);
        assert.deepEqual({label:'Label2', value:'Value2'}, optionSelectedStub.args[1][0]);
      });
    });

    describe('Mouseover', () => {
      it('on any drop down option should set highlightSelected to false', () => {
        this.dropDownComponent.setData({highlightSelected:true, openDropDownOptions:true});

        this.dropDownComponent.find('.drop-down-options .drop-down-option').trigger('mouseover');

        assert.ok(! this.dropDownComponent.vm.highlightSelected);
      });
    });

  });

  describe('Methods', () => {
    describe('ToggleDropDownOptions', () => {

      it('should toggle openDropDownOptions', () => {
        this.dropDownComponent.setData({openDropDownOptions:false});
        this.dropDownComponent.vm.toggleDropDownOptions();

        assert.ok(this.dropDownComponent.vm.openDropDownOptions);
        this.dropDownComponent.vm.toggleDropDownOptions();

        assert.ok(!this.dropDownComponent.vm.openDropDownOptions);

      });

    });

    describe('OnClickOutside', () => {
      it('should set openDropDownOptions to false', () => {
        this.dropDownComponent.setData({openDropDownOptions:true});
        this.dropDownComponent.vm.onClickOutside();

        assert.ok(!this.dropDownComponent.vm.openDropDownOptions);
      });

      it('should set highlightSelected to true', () => {
        this.dropDownComponent.setData({highlightSelected:false});
        this.dropDownComponent.vm.onClickOutside();

        assert.ok(this.dropDownComponent.vm.highlightSelected);
      });
    });

    describe('IsSelected', () => {
      it('should return false when option is not selected ', () => {
        assert.ok(!this.dropDownComponent.vm.isSelected({label:'Label1', value:'Value1'}));
      });

      it('should return false when different option is selected ', () => {
        this.dropDownComponent.setData({selectedOption:[{label:'Label2', value:'Value2'}]});

        assert.ok(!this.dropDownComponent.vm.isSelected({label:'Label1', value:'Value1'}));
      });

      it('should return true when same option is selected ', () => {
        this.dropDownComponent.setProps({selected:[{label:'Label1', value:'Value1'}]});

        assert.ok(this.dropDownComponent.vm.isSelected({label:'Label1', value:'Value1'}));
      });

      it('should use provided label and value props', () => {
        this.dropDownComponent.setProps({label:'name', value:'id', selected:[{name:'Label1', id:'Value1'}]});

        assert.ok(this.dropDownComponent.vm.isSelected({name:'Label1', id:'Value1'}));
      });

    });

    describe('OptionSelected', () => {
      it('should set openDropDownOptions to false', () => {
        this.dropDownComponent.setData({openDropDownOptions:true});
        this.dropDownComponent.vm.optionSelected({});

        assert.ok(!this.dropDownComponent.vm.openDropDownOptions);
      });

      it('should use provided label and value props', () => {
        let onChangeStub = sandbox.stub();
        this.dropDownComponent.setProps({onChange:onChangeStub,label:'name', value:'id'});

        assert.equal(0,onChangeStub.callCount);
        this.dropDownComponent.vm.optionSelected({name:'Label1', id:'Value1'});

        assert.equal(1,onChangeStub.callCount);
        assert.deepEqual({name: 'Label1', id: 'Value1'}, onChangeStub.args[0][0]);
      });

      it('should set highlightSelected to true', () => {
        this.dropDownComponent.setData({highlightSelected:false});
        this.dropDownComponent.vm.optionSelected({name:'Label1', id:'Value1'});

        assert.ok(this.dropDownComponent.vm.highlightSelected);
      });

      it('should invoke onChanged when different option is selected', () => {
        let onChangeStub = sandbox.stub();
        this.dropDownComponent.setProps({onChange:onChangeStub});

        assert.equal(0,onChangeStub.callCount);
        this.dropDownComponent.vm.optionSelected({label:'Label1', value:'Value1'});

        assert.equal(1,onChangeStub.callCount);
        assert.deepEqual({label: 'Label1', value: 'Value1'}, onChangeStub.args[0][0]);
      });

      it('should invoke onChanged when same option is selected', () => {
        let onChangeStub = sandbox.stub();
        this.dropDownComponent.setProps({selected:[{label:'Label2', value:'Value2'}], onChange:onChangeStub});

        this.dropDownComponent.vm.optionSelected({label:'Label2', value:'Value2'});

        assert.equal(0, onChangeStub.callCount);
      });
    });

    describe('GetOptionLabel', () => {
      it('should return option label when option is an object', () => {
        assert.equal(this.dropDownComponent.vm.getOptionLabel({label:'Label',value:'Value'}), 'Label')
      });

      it('should return option label when option is a string or number', () => {
        assert.equal(this.dropDownComponent.vm.getOptionLabel('Label'), 'Label');
        assert.equal(this.dropDownComponent.vm.getOptionLabel(20), 20);
      });
    });

    describe('GetOptionValue', () => {
      it('should return option value when option is an object', () => {
        assert.equal(this.dropDownComponent.vm.getOptionValue({label:'Label',value:'Value'}), 'Value')
      });

      it('should return option value when option is a string or number', () => {
        assert.equal(this.dropDownComponent.vm.getOptionValue('Value'), 'Value');
        assert.equal(this.dropDownComponent.vm.getOptionValue(20), 20);
      });
    });
  });

  describe('Computed', () => {
    describe('SelectedValue', () => {
      it('should return place holder when displaySelectedValue false', () => {
        this.dropDownComponent.setProps({displaySelectedValue:false});
        this.dropDownComponent.setData({selectedOption:[{label:'Selected label', value:'Selected value'}]});

        assert.equal('Select', this.dropDownComponent.vm.selectedValue);
      });

      it('should return place holder when displaySelectedValue true and nothing is selected', () => {

        assert.equal('Select', this.dropDownComponent.vm.selectedValue);
      });

      it('should return selected value label when displaySelectedValue true', () => {
        this.dropDownComponent.setProps({selected:[{label:'Selected label', value:'Selected value'}]});
        assert.equal('Selected label', this.dropDownComponent.vm.selectedValue);
      });

      it('should use passed label and value props', () => {
        this.dropDownComponent.setProps({label:'name', value:'id',selected:[{name:'Selected label', id:'Selected value'}]});
        assert.equal('Selected label', this.dropDownComponent.vm.selectedValue);
      });
    });
  });
  
});