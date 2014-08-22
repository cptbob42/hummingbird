desc "Bulk import videos from Hulu"
task :bulk_import_hulu => :environment do
  require 'hooloo'
  require 'rubyfish'

  @results = {
    fail: 0
  }
  def import_episodes(anime, show, how=nil, uncertain=false)
    @results[how] = 0 unless @results.has_key?(how)
    @results[how] += 1
    printf "++++ %s ---> %s, %s VIA %s\n", show.name, anime.title, anime.alt_title, how.to_s.upcase if uncertain

    show.videos.each do |video|
      next unless video.video_type == 'episode'
      episode = Episode.create_or_update_from_hash({
        anime: anime,
        episode: video.episode_number,
        season: video.season_number,
        title: video.title.gsub(/^([sd]ub) /i, '').strip,
        synopsis: video.description,
        thumbnail: video.thumbnail_url
      })
      Video.create_or_update_from_hash({
        streamer: @streamer,
        episode: episode,
        url: "http://www.hulu.com/watch/#{video.id}",
        embed_data: { embed_url: video.oembed[:embed_url] }.to_json,
        available_regions: ['US'],
        sub_lang: video.closed_captions.join(',').upcase,
        dub_lang: video.has_captions? ? 'EN' : 'JP'
      })
    end
  end
  def best_magic(options, min_or_max, &block)
    sorted = options.compact.map do |a|
      {
        anime: a,
        sort: [
          block.try(:call, a.title.try(:downcase) || ''),
          block.try(:call, a.alt_title.try(:downcase) || '')
        ].compact.reject{ |a| a.try(:nan?) || false }.send(min_or_max)
      }
    end.sort { |a, b| a[:sort] <=> b[:sort] }
    if min_or_max == :min
      sorted
    else
      sorted.reverse
    end.first
  end

  puts '==> Creating streamer entry'
  @streamer = Streamer.where(
    site_name: 'Hulu'
  ).first_or_create


  puts '==> Loading anime from Hulu'
  anime_genre = Hooloo::Genre.new 'anime'
  i = 0
  shows = []
  loop do
    page = anime_genre.shows(items_per_page: 100, position: i * 100)
    break if page.length == 0
    shows << page
    i += 1
  end
  shows.flatten!
  shows.compact!


  puts '==> Attempting to match %d shows' % shows.length
  success = 0
  failure = 0
  shows.each do |show|
    options = []
    ## Exact Match
    options << anime = Anime.where("lower(title) = :title OR lower(alt_title) = :title",
                                   title: show.name.downcase).first
    next import_episodes(anime, show, :exact) unless anime.nil?

    ## Trigram
    options << anime = Anime.fuzzy_search_by_title(show.name).first
    next import_episodes(anime, show, :trigram, anime.pg_search_rank < 0.75) if !anime.nil? && anime.pg_search_rank > 0.66

    ## Prefix
    options << anime = Anime.where("lower(title) SIMILAR TO :prefix OR lower(alt_title) SIMILAR TO :prefix",
                                   prefix: "#{show.name.downcase}(:| ) %").first
    next import_episodes(anime, show, :prefix, true) unless anime.nil?

    ## Damerau-Levenshtein Distance
    best = best_magic(options, :min) { |title| RubyFish::DamerauLevenshtein.distance(title, show.name.downcase) }
    next import_episodes(best[:anime], show, :levenshtein, best[:sort] > 1) if best[:sort] < 3

    # Longest Common Subsequence
    best = best_magic(options, :max) { |title| RubyFish::LongestSubsequence.distance(title, show.name.downcase).to_f / (title.length + show.name.length) }
    next import_episodes(best[:anime], show, :subsequence, best[:sort] < 0.4) if best[:sort] > 0.33

    printf "---- %s ---> %s\n", show.name, options.compact.map{ |a| [a.title, a.alt_title] }.compact.flatten.join(', ')
  end
  puts "====== Of %d =======" % shows.length
  @results.each do |how, num|
    puts "%s: %d" % [how.to_s, num]
  end
=begin
=end
end