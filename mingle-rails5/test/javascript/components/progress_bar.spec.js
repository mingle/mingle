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
import ProgressBar from '../../../app/javascript/components/ProgressBar.vue'
import sinon from "sinon";
import assert from "assert";
import {mount, createLocalVue} from '@vue/test-utils'

const localVue = createLocalVue();

let sandbox = sinon.createSandbox();


describe('ProgressBar.vue', function () {
  beforeEach(() => {
    this.propsData = {target: '.target-element'};
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('StyleConfig', () => {
    it('should be default when not set', () => {
      sandbox.stub(document, 'querySelector').withArgs('.target-element').returns({
            getStyle(style){
              let styles = {'margin-top': '20px', 'padding-top':'10px'};
              return styles[style];
            },
            getWidth() {
              return 40;
            }, positionedOffset() {
              return {}
            }
          }
      );
      this.ProgressBarComponent = mount(ProgressBar, {
        propsData: this.propsData,
        localVue: localVue
      });
      let {float, left, top, position} = this.ProgressBarComponent.find('.linear-progress-bar').element.style;

      assert.equal('left', float);
      assert.equal('0px', left);
      assert.equal('0px', top);
      assert.equal('0px', top);
      assert.equal('absolute', position);
    });

    it('should give priority to boxStyle config', () => {
      sandbox.stub(document, 'querySelector').withArgs('.target-element').returns({
            getStyle(style){
              let styles = {'margin-top': '20px', 'padding-top':'10px'};
              return styles[style];
            },
            getWidth() {
              return 40;
            }, positionedOffset() {
              return {left: 20, top: 40}
            }
          }
      );
      this.ProgressBarComponent = mount(ProgressBar, {
        propsData: this.propsData,
        localVue: localVue
      });
      this.propsData.boxstyle = {position: 'relative'};
      this.ProgressBarComponent.setProps(this.propsData);

      return localVue.nextTick().then(() => {
        let {width, position, top, left, margin, padding} = this.ProgressBarComponent.find('.linear-progress-bar').element.style;
        assert.equal('40px', width);
        assert.equal('relative', position);
        assert.equal('40px', top);
        assert.equal('20px', left);
        assert.equal('20px', margin);
        assert.equal('10px', padding);
      });
    });
  });
});