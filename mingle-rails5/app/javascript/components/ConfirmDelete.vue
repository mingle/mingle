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
    <modal name="confirm-delete" class="confirm-delete-modal" height="auto" width="660" :click-to-close="false">
        <div class="confirm-delete-container">
            <div class="header">
                <h2>{{heading}}</h2>
                <strong class='close fa fa-times fa-inverse' @click="$modal.hide('confirm-delete')"></strong>
            </div>
            <div class="content">
                <div class="warning-box">{{message}}</div>
            </div>
            <div class="actions">
                <div class="action-bar">
                    <a class="ok" href="javascript:void(0)" @click="deleteConfirmed"><slot name="okActionText">Continue to delete</slot></a>
                    <a class="link_as_button" href="javascript:void(0)" @click="$modal.hide('confirm-delete')">Cancel</a>
                </div>
            </div>
        </div>
    </modal>
</template>

<script>

    export default {
        props: {
            heading: {
                type: String,
                default: 'Confirm Delete'
            },
            message: {
                type: String,
                default: 'CAUTION! This action is final and irrecoverable.'
            }
        },
        methods: {
            deleteConfirmed: function () {
                this.$emit("delete");
                this.$modal.hide("confirm-delete");
            }
        }
    }
</script>

<style scoped lang="scss">
    .confirm-delete-container {
        background: white;
        height: 100%;
        .header {
            background: #333;
            position: relative;
            h2 {
                color:white;
                padding: 10px 35px 10px 15px;
            }
            .close {
                position: absolute;
                right: 14px;
                top: 14px;
                overflow: hidden;
                cursor: pointer;
            }
        }
        .action-bar {
        border-top: 1px #CCC solid;
        }
    }
</style>
<style>
    .confirm-delete-modal .v--modal {
        border-radius: 0px;
    }
</style>
