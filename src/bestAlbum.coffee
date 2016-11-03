async = require 'async'
fs = require 'fs'

min_reviews = 7
drop_difference = 70

aggScores = (scores) ->
  avg = mean scores
  scores = scores.filter (x) ->
    Math.abs(x - avg) < drop_difference
  return -1 if scores.length < min_reviews
  mean scores

mean = (xs) ->
  xs.reduce(((a, b) -> a + b), 0) / xs.length

getBandAlbums = (bandHash, cb) ->
  fs.readFile __dirname + '/../bands/' + bandHash, (err, file) ->
    return cb err if err
    band = JSON.parse file
    albums = []
    for album in band.albums or []
      continue unless album.reviews
      score = aggScores (parseInt(x.score) for x in album.reviews)
      continue unless score >= 0
      albums.push
        band: band.name
        name: album.tableInfo.name
        year: album.tableInfo.year
        score: score
    cb null, albums

main = (cb) ->
  fs.readdir __dirname + '/../bands', (err, bandsHashes) ->
    return cb err if err
    all = []
    pushAlbums = (band, cb) ->
      getBandAlbums band, (err, albums) ->
        return cb err if err
        all.push.apply all, albums
        cb null
    async.eachSeries bandsHashes, pushAlbums, (err) ->
      return cb err if err
      all.sort (a, b) -> b.score - a.score
      console.log all.length
      out = JSON.stringify all, null, 2
      fs.writeFile __dirname + '/../data/topAlbums.json', out, cb

main (err) ->
  throw err if err
