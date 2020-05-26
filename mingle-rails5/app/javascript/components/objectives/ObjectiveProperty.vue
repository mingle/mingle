<!--
Copyright 2020 ThoughtWorks, Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
-->
<template>
  <div class="objective-property" :class="`objective-property-${propertyNameAsClass()}`">
    <div class="objective-property-name"><strong>{{objectiveProperty.name}}:</strong></div>
    <drop-down
               v-if="!readOnlyMode"
               :containerClass="'objective-property-dropdown'"
               :selected="selectedValue"
               :select-options="allowedValues"
               id="change_member_role"
               @drop-down-option-changed="updateProperty"
    />
    <span v-else>{{selected}}</span>
  </div>
</template>

<script>
  import DropDown from "../DropDown";

  export default {
    components: {
      DropDown
    },
    props: {
      objectiveProperty: {
        type: Object,
        required: true
      }
    },
    data: function () {
      return {
        selected: (this.objectiveProperty.value === undefined ? '' : this.objectiveProperty.value)
      }
    },
    methods: {
      propertyNameAsClass() {
        let propertyName = this.objectiveProperty.name.toLowerCase();
        return propertyName.replace(/\W+/g, '-');
      },
      updateProperty(property) {
        this.selected = property;
      }
    },
    computed: {
      selectedValue() {
        return [this.selected];
      },
      allowedValues(){
        let allowedValues = ['(not set)'];
        return allowedValues.concat(this.objectiveProperty.allowed_values);
      },
      readOnlyMode(){
        return this.$store.state.toggles.readOnlyModeEnabled;
      }
    },
    watch: {
      selected(newValue, oldValue) {
        if (newValue !== oldValue)
          this.$emit('change', Object.assign({}, this.objectiveProperty, {value: newValue}));
      }
    }
  }
</script>.
<style lang="scss">
  #objective_properties {
    .objective-property-dropdown {
      .drop-down-toggle {
        border: none;
        color: #3298bb;
        span {
          padding-left: 20px;
        }
      }
    }
  }
</style>
