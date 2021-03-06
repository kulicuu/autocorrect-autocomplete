

c = console.log.bind console
color = require 'bash-color'
_ = require 'lodash'
fp = require 'lodash/fp'
flow = require 'async'

Bluebird = require 'bluebird'

Redis = require 'redis'
Bluebird.promisifyAll(Redis.RedisClient.prototype)
Bluebird.promisifyAll(Redis.Multi.prototype)
redis = Redis.createClient
    port: 6464


send_match = ({ match_set, job_id }) ->
    c 'job_id in send_match', job_id
    process.send
        type: 'match_report'
        payload: { match_set, job_id }


send_progress = ({ perc_count, job_id }) ->
    process.send
        type: 'progress_update'
        payload:
            perc_count: perc_count
            job_id: job_id


api = {}


prefix_trees = {}


naive_cache_it = ({ prefix_tree, job_id }) ->
    the_str = JSON.stringify prefix_tree
    redis.hsetAsync 'prefix_tree_naive_cache', job_id, the_str
    .then (re) ->
        c "#{color.green('re on naive_cache_it redis call', on)} #{re}"


break_ties = ({ candides }) ->
    # for now will just return the first,
    # but later can implement the logic for lexicographic order
    candides[0]


map_prefix_to_match = ({ dictionary, prefix }) ->
    candides = []
    for word in dictionary
        if word.indexOf(prefix) is 0
            candides.push word
    if candides.length > 1
        return break_ties { candides }
    else
        return candides.pop()


reduce_tree = (acc, tree) ->
    if acc.indexOf(tree.match_word) is -1
        acc = [].concat(acc, tree.match_word)
    _.reduce tree.chd_nodes, (acc2, node, prefix) ->
        reduce_tree acc2, node
    , acc


api.get_tree = (payload) ->
    { tree_id, job_id } = payload
    prefix_tree = prefix_trees[_.keys(prefix_trees)[0]] # for now just get the first available
    process.send
        type: 'prefix_tree_blob'
        payload:
            string_tree: JSON.stringify(prefix_tree)
            job_id: job_id
            tree_id: tree_id


api.search_prefix_tree = (payload) ->
    { prefix, job_id } = payload
    if prefix.length is 0
        send_match
            job_id: job_id
            match_set: []
    else
        cursor = prefix_trees[_.keys(prefix_trees)[0]]
        canceled = false
        if cursor isnt undefined
            prefix_rayy = prefix.split ''
            for char in prefix_rayy
                if cursor.chd_nodes[char] isnt undefined
                    cursor = cursor.chd_nodes[char]
                else
                    canceled = true
                    send_match
                        job_id: job_id
                        match_set: []
            if canceled is false
                send_match
                    job_id: job_id
                    match_set: reduce_tree([], cursor)


api.build_tree = (payload) ->
    counter = 0
    { dctn_blob, job_id, tree_id } = payload
    raw_rayy = dctn_blob.split '\n'
    len_raw_rayy = raw_rayy.length
    perc_count = len_raw_rayy / 100
    tree =
        chd_nodes: {}
        prefix: ''
    for word, idx in raw_rayy
        c "#{color.green(word, on)}"
        cursor = tree
        prefix = ''
        unless word.length < 1
            counter++
            perc = counter / perc_count
            if Math.floor(counter % perc_count) is 0
                send_progress
                    perc_count: Math.floor perc
                    job_id: job_id
                    tree_id: tree_id
            for char, jdx in word
                prefix+= char
                if not _.includes(_.keys(cursor.chd_nodes), char)
                    cursor.chd_nodes[char] =
                        match_word: map_prefix_to_match
                            prefix: prefix
                            dictionary: raw_rayy
                        prefix: prefix
                        chd_nodes: {}
                cursor = cursor.chd_nodes[char]
    prefix_trees[tree_id] = tree
    c "#{color.yellow('should be done now', on)}"
    send_progress
        perc_count: 100
        job_id: job_id
        tree_id: tree_id


keys_api = _.keys api


process.on 'message', ({ type, payload }) ->
    if _.includes(keys_api, type)
        api[type] payload
    else
        c "#{color.yellow('No-Op in worker_prefix_tree with :', on)} #{color.white(type, on)}"






# --------------------------------------------

# search_prefix_tree__ = ({ prefix_tree, prefix }) ->
#     cursor = prefix_tree
#     prefix_rayy = prefix.split ''
#     c prefix, color.blue('prefix', on)
#     for char in prefix_rayy
#         cursor = cursor.chd_nodes[char]
#         if cursor is undefined
#             return 'Not found.'
#     _.omit cursor, 'chd_nodes'
