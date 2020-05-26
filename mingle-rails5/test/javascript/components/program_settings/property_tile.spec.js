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
import PropertyTile from '../../../../app/javascript/components/program_settings/PropertyTile'
import assert from "assert";
import {shallow, createLocalVue} from '@vue/test-utils'

const localVue = createLocalVue();

describe('PropertyTile.vue', () => {
    let propertyTileComponent;

    beforeEach(function () {
        propertyTileComponent = shallow(PropertyTile, {
            localVue,
            propsData: {property: {name:'Value'}}
        })
    });

    describe('Renders', function () {
        it('property name, drag and remove icons',  () => {
            assert.ok(propertyTileComponent.find('.property-tile .fa.fa-bars').exists());
            assert.ok(propertyTileComponent.find('.property-tile .fa.fa-times').exists());
            assert.equal(propertyTileComponent.find('.property-tile .property-name').text(), 'Value');
        });
    });
});