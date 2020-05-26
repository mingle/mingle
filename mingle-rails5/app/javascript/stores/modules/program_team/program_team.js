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
import Vue from 'vue';
export default function createProgramTeam(members, roles, services) {
  return {
    usersFetched:false,
    state: {
      users: [],
      members,
      roles
    },
    mutations: {
      removeMembers(state, usersLogin) {
        usersLogin.forEach((userLogin) => {
          let member = state.members[userLogin];
          if (member) {
            Vue.delete(state.members, userLogin);
            state.users.push({name: member.name, login: member.login, email: member.email});
          }
        });
      },

      updateUsers(state, users) {
         state.users = users.filter((user)=>{
          return !state.members.hasOwnProperty(user.login);
        });
      },

      updateRole(state, userInfo) {
        for (let i = 0; i <= state.users.length - 1; i++) {
          if (state.users[i].login === userInfo.login) {
            state.users[i].role = userInfo.role;
            break;
          }
        }
      },

      addMember(state, newMember) {
        state.users = state.users.filter((user) => {
          return !(user.login === newMember.login);
        });
        Vue.set(state.members, newMember.login, newMember);
      },

      updateProjects(state, userData) {
        for (let i = 0; i <= state.users.length - 1; i++) {
          if (state.users[i].login === userData.userLogin) {
            state.users[i].projects = userData.projects;
            break;
          }
        }
      },

      updateMembersRole(state, membersInfo) {
        membersInfo.logins.forEach((memberLogin) => {
          if (state.members.hasOwnProperty(memberLogin)) {
            state.members[memberLogin].role = membersInfo.role;
          }
        });
      }
    },
    actions: {
      removeMembers(context, usersLogin) {
        return new Promise((resolver) => {
          services['programTeamService'].bulkRemove(usersLogin).then(response => {
            if (response.success) {
              this.commit('removeMembers', usersLogin);
              resolver(response);
            } else {
              console.log('[ERROR]:', response);
              resolver(response);
            }
          });
        });
      },

      fetchUsers(context) {
        if (!this.usersFetched) {
          services['userService'].fetchUsers().then(response => {
            if (response.success) {
              this.usersFetched = true;
              this.commit('updateUsers', response.users);
            } else {
              console.log('[ERROR]:', response);
            }
          })
        }
      },

      addMember(context, userInfo) {
        return new Promise((resolver) => {
          services['programTeamService'].addMember(userInfo.login, userInfo.role).then(response => {
            if (response.success) {
              this.commit('updateRole', response.user);
              this.commit('addMember', response.user);
              resolver({success: true});
            } else {
              console.log('[ERROR]:', response);
              resolver(response);
            }
          });
        });
      },

      fetchProjects(context, userLogin) {
        return new Promise((resolver) => {
          services['userService'].fetchProjects(userLogin).then(response => {
            if (response.success) {
              this.commit('updateProjects', response.data);
              resolver(response.data.projects);
            } else {
              console.log('[ERROR]:', response);
              resolver(response);
            }
          });
        });
      },

      bulkUpdate(context, membersInfo){
        return new Promise((resolver) => {
          services.programTeamService.bulkUpdate(membersInfo.logins, membersInfo.role.id).then(response => {
            if (response.success) {
              this.commit('updateMembersRole', membersInfo);
              resolver({success:true, message:response.message});
            } else {
              console.log('[ERROR]:', response);
              resolver({success:false, message:response.error});
            }
          });
        });
      }
    }
  }
}