_ = require 'lodash'
async = require 'async'
cheerio = require 'cheerio'
fs = require 'fs'
request = require 'request'
camelcase = require 'camelcase'

albumsUrl = (bandUrl) ->
  parts = bandUrl.split '/'
  id = parts[parts.length - 1]
  "http://www.metal-archives.com/band/discography/id/#{id}/tab/all"

labelToName = (label) ->
  camelcase label.replace ':', ''

loadPage = (url, cb) ->
  request url, (err, res, html) ->
    return cb err if err
    cb null, cheerio.load html

getAlbumReviews = (album, cb) ->
  return cb null unless album.reviewsUrl
  loadPage album.reviewsUrl, (err, $) ->
    return cb err if err
    album.reviews = $('.reviewBox').map ->
      authorAndDate = $(@).find('.reviewTitle + div')
      titleParts = $(@).find('.reviewTitle').text().trim().split ' - '
      score: titleParts[titleParts.length - 1]
      reviewTitle: titleParts.slice(0, titleParts.length - 1).join ' - '
      reviewContent: $(@).find('.reviewContent').html()
      authorUrl: authorAndDate.find('a').attr 'href'
      authorName: authorAndDate.find('a').text()
      date: authorAndDate.text().trim().split(',').slice(1, 3).join(',').trim()
    .toArray()
    cb null

fillAlbumPage = (album, cb) ->
  return cb null unless album.albumUrl
  loadPage album.albumUrl, (err, $) ->
    return cb err if err
    album.albumPage =
      albumInfo: zipDtDds $, '#album_info dt', '#album_info dd'
      cover:
        imageUrl: $('#cover').attr 'href'
    cb null

fillInAlbums = (bandInfo, cb) ->
  loadPage albumsUrl(bandInfo.url), (err, $) ->
    return cb err if err
    labels = $('table thead th').map(-> labelToName $(@).text()).toArray()
    bandInfo.albums = $('table tbody tr').map ->
      domCells = $(@).find 'td'
      cells = domCells.map(-> $(@).text().trim()).toArray()
      album =
        albumUrl: domCells.eq(0).find('a').attr 'href'
        reviewsUrl: domCells.eq(-1).find('a').attr 'href'
        tableInfo: {}
      for i in [0...labels.length]
        album.tableInfo[labels[i]] = cells[i]
      album
    .toArray()

    async.map bandInfo.albums, getAlbumReviews, (err) ->
      return cb err if err
      async.map bandInfo.albums, fillAlbumPage, (err) ->
        return cb err if err
        cb null

zipDtDds = ($, sel1, sel2) ->
  labels = $(sel1).map(-> $(@).text().trim()).toArray()
  values = $(sel2).map(-> $(@).text().trim()).toArray()
  bandStats = {}
  for i in [0...labels.length]
    bandStats[labelToName labels[i]] = values[i]
  bandStats

getBandPageInfo = (url, cb) ->
  loadPage url, (err, $) ->
    return cb err if err

    cb null,
      url: url
      name: $('.band_name a').text()
      bandStats: zipDtDds $, '#band_stats dt', '#band_stats dd'
      logoUrl: $('#logo').attr 'href'
      bandPhotoUrl: $('#photo').attr 'href'

getBandInfo = (url, cb) ->
  getBandPageInfo url, (err, bandInfo) ->
    return cb err if err
    fillInAlbums bandInfo, (err) ->
      cb null, bandInfo

main = (cb) ->
  jsonFile =  __dirname + '/../data/urls.json'
  fs.readFile jsonFile, (err, file) ->
    return cb err if err
    json = JSON.parse file
    url1 = 'http://www.metal-archives.com/bands/Nightwish/39'
    getBandInfo url1, (err, info) ->
      console.log JSON.stringify info, null, 2

main (err) ->
  throw err if err
