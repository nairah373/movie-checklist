class MoviesController < ApplicationController
  before_action :set_movie, only: [:toggle, :destroy]

  def index
    @filter  = params[:filter].presence_in(%w[all watched towatch]) || "all"
    @movies  = Movie.for_filter(@filter)
    @counts  = movie_counts
  end

  def create
    @movie = Movie.new(movie_params)
    if @movie.save
      respond_to do |format|
        format.turbo_stream { render_after_change(prepend: @movie) }
        format.html { redirect_to root_path }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "modal",
            partial: "movies/modal",
            locals: { movie: @movie, open: true }
          )
        end
        format.html { redirect_to root_path }
      end
    end
  end

  def toggle
    @movie.toggle_watched!
    respond_to do |format|
      format.turbo_stream { render_after_change(replace: @movie) }
      format.html { redirect_to root_path }
    end
  end

  def destroy
    @movie.destroy
    respond_to do |format|
      format.turbo_stream { render_after_change(remove: @movie) }
      format.html { redirect_to root_path }
    end
  end

  def seed
    Movie.seed_sample! if Movie.count.zero?
    redirect_to root_path
  end

  def clear
    Movie.destroy_all
    redirect_to root_path
  end

  private

  def set_movie
    @movie = Movie.find(params[:id])
  end

  def movie_params
    params.expect(movie: [:title, :year, :genre, :poster_url])
  end

  def render_after_change(prepend: nil, replace: nil, remove: nil)
    @filter = params[:filter].presence_in(%w[all watched towatch]) || "all"
    streams = []

    if remove
      streams << turbo_stream.remove(remove)
    elsif replace
      streams << turbo_stream.replace(replace, partial: "movies/movie", locals: { movie: replace })
    elsif prepend
      should_show = (@filter == "all") || (@filter == "watched" && prepend.watched) || (@filter == "towatch" && !prepend.watched)
      if should_show
        streams << turbo_stream.prepend("grid", partial: "movies/movie", locals: { movie: prepend })
        streams << turbo_stream.remove("empty-state")
      end
      streams << turbo_stream.replace("modal", partial: "movies/modal", locals: { movie: Movie.new, open: false })
    end

    streams << turbo_stream.replace("stats",   partial: "movies/stats",   locals: { counts: movie_counts })
    streams << turbo_stream.replace("filters", partial: "movies/filters", locals: { filter: @filter, counts: movie_counts })

    render turbo_stream: streams
  end

  def movie_counts
    total   = Movie.count
    watched = Movie.watched.count
    { total: total, watched: watched, towatch: total - watched }
  end
end
