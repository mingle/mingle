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
  <div class="program-team">
    <message-box :message="message"/>
    <div class="program-team-header">
      <h1>
        Team Members
      </h1>
    </div>
    <div class="actions">
      <div class="messages">
        <span class="user-selection-message" v-if="selectedMembersCount()">{{selectedMembersMessage()}}</span>
        <span class="select-all-team-members" v-if="shouldDisplaySelectAllMembersLink" @click="selectAllTeamMembers()"> Select all {{Object.keys(members).length}} members</span>
      </div>
      <div>
        <button class="add-member primary" v-if="showAddTeamMemberButton" @click="openAddMemberPopUp">
          <span class="fa fa-plus"></span>
          Add Team Member
        </button>
        <add-member-pop-up v-bind:heading="addMemberPopUpHeading"
                           v-on:update-message="updateMessage" />
        <confirm-delete v-bind:message="confirmationMessage" v-bind:heading="confirmationTitle"
                        v-bind:confirmationButtonText="confirmationButtonText" v-on:delete="removeSelectedMembers">
          <template slot="okActionText">{{confirmationButtonText}}</template>
        </confirm-delete>
        <progress-bar v-if="showProgressBar" :target="progressBarTarget"/>
        <button class="remove-member" v-if="$store.state.currentUser.admin" :disabled="isBulkActionsEnabled"
                @click="showConfirmationBox">
          <span class="fa fa-times"></span>
          Remove
        </button>
          <drop-down :containerClass="'change-member-role'"
                   :select-options="$store.state.programTeam.roles"
                   :place-holder="'CHANGE ROLE'"
                   :label="'name'" :value="'id'"
                   :display-selected-value="false"
                   :disabled="isBulkActionsEnabled"
                   id="change_member_role"
                   v-if="$store.state.currentUser.admin"
                     :options="{buttonTypeDropdown:true}"
                   @drop-down-option-changed="updateRoles"
        />
      </div>
    </div>
    <div class="program-user-list">
      <v-client-table :columns="columns" :data="programMembers" :options="options" ref="programTeam"
                      @pagination="resetSelectAll" @filter="resetSelectAll">
        <input slot="selected" slot-scope="props" type="checkbox" v-model="props.row.selected"
               @click="selectMember(props.row)" :id="`select_${props.row.login}`" :title="`Select ${props.row.name}`"/>
        <div slot="role" slot-scope="props" :class="{'role-updated': lastUpdatedMember.login === props.row.login }">
          <drop-down :containerClass="'members-role-drop-down'"
                     :select-options="$store.state.programTeam.roles"
                     :place-holder="'CHANGE ROLE'"
                     :selected="[props.row.role]"
                     :label="'name'" :value="'id'"
                     :options="{maxWidth:'150px'}"
                     :id="`${props.row.login}_role_dropdown`"
                     v-if="isAuthorizedToChangeRole(props.row.login) && props.row.activated"
                     :on-change="roleChanged(props.row.login)"
          />
          <p v-else>{{props.row.role.name}}</p>
        </div>
        <span class="projects-truncation" slot="projects" slot-scope="props" :title="props.row.projects"> {{props.row.projects}}</span>
        <i slot="afterFilter" class="vue-table-search-icon fa fa-search"></i>
      </v-client-table>
    </div>
  </div>
</template>

<script>
  import ConfirmDelete from './ConfirmDelete'
  import MessageBox from './MessageBox'
  import AddMemberPopUp from './AddMemberPopUp'
  import TooltipStyleMessage from './TooltipStyleMessage'
  import ProgressBar from './ProgressBar'
  import vSelect from 'vue-select';
  import DropDown from './DropDown';

  export default {
    components: {ConfirmDelete, MessageBox, AddMemberPopUp, TooltipStyleMessage, ProgressBar, vSelect, DropDown},
    data: function () {
      return {
        selectedMemberRole: [],
        progressBarTarget:'',
        showProgressBar: false,
        confirmationMessage: "Are you sure you want to remove the selected members from the program?",
        confirmationTitle: "Remove Program Members",
        confirmationButtonText: "Confirm",
        lastUpdatedMember:{},
        message: {},
        displaySelectAllMembersLink: false,
        disableBulkActions: true,
        members: this.getProgramMembers(),
        columns: (this.$store.state.currentUser.admin ? ["selected", "name", "login", "projects", "role", "email"] : ["name", "login", "projects", "role", "email"]),
        addMemberPopUpHeading: 'Add Team Member',
        options: {
            rowClassCallback(member) {
              return member.activated ? false : "deactive";
            },
          headings: {
            selected: function (h) {
              return h('input', {
                attrs: {
                  type: 'checkbox',
                  id: 'select_all_checkbox',
                  title: 'Select all team member on this page'
                },
                on: {
                  click: (e) => {
                    this.selectMembersOnPage(e.target.checked)
                  }
                }
              })
            },
            name: "Name",
            login: "Sign-in name",
            role: "Role",
            email: "Email"
          },
          perPage: 25,
          perPageValues: [25],
          texts: {
            filterPlaceholder: "Search for a team member",
            count: "Viewing {from} - {to} of {count} users"
          },
          pagination: {nav: 'scroll'},
          sortIcon: {
            is: 'fa-sort',
            base: 'fas',
            up: 'sort-alpha-up',
            down: 'sort-alpha-down'
          },
          sortable: ['name', 'role'],
          filterable: ['name', 'login', 'role', 'email'],
          orderBy: {
            column: 'name',
            ascending: true
          },
          customSorting: {
            role(ascending) {
              return function (left, right) {
                if(ascending)
                  return left.role.name > right.role.name ? 1 : -1;
                return left.role.name < right.role.name ? 1 : -1;
              }
            }
          }
        }
      }
    },
    methods: {
      getProgramMembers() {
        return this.$store.state.programTeam.members;
      },

      reassignProgramMembers() {
        this.members = Object.assign({}, this.members);
      },
      selectMembersOnPage(checked) {
        this.$refs.programTeam.filteredData.forEach((teamMember) => {
          this.select(teamMember, checked);
        });
        this.reassignProgramMembers();
        this.displaySelectAllMembersLink = !this.areAllMembersSelected() && checked;
        this.toggleRemoveButton();
      },
      select(teamMember, checked) {
        this.members[teamMember.login].selected = (checked === undefined ? !this.members[teamMember.login].selected : checked);
      },
      selectMember(teamMember) {
        this.select(teamMember);
        this.reassignProgramMembers();
        this.toggleRemoveButton();
        this.resetSelectAll();
      },
      resetSelectAll() {
        this.setSelectAllTo(!this.$refs.programTeam.filteredData.some((x) => Boolean(this.members[x.login].selected) === false));
      },
      toggleRemoveButton() {
        this.disableBulkActions = !Object.values(this.members).some((user) => user.selected === true);
      },
      selectedMembersCount() {
        return Object.values(this.members).filter((user) => user.selected).length
      },
      selectAllTeamMembers() {
        this.displaySelectAllMembersLink = false;
        for (let key in this.members)
          this.select(this.members[key], true);
        this.reassignProgramMembers();
        this.setSelectAllTo(true);
      },
      setSelectAllTo(value) {
        let selectAllCheckBox = this.$refs.programTeam.$el.querySelector('#select_all_checkbox');
        selectAllCheckBox.checked = value
      },
      removeSelectedMembers() {
        this.showProgressBar = true;
        this.progressBarTarget = '.remove-member';
        this.confirmationMessage = null;
        let selectedMembersLogin = Object.values(this.members).filter((user) => user.selected).map((user) => user.login);
        this.$store.dispatch('removeMembers', selectedMembersLogin).then((result) => {
          if (result.success) {
            this.message = {type: 'success', text: result.message};
            this.disableBulkActions = true;
            this.members = this.getProgramMembers();
          } else
            this.message = {type: 'error', text: result.error};
          this.showProgressBar = false;
          this.resetSelectAll();
        });
      },
      openAddMemberPopUp() {
        this.$modal.show('add-member-pop-up');
        this.$store.dispatch('fetchUsers');
      },
      showConfirmationBox() {
        if (this.selectedMembersCount() === 1) {
          this.confirmationMessage = "Are you sure you want to remove the selected member from the program?";
          this.confirmationTitle = "Remove Program Member";
        }
        else {
          this.confirmationMessage = "Are you sure you want to remove the selected members from the program?";
          this.confirmationTitle = "Remove Program Members";
        }
        this.$modal.show("confirm-delete");
      },
      selectedMembersMessage() {
        let selectedMembersCount = this.selectedMembersCount();
        if (selectedMembersCount === 1)
          return 'One member selected.';
        return `${selectedMembersCount} members selected.`;
      },
      areAllMembersSelected() {
        return !Object.values(this.members).some((member) => Boolean(member.selected) === false);
      },
      updateMessage(message) {
        this.members = this.getProgramMembers();
        this.message = message;
      },
      roleChanged(login) {
        return (event) => {
          if (!event || event.id === this.members[login].role.id) return;
          let membersInfo = {logins: [login], role: {id: event.id, name: event.name}};
          this.changeMembersRole(membersInfo).then((response)=>{
            if(response.success) {
              this.lastUpdatedMember.login = login;
              this.reassignProgramMembers();
            }
          });
        }
      },
      isAuthorizedToChangeRole(login) {
        let currentUser = this.$store.state.currentUser;
        return currentUser.mingleAdmin || (currentUser.admin && currentUser.login !== login)
      },
      updateRoles(role) {
        let selectedMembersLogin = [];
        Object.values(this.members).forEach((member) => {
          if (member.selected && this.isAuthorizedToChangeRole(member.login) && member.activated)
            selectedMembersLogin.push(member.login)
        });
        if (selectedMembersLogin.length > 0) {
          this.showProgressBar = true;
          this.progressBarTarget = '.change-member-role .drop-down-toggle';
          this.changeMembersRole({logins: selectedMembersLogin,role: {id: role.id, name: role.name} }).then((response) => {
            this.showProgressBar = false;
            if (response.success) {
              this.message = {type: 'success', text: response.message};
              this.disableBulkActions = true;
              this.unSelectAll();
            } else {
              this.message = {type: 'error', text: response.message};
            }
          });
        }
      },

      changeMembersRole(membersInfo) {
        this.lastUpdatedMember = {};
        return new Promise((resolver) => {
          this.$store.dispatch('bulkUpdate', membersInfo).then(resolver);
        });
      },
      unSelectAll() {
        this.displaySelectAllMembersLink = false;
        for (let key in this.members)
          this.select(this.members[key], false);
        this.reassignProgramMembers();
        this.setSelectAllTo(false);
      }
    },
    computed: {
      programMembers() {
        return Object.values(this.members);
      },
      showAddTeamMemberButton() {
        return this.$store.state.currentUser.admin && this.$store.state.toggles.addTeamMemberEnabled
      },
      isBulkActionsEnabled() {
        return this.disableBulkActions
      },
      shouldDisplaySelectAllMembersLink() {
        return this.displaySelectAllMembersLink && !this.areAllMembersSelected()
      }
    }
  }

</script>
<style lang="scss" scoped>
  .program-team {
    .program-team-header h1 {
      margin: 10px 0 0 0;
    }
    .actions {
      position: absolute;
      margin-top: 20px;
      .messages {
        height: 20px;
        .select-all-team-members {
          text-decoration: underline;
          cursor: pointer;
        }
      }
    }
    .confirmation-actions {
      width: 160px;
      button {
        float: right;
      }
    }

  }
</style>

<style lang="scss">

  span.projects-truncation {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 230px;
    display: block;
  }

  table.vue-table {
    border: 1px solid #DDD;
    border-collapse: collapse;
    box-shadow: 0 5px 5px rgba(0, 0, 0, 0.25);
    -moz-box-shadow: 0 5px 5px rgba(0, 0, 0, 0.25);
    -webkit-box-shadow: 0 5px 5px rgba(0, 0, 0, 0.25);
    margin: 0;
    width: 100%;
  }

  .VueTables__table.vue-table {
    thead th {
      background: #d2eff9;
      text-align: left;
    }
    tbody tr {
      td{
        vertical-align: middle;
        &:nth-child(4) {
          width: 230px;
        }
        &:nth-child(5) {
          width: 205px;
        }
      }
    }

    tbody tr.deactive td{
      color: #888;
      .v-select .dropdown-toggle{
        pointer-events: none;
        background-image: none;
        background-color: white;
        border-color: white;
        span.selected-tag{
          color: #888;
        }
        input {
          background-color: white;
        }
        .open-indicator {
          display: none;
        }
      }
    }
  }

  .filters {
    .search-container {
      margin-bottom: 10px;
      float: right;
      .VueTables__search-field {
        margin-right: 5px;
        float: left;
      }
      .vue-table-search-icon.fa.fa-search {
        margin-top: 5px;
      }
    }
  }

  .VueTables__sort-icon.fas {
    margin-left: 5px;
    font-family: 'FontAwesome';
    cursor: pointer;
  }

  .VueTables__sort-icon.sort-alpha-down:after {
    content: "\f0dd";
  }

  .VueTables__sort-icon.sort-alpha-up:after {
    content: "\f0de";
  }

  .VuePagination.filters.search-container.justify-content-center {
    display: inline-block;
    width: 100%;
    height: 38px;
    .pagination {
      margin: 10px -10px
    }
  }

  .VuePagination {
    ul {
      white-space: nowrap;
      li {
        display: inline;
      }
    }
    .VuePagination__pagination {
      float: right;

    }
    p.VuePagination__count.text-center.search-container {
      margin: 10px;
      line-height: 20px;
    }
  }

  .page-link.active {
    color: #FFF;
    font-weight: normal;
    background-color: #999;
    pointer-events: none;
  }

  .VuePagination__pagination-item-next-page.disabled,
  .VuePagination__pagination-item-prev-page.disabled {
    pointer-events: none;
  }

  .VuePagination__pagination-item-next-page.disabled, .VuePagination__pagination-item-prev-page.disabled {
    pointer-events: none;
  }

  .tooltip-style-message.left-center-arrow {
    .messages-box {
      height: 25px !important;
      padding: 0 !important;
    }
  }

  .change-member-role {
    display: inline-block;
    button.drop-down-toggle{
      padding: 0 10px;
      &:before{
        content: "\f040";
        font-family: FontAwesome;
      }
    }
    button{
      width: 137px;
    }
  }
  .members-role-drop-down{
    .dropdown-toggle{
      border-radius: 0;
      border-color: rgb(204,204,204);
      input{
        width: 1px !important;
      }
    }
  }
  .role-updated{
    display: flex;
    &:after{
      content:'\f00c';
      font-family: FontAwesome;
      color: green;
      margin-top: 4%;
      margin-left: 10px;
      font-size: 15px;
    }
  }

</style>