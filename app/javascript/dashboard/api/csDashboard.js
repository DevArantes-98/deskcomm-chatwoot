/* global axios */
import ApiClient from './ApiClient';

class CsDashboardAPI extends ApiClient {
  constructor() {
    super('cs_dashboard', { accountScoped: true });
  }

  get({ since, until, groupBy, timezoneOffset, inboxId }) {
    return axios.get(this.url, {
      params: {
        since,
        until,
        group_by: groupBy,
        timezone_offset: timezoneOffset,
        inbox_id: inboxId,
      },
    });
  }
}

export default new CsDashboardAPI();
