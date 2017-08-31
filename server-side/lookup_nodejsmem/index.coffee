




node_mem_arq = {}


build_selection = {}


build_selection['BK-tree'] = require('./bk-tree.coffee').default

build_selection['prefix-tree'] = Bluebird.promisify ({ payload }, cb) ->
    c '222'

keys_build_selection = _.keys build_selection


nodemem_api = {}



# TODO :
# 0. Implement this into another thread childprocess
# 1. signals to abort, results saved refs in some data structure
#


nodemem_api['search_struct'] = Bluebird.promisify ({ payload }, cb) ->
    c payload, 'payload'
    { struct_key, query_expr } = payload

    c "#{color.green('here', on)}"



    cb null, { nothing_yet: 42 }



nodemem_api['build_selection'] = Bluebird.promisify ({ type, payload }, cb) ->
    { data_struct_type_select, dctn_hash } = payload
    if _.includes(keys_build_selection, data_struct_type_select)
        build_selection[data_struct_type_select] { blob: dctn_hash.as_blob }
        .then ({ payload }) ->
            node_mem_arq[data_struct_type_select] = payload.built_struct
            cb null, { payload }




keys_nodemem_api = _.keys nodemem_api


nodemem_api_fncn = Bluebird.promisify ({ type, payload }, cb) ->
    if _.includes(keys_nodemem_api, type)
        nodemem_api[type] { payload }
        .then ({ payload }) -> # is this a code smell ?  two payloads one overwriting the other ?
        # i think it is but it would be worse to have awkward names for the response, ...
            c '88888888'
            cb null, { payload }
    else
        c "#{color.yellow('no-op in nodemem_apip.', on)}"






exports.default = nodemem_api_fncn
