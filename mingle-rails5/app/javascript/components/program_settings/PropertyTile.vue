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
    <div class="property-tile" >
        <span class="fa fa-bars"></span>
        <span class="property-name">{{property.name}}</span>
        <span class="close fa fa-times"></span>
        </div>
</template>

<script>
    export default {
        name: "PropertyTile",
        props:{
            property: {
                type:Object,
                default:'property'
            }
        }
    }
</script>

<style lang="scss" scoped>
.property-tile{
    border: 1px solid #ccc;
    display: inline-block;
    padding: 5px;
    font-size: 12px;
    -moz-box-shadow: 1px 2px 3px 0px #989393;
    -webkit-box-shadow: 1px 2px 3px 0px #989393;
    margin-right: 15px;
    margin-bottom: 10px;
    background-color: white;

    .property-name {
        width: 90px;
        display: inline-block;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        position: relative;
        top: 2px;
    }

    .fa {
        color: #ccc;
        position: relative;
        bottom: 2px;
    }
    .fa-bars{
        padding-right: 5px;
    }

    .close.fa-times{
        padding-left: 5px;
    }

}
</style>