#!/usr/bin/ruby
require 'addressable/uri'
require 'open-uri'
require 'nokogiri'
require 'to_name'
require 'similar_text'
require 'pathname'
require 'yaml'

Show = Struct.new(:name, :url)
Similarity = Struct.new(:show, :similarity)
Episode = Struct.new(:name, :subs)
Release = Struct.new(:name, :url)

def load_url(url)
  uri = Addressable::URI.parse(url)
  http = Net::HTTP.new(uri.host)
  http.request_get(uri.path) do |response|
    return response.read_body
  end
end

def load_shows()
  YAML::load_file(File.join(Dir.home(), ".config", "ednasubs", "shows.yaml"))
end

def find_show(shows, info)
  best = shows.map { |show|
    Similarity.new(show, show.name.similar(info.name))
  }. max_by { |item| item.similarity}
  if(best.similarity >= 80)
    best.show
  else
    nil
  end
end

def load_episodes(show, season)
  doc = Nokogiri::HTML(open("http://www.edna.cz#{show.url}titulky/?season=#{season}"))
  doc.css('.episodes tbody tr').map do |rows|
    name = rows.css('h3 a').first.content
    subs = rows.css('a.flag').map do |link|
      url = link.attribute('href').content
      lang = link.css('i').first.content
      [lang, url]
    end
    Episode.new(name, subs.to_h)
  end
end

def find_episode(episodes, info)
  episodes.find do |episode|
    episode.name.start_with?("S#{info.series.to_s.rjust(2,"0")}E#{info.episode.to_s.rjust(2,"0")}")
  end
end


def filter_supported(episodes)
  episodes.each do |episode|
    episode.subs = episode.subs.select do |lang, url|
      u = Addressable::URI.parse(url)
      url.start_with?("/") || u.host == 'www.edna.cz' || u.host == 'cwzone.cz'
    end
  end
end

def load_releases(episode, lang)
  def load_edna(url)
    doc = Nokogiri::HTML(open(url))
    results = doc.css('ul.bullets li a').select {|link| link.attribute('href').content.include?('&file=')}.map do |link|
      Release.new(link.content, "http://www.edna.cz#{link.attribute('href').content}")
    end
    if results.empty?
      doc.css('div.content-inner a').map do |link|
        Release.new("Neznámá verze", "http://www.edna.cz#{link.attribute('href').content}")
      end
    else
      results
    end
  end

  def load_cwzone(url)
    doc = Nokogiri::HTML(open(url))
    doc.css('.stahnout a').map do |link|
      Release.new(link.content, "http://cwzone.cz#{link.attribute('href').content}")
    end
  end

  def load_titulky(url)
    doc = Nokogiri::HTML(open(url))
    doc
  end

  link = episode.subs[lang]
  if !link.nil?
    if link.start_with?('/')
      load_edna("http://www.edna.cz#{link}")
    elsif Addressable::URI.parse(link).host == "cwzone.cz"
      load_cwzone(link)
    else
      exec("gnome-open \"#{link}\"")
    end
  end
end

def find_release(releases, filename)
  name = File.basename(filename, ".*")
  releases.find do |release|
    File.basename(release.name, ".srt").include?(name)
  end
end

def download_release(release, destination)
  File.open(destination, 'wb') do |file|
    open(release.url, "rb") do |content|
      file.write(content.read)
    end
  end
end

def make_destination(filename)
  basename = "#{File.basename(filename,".*")}.srt"
  pn = Pathname.new(filename)
  (pn.dirname + basename).to_path
end

def show_error_and_exit(err)
  if true
    exec("zenity --error --text='#{err}'")
  else
    puts err
    exit
  end
end

def show_info_and_exit(info)
  if true

    exec("zenity --info --text='#{info}'")
  else
    puts info
    exit
  end
end

def cli_select(releases)
  def read_option(size)
    print "Vyberte verzi: "
    value = $stdin.readline.to_i
    if(value < size)
      value
    else
      puts "Spatne cislo."
      read_option(size)
    end
  end

  releases.each_with_index do |release, index|
    puts "[#{index}] #{File.basename(release.name, ".srt")}"
  end
  releases[read_option(releases.size)]
end

def gui_select(releases)
  options = releases.each_with_index.map do |release, index|
    "#{index} '#{File.basename(release.name, ".srt")}'"
  end
  command = "zenity --list --radiolist --width 550 --height 300 --title 'Vyberte titulky ke stáhnutí' --column='Volba' --column='Verze' #{options.join(" ")}"
  result = `#{command}`.strip
  release = releases.find do |release|
    File.basename(release.name, ".srt") == result
  end
  if(release.nil?)
    exit
  end
  release
end

filename = ARGV[0]
info = ToName.to_name(filename)
hasGui = true
if(info.series.nil? || info.episode.nil?)
  show_error_and_exit "Chybí číslo série/epizody."
end

shows = load_shows()
show = find_show(shows, info)
if(show.nil?)
  show_error_and_exit "Neznámé jméno seriálu."
end

episodes = load_episodes(show, info.series)
episode = find_episode(filter_supported(episodes), info)
if(episode.nil?)
  show_error_and_exit "Neznámé číslo epizody."
end

releases = load_releases(episode,"cz")
if(releases.nil?)
  show_error_and_exit "Žádné dostupné titulky."
end

release = find_release(releases, filename)
if(release.nil?)
   if(hasGui)
     release = gui_select(releases)
   else
     release = cli_select(releases)
   end
end

download_release(release, make_destination(filename))

show_info_and_exit "Úspěšně staženo!"

