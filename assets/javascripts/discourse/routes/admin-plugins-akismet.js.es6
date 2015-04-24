export default Discourse.Route.extend({
  model() {
    return this.store.find('akismet-stat');
  }
});
