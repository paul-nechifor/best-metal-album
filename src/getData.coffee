async = require 'async'
cheerio = require 'cheerio'
fs = require 'fs'
request = require 'request'

website = 'http://www.metal-archives.com/browse/letter'

loadPage = (url, cb) ->
  request url, (err, res, html) ->
    return cb err if err
    cb null, cheerio.load html

getLetterUrls = (cb) ->
  loadPage website, (err, $) ->
    letters = $ '#letterMenu > ul > li > a'
    .map ->
      parts = $(@).attr('href').split('/')
      parts[parts.length - 1]
    .toArray()
    cb null, letters

positionUrl = (letter, start) ->
  "http://www.metal-archives.com/browse/ajax-letter/l/#{letter}/json/1?sEcho=1&iColumns=4&sColumns=&iDisplayStart=#{start}&iDisplayLength=500&mDataProp_0=0&mDataProp_1=1&mDataProp_2=2&mDataProp_3=3&iSortCol_0=0&sSortDir_0=asc&iSortingCols=1&bSortable_0=true&bSortable_1=true&bSortable_2=true&bSortable_3=false&_=1477507478903"

urlsFromListing = (records) ->
  records.map (x) -> x[0].split("'")[1]

letterOffsetJson = (parts, cb) ->
  [letter, offset] = parts
  request positionUrl(letter, offset), (err, res, json) ->
    return cb err if err
    cb null, JSON.parse json

letterOffsetUrls = (parts, cb) ->
  letterOffsetJson parts, (err, json) ->
    return cb err if err
    cb null, urlsFromListing json.aaData

getBandUrlsForLetter = (letter, cb) ->
  letterOffsetJson [letter, 0], (err, json) ->
    return cb err if err
    total = json.iTotalDisplayRecords
    ranges = ([letter, x] for x in [500...total] by 500)
    initialUrls = urlsFromListing json.aaData

    async.map ranges, letterOffsetUrls, (err, urlses) ->
      urlses.forEach (urls) ->
        initialUrls.push.apply initialUrls, urls
      cb null, initialUrls

getAllBandUrls = (cb) ->
  getLetterUrls (err, letters) ->
    return cb err if err
    urls = []
    async.map letters, getBandUrlsForLetter, (err, urlses) ->
      urlses.forEach (us) ->
        urls.push.apply urls, us
      cb null, urls

main = (cb) ->
  getAllBandUrls (err, urls) ->
    return cb err if err
    jsonFile =  __dirname + '/../data/urls.json'
    fs.writeFile jsonFile, JSON.stringify(urls), (err) ->
      return cb err if err
      cb null

main (err) ->
  throw err if err
