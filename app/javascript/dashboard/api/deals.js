/* global axios */
import ApiClient from './ApiClient';

class DealAPI extends ApiClient {
  constructor() {
    super('deals', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, payload);
  }

  update(id, payload) {
    return axios.put(`${this.url}/${id}`, payload);
  }

  destroy(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new DealAPI();
