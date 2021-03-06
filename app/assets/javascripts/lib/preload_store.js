HB.PreloadStore = {
  get: function(key, fetch) {
    if (typeof window.genericPreload[key] !== "undefined") {
      return window.genericPreload[key];
    } else if (typeof fetch !== "undefined") {
      return fetch();
    }
  },

  pop: function(key, fetch) {
    var value = HB.PreloadStore.get(key, fetch);
    delete window.genericPreload[key];
    return value;
  },

  popEmberData: function(key, path, object, store, edQuery) {
    var data = HB.PreloadStore.pop(key);
    if (typeof data === "undefined" || data === null) {
      if (typeof edQuery !== "undefined") {
        return edQuery();
      } else {
        return null;
      }
    }
    store.pushPayload(data);
    var ids = data[path].map(function(x) { return x.id; });
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return resolve(store.findByIds(object, ids));
    });
  }
};
