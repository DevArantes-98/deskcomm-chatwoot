/* global axios */
import ApiClient from './ApiClient';

class WhatsappGroupsAPI extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  create({ inboxId, name, contactIds }) {
    return axios.post(`${this.baseUrl()}/whatsapp_groups`, {
      inbox_id: inboxId,
      name,
      contact_ids: contactIds,
    });
  }

  show(conversationId) {
    return axios.get(`${this.url}/${conversationId}/group`);
  }

  inviteLink(conversationId) {
    return axios.get(`${this.url}/${conversationId}/group/invite_link`);
  }

  addParticipants(conversationId, contactIds) {
    return axios.post(`${this.url}/${conversationId}/group/add_participants`, {
      contact_ids: contactIds,
    });
  }

  removeParticipants(conversationId, participants) {
    return axios.post(
      `${this.url}/${conversationId}/group/remove_participants`,
      { participants }
    );
  }
}

export default new WhatsappGroupsAPI();
