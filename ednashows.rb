#!/usr/bin/ruby
require 'addressable/uri'
require 'open-uri'
require 'nokogiri'
require 'yaml'
require 'fileutils'

Show = Struct.new(:name, :url)

def load_shows(url)
  doc = Nokogiri::HTML(open("http://www.edna.cz#{url}"))
  shows = doc.css('ul.serieslist li .text-box h3 a').map do |link|
    puts link.content
    m = /(.*)\s\(.*\)/.match(link.content)
    Show.new(m.nil? ? link.content : m[1], link.attribute('href').content)
  end
  n = doc.css("a.btn-next").first.attribute('href')
  if(n.nil?)
    shows
  else
    shows + load_shows(n.content)
  end
end

path = File.join(Dir.home, '.config', 'ednasubs')
FileUtils::mkdir_p path
File.open(File.join(path, 'shows.yaml'), 'w') do |f|
  f.write load_shows("/serialy").to_yaml
end

