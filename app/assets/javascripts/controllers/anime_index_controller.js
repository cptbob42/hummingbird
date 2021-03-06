HB.AnimeIndexController = Ember.ObjectController.extend(HB.HasCurrentUser, {
  showEpisodes: function() {
    return this.get('currentUser.isAdmin') && this.get('model.episodes.length')>0;
  }.property('currentUser.isAdmin', 'model.episodes.length'),

  // TODO This should start at either episode 1 or the most recent episode the
  // user has seen.
  episodesPreview: function() {
    if (this.get('model.episodes.length') > 5) {
      return this.get('model.sortedEpisodes').slice(0, 5);
    } else {
      return this.get('model.sortedEpisodes');
    }
  }.property('model.episodes.@each'),

  // Legacy -- remove after Ember transition is complete.
  newReviewURL: function() {
    return "/anime/" + this.get('model.id') + "/reviews/new";
  }.property('model.id'),
  fullReviewsURL: function () {
    return "/anime/" + this.get('model.id') + "/reviews";
  }.property('model.id'),
  // End Legacy
});
