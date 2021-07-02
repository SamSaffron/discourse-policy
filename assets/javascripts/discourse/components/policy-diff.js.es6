import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "",
  isLoading: false,
  postId: null,
  diff: null,
  date: null,
  username: null,
  avatarTemplate: null,

  didInsertElement() {
    this._super(...arguments);

    this._loadDiff();
  },

  _loadDiff() {
    this.set("isLoading", true);

    ajax(`/posts/${this.postId}/revisions/latest.json`)
      .then((diff) => {
        this.set("username", diff?.username);
        this.set("avatarTemplate", diff?.avatar_template);
        this.set("date", moment(diff?.created_at).format("LL"));
        this.set("diff", diff?.body_changes?.inline);
      })
      .finally(() => {
        this.set("isLoading", false);
      });
  },
});
