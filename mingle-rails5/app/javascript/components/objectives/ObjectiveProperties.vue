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
    <div class="objective-properties-container">
        <div class="objective-properties" id="objective_properties">
            <objective-property v-for="objectiveProperty in objectiveProperties"
                                :objective-property="objectiveProperty"
                                @change="propertyUpdated"
            />
        </div>
    </div>

</template>
<script>
  import ObjectiveProperty from "./ObjectiveProperty";
  export default{
    components: {ObjectiveProperty},
    props: {
      objectiveProperties: {
        type: Object,
        required: true
      }
    },
    methods:{
      propertyUpdated(updatedProperty){
        let properties = Object.assign({},this.objectiveProperties,{[updatedProperty.name]:updatedProperty});
        this.$emit('propertiesChanged',properties);
      }
    }
  }
</script>
<style lang="scss" scoped>
    .objective-properties-container {
                width: 100%;
                height: 45px;
                position: absolute;
                bottom: 60px;
                .objective-properties {
                    height: 100%;
                    width: calc(100% - 16px);
                    background-color: #eee;
                    position: inherit;
                    display: flex;
                    top: 0px;
                    padding: 15px;
                    .objective-property {
                        flex: 1;
                        display: flex;
                        align-items: center;
                        .objective-property-ratio-label{
                            padding-right:5px;
                        }
                    }
                }
            }
</style>
