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
import Objective from '../../../../app/javascript/components/objectives/Objective.vue'
import assert from "assert"
import sinon from 'sinon'
import {mount} from '@vue/test-utils'

let sandbox = sinon.createSandbox();


describe('Objective.vue', () => {
  let objective, storeDispatchStub;
  beforeEach(function () {
    storeDispatchStub = sandbox.stub();
    sandbox.stub(document, 'querySelector').returns({
          getStyle(style) {
            let styles = {'margin-top': '20px', 'padding-top': '10px'};
            return styles[style];
          },
          getWidth() {
            return 40;
          }, positionedOffset() {
            return {left: 20, top: 40}
          }
        }
    );
    objective = mount(Objective, {
      propsData: {objective: {name: 'Foo', number: 1234, position: 10}},
      mocks: {
        $store: {state: {disableDragging: false}, dispatch: storeDispatchStub}
      }
    });
  });

  afterEach(function () {
    sandbox.restore();
  });

  describe('Renders', function () {
    it('name and number for backlog objective', () => {
      assert.equal('Foo', objective.find('div.name').text());
      assert.equal('1234', objective.find('span.number').text());
    });

    it('should not render progress bar', () => {
      assert.ok(!objective.find('.linear-progress-bar').exists());
    });

    it('should render progress bar when showProgressBar is true', () => {
      objective.setData({showProgressBar: true});
      assert.ok(objective.find('.linear-progress-bar').exists());
    });

    it('should render progress bar when showProgressBarOnDrop is true', (done) => {
      objective = mount(Objective, {
        propsData: {objective: {name: 'Foo', number: 1234, position: 10}},
        mocks: {
          $store: {state: {disableDragging: false}, dispatch: storeDispatchStub}
        },
        computed: {
          showProgressBarOnDrop() {
            return true;
          }
        }
      });
      setTimeout(() => {
        assert.ok(objective.find('.linear-progress-bar').exists());
        done();
      });
    });

    it('should not have dragging-disabled class', () => {
      assert.ok(!objective.find('.objective.dragging-disabled').exists());
    });

    it('should have dragging-disabled class', () => {
      objective = mount(Objective, {
        propsData: {objective: {name: 'Foo', number: 1234, position: 10}},
        mocks: {
          $store: {state: {disableDragging: false}, dispatch: storeDispatchStub}
        },
        computed: {
          isDraggingDisabled() {
            return true;
          }
        }
      });

      assert.ok(objective.find('.objective.dragging-disabled').exists());
    });
  });

  describe('Data', () => {
    it('showProgressBar should be false', () => {
      assert.ok(!objective.showProgressBar);
    });
  });

  describe('Props', () => {
    describe('IsDraggingDisabled', () => {
      it('should be false', () => {
        assert.ok(!objective.vm.isDraggingDisabled);
      });

      it('should be true', () => {
        objective = mount(Objective, {
          propsData: {objective: {name: 'Foo', number: 1234, position: 10}},
          mocks: {
            $store: {state: {disableDragging: true}, dispatch: storeDispatchStub}
          }
        });
        assert.ok(objective.vm.isDraggingDisabled);
      });
    });

    describe('ShowProgressBarOnDrop', () => {
      it('should be false', () => {
        assert.ok(!objective.vm.showProgressBarOnDrop);
      });

      it('should be true', () => {
        objective.setProps({droppedObjectiveNumber: objective.vm.objective.number});
        assert.ok(objective.vm.showProgressBarOnDrop);
      });
    });
  });

  describe('Interaction', function () {
    describe('Click', () => {
      it('on objective item should invoke openObjectivePopup', () => {
        let openObjectivePopupStub = sandbox.stub();
        objective.setMethods({openObjectivePopup: openObjectivePopupStub});

        assert.equal(openObjectivePopupStub.callCount, 0);
        objective.find('.objective').trigger('click');

        assert.equal(openObjectivePopupStub.callCount, 1);
        assert.deepEqual(openObjectivePopupStub.args[0][0], {name: 'Foo', number: 1234, position: 10});

      });
    });
  });

  describe('Methods', () => {
    describe('OpenObjectivePopup', () => {
      it('should dispatch fetchObjective with backlog objective number', () => {
        assert.equal(storeDispatchStub.callCount, 0);
        storeDispatchStub.returns(Promise.resolve(''));

        objective.vm.openObjectivePopup({number: 1});

        assert.equal(storeDispatchStub.callCount, 1);
      });

      it('should invoke toggleProgressBar on successful response', (done) => {
        assert.equal(storeDispatchStub.callCount, 0);
        storeDispatchStub.returns(Promise.resolve(''));
        assert.ok(!objective.vm.showProgressBar);

        objective.vm.openObjectivePopup({number: 1});

        assert.ok(objective.vm.showProgressBar);
        assert.equal(storeDispatchStub.callCount, 1);

        setTimeout(() => {
          assert.ok(!objective.vm.showProgressBar);
          done();
        });
      });

      it('should emit open-objective event on successful response', (done) => {
        storeDispatchStub.returns(Promise.resolve({success: true}));

        assert.ok(!objective.emitted()['open-objective']);
        objective.vm.openObjectivePopup({number: 1});

        setTimeout(() => {
          assert.ok(objective.emitted()['open-objective']);
          done();
        });
      });

      it('should not emit open-objective event on failure', (done) => {
        storeDispatchStub.returns(Promise.resolve({success: false}));

        assert.ok(!objective.emitted()['open-objective']);
        objective.vm.openObjectivePopup({number: 1});

        setTimeout(() => {
          assert.ok(!objective.emitted()['open-objective']);
          assert.equal(storeDispatchStub.callCount, 1);
          assert.equal(storeDispatchStub.args[0][0], 'fetchObjective');
          done();
        });
      });
    });
  });
});
