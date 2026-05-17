require "net/http"
require "uri"

class Movie < ApplicationRecord
  POSTER_COLORS = %w[
    #7C2D12 #1C1917 #7F1D1D #0E7490 #365314 #854D0E
    #581C87 #0F172A #9F1239 #0C4A6E #134E4A #3B0764
  ].freeze

  PINTEREST_HOSTS = /\A(?:[a-z]{2}\.)?pinterest\.(?:com|co\.uk|ca|fr|de|jp|in|com\.au)\z/i
  PIN_IT_HOST     = /\Apin\.it\z/i
  USER_AGENT      = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

  SAMPLE_FILMS = [
    { title: "Parasite",                 year: 2019, genre: "Thriller",  watched: true,  color: "#7C2D12" },
    { title: "The Grand Budapest Hotel", year: 2014, genre: "Comedy",    watched: true,  color: "#9F1239" },
    { title: "In the Mood for Love",     year: 2000, genre: "Romance",   watched: false, color: "#7F1D1D" },
    { title: "Spirited Away",            year: 2001, genre: "Animation", watched: true,  color: "#0E7490" },
    { title: "Past Lives",               year: 2023, genre: "Drama",     watched: false, color: "#365314" },
    { title: "2001: A Space Odyssey",    year: 1968, genre: "Sci-Fi",    watched: false, color: "#0F172A" }
  ].freeze

  validates :title, presence: true

  before_validation :assign_color,         on: :create
  before_validation :resolve_pinterest_url, if: :pinterest_page_url?

  scope :watched,  -> { where(watched: true) }
  scope :to_watch, -> { where(watched: false) }
  scope :ordered,  -> { order(watched: :asc, created_at: :desc) }

  def self.for_filter(filter)
    case filter
    when "watched" then watched.ordered
    when "towatch" then to_watch.ordered
    else                ordered
    end
  end

  def self.seed_sample!
    SAMPLE_FILMS.each { |attrs| create!(attrs) }
  end

  def toggle_watched!
    update!(watched: !watched)
  end

  private

  def assign_color
    self.color ||= POSTER_COLORS.sample
  end

  def pinterest_page_url?
    return false if poster_url.blank?
    return false unless poster_url_changed?
    uri = URI.parse(poster_url) rescue nil
    return false unless uri&.host
    uri.host.match?(PINTEREST_HOSTS) || uri.host.match?(PIN_IT_HOST)
  end

  def resolve_pinterest_url
    direct = Movie.fetch_pinterest_image(poster_url)
    self.poster_url = direct if direct.present?
  end

  def self.fetch_pinterest_image(url, redirects_left: 3)
    return nil if redirects_left <= 0
    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                               open_timeout: 4, read_timeout: 6) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = USER_AGENT
      req["Accept"]     = "text/html,application/xhtml+xml"
      http.request(req)
    end

    case response
    when Net::HTTPRedirection
      next_url = URI.join(url, response["location"]).to_s
      fetch_pinterest_image(next_url, redirects_left: redirects_left - 1)
    when Net::HTTPSuccess
      extract_image_url(response.body)
    end
  rescue StandardError => e
    Rails.logger.warn("Pinterest resolve failed for #{url}: #{e.class}: #{e.message}")
    nil
  end

  def self.extract_image_url(html)
    return nil if html.blank?
    [
      /<meta[^>]+property=["']og:image:secure_url["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
      /"image_url"\s*:\s*"([^"]+\.(?:jpg|jpeg|png|webp)[^"]*)"/i
    ].each do |re|
      m = html.match(re)
      return CGI.unescapeHTML(m[1]) if m
    end
    nil
  end
end
