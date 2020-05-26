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
import TooltipStyleMessage from '../../../app/javascript/components/TooltipStyleMessage.vue'
import sinon from "sinon";
import assert from "assert";
import {mount, createLocalVue} from '@vue/test-utils'

const localVue = createLocalVue();

let sandbox = sinon.createSandbox();


describe('TooltipStyleMessage.vue', function () {
  beforeEach(() => {
    this.modalHideSpy = sandbox.spy();
    this.propsData = {config: {position:{}}};
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('Renders', () => {
    beforeEach(() => {
      this.toolTipStyleMessageBoxComponent = mount(TooltipStyleMessage, {
        propsData: this.propsData,
        localVue: localVue,
      });
    });
    it('should not render message when not set', () => {
      assert.ok(!this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());
    });

    it('should render message', () => {
      this.propsData.message = {type:'message-type', text:"message"};
      this.toolTipStyleMessageBoxComponent.setProps(this.propsData);
      return localVue.nextTick().then(() => {
        assert.ok(this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());
      });
    });

    it('should have bottom-arrow class', () => {
      this.propsData.message = {type:'message-type', text:"message"};
      this.toolTipStyleMessageBoxComponent.setProps(this.propsData);
      assert.ok(this.toolTipStyleMessageBoxComponent.find('.bottom-arrow').exists());
    });

    it('should use arrowStyle property as class', () => {
      this.propsData.message = {type:'message-type', text:"message"};
      this.propsData.arrowStyle = 'left-center-arrow';
      this.toolTipStyleMessageBoxComponent.setProps(this.propsData);
      assert.ok(this.toolTipStyleMessageBoxComponent.find('.left-center-arrow').exists());
    });

    it('should replace named slot with passed content', () => {
      this.propsData.message = {type:'message-type', text:"message"};
      let toolTipStyleMessageBoxComponent = mount(TooltipStyleMessage, {
        propsData: this.propsData,
        localVue: localVue,
        slots: {
          actions: '<div class="slot-content" />',
        }
      });

      assert.ok(toolTipStyleMessageBoxComponent .find('.slot-content').exists());
    });

    it('should not render close button', () => {
      this.toolTipStyleMessageBoxComponent.setProps({message:{type:'message-type', text:"message"}});
      assert.ok(!this.toolTipStyleMessageBoxComponent.find('.close-button.fa.fa-times').exists());
    });

    it('should render close button', () => {
      this.toolTipStyleMessageBoxComponent.setProps({close:true,message:{type:'message-type', text:"message"}});
      assert.ok(this.toolTipStyleMessageBoxComponent.find('.close-button.fa.fa-times').exists());
    });
  });

  describe('Position', () => {
    beforeEach(() => {
      this.propsData.message = {type:'message-type', text:"message"};
      this.toolTipStyleMessageBoxComponent = mount(TooltipStyleMessage, {
        propsData: this.propsData,
        localVue: localVue,
      });
    });
    it('should be 0px from left and 35px from bottom when not set', () => {
      let {left, bottom} = this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').element.style;

      assert.equal(left, '0px');
      assert.equal(bottom, '35px');
    });

    it('should give priority to position of config property', () => {
      this.propsData.config = {position: {left: 10, bottom: 20}};
      this.toolTipStyleMessageBoxComponent.setProps(this.propsData);

      return localVue.nextTick().then(() => {
        let {left, bottom} = this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').element.style;
        assert.equal(left, '10px');
        assert.equal(bottom, '20px');
      });
    });
  });

  describe('SelfDestroyable', () => {
    beforeEach(() => {
      this.propsData.config = {activeTime:1000, position:{}};
      this.toolTipStyleMessageBoxComponent = mount(TooltipStyleMessage, {
        propsData: this.propsData,
        localVue: localVue,
      });
    });
    it('should get destroyed after 1 second', (done) => {
      assert.ok(!this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());

      this.propsData.message = {type:'message-type', text:"message"};
      this.toolTipStyleMessageBoxComponent.setProps(this.propsData);

      assert.ok(this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());

      setTimeout(() => {
        assert.ok(!this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists(),"should have got destroyed after 1000 milliseconds");
        done();
      },1001);
    });

    it('should not get destroyed when selfDestroyable is false', (done) => {
      assert.ok(!this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());

      this.propsData.message = "new_jmessage";
      Object.assign(this.propsData.config, {selfDestroyable: false, activeTime:10});


      this.toolTipStyleMessageBoxComponent.setProps(this.propsData);

      assert.ok(this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());

      setTimeout(() => {
        assert.ok(this.toolTipStyleMessageBoxComponent.find('.tooltip-style-message').exists());
        done();
      },12);
    });
  });
});
