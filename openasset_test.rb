require 'bitcoin'
require 'openassets'
require 'net/http'
require 'json'

Bitcoin.network = :regtest
RPCUSER = "alice"
RPCPASSWORD = "alice"
HOST = "localhost"
PORT = 18443

def bitcoinRPC(method,param)
    http = Net::HTTP.new(HOST, PORT)
    request = Net::HTTP::Post.new('/')
    request.basic_auth(RPCUSER,RPCPASSWORD)
    request.content_type = 'application/json'
    request.body = {method: method, params: param, id: 'jsonrpc'}.to_json
    JSON.parse(http.request(request).body)["result"]
end

api = OpenAssets::Api.new({
       network:             'regtest',
       provider:           'bitcoind',
       cache:              'cache.db',
       dust_limit:                200,
       default_fees:              500,
       min_confirmation:            1,
       max_confirmation:      9999999,
       rpc: {
         user:                  'alice',
         password:              'alice',
         schema:               'http',
         port:                  18443,
         host:            'localhost',
         timeout:                  60,
         open_timeout:             60 }
   })

api.provider.list_unspent
api.get_balance

alice_key = Bitcoin::Key.generate
bob_key = Bitcoin::Key.generate
alice_key_priv = alice_key.to_base58
print "alice key " , alice_key_priv, "\n"
bitcoinRPC('importprivkey',[alice_key_priv])
api.provider.import_privkey(alice_key_priv)

aa = bitcoinRPC('generatetoaddress',[80, alice_key.addr] )
bb = bitcoinRPC('generatetoaddress',[40, bob_key.addr] )
cc = bitcoinRPC('sendtoaddress',[alice_key.addr, 80] )

include ::OpenAssets::Util

alice_oa_addr = address_to_oa_address(alice_key.addr)
bob_oa_addr = address_to_oa_address(bob_key.addr)

aa = bitcoinRPC('generatetoaddress',[80, alice_oa_addr] )

# api.issue_asset(<issuer open asset address>,
#                 <issuing asset quantity>,
#                 <metadata>,
#                 <to open asset address>,
#                 <fees (The fess in satoshis for the transaction. use 10000 satoshi if specified nil)>,
#                 <mode=('broadcast', 'signed', 'unsigned')>,
#                 <output_qty default value is 1.>)

tx = api.issue_asset(alice_oa_addr, 150, 'AGHhobo7pVQN5fZWqv3rhdc324ryT7qVTB', alice_oa_addr, nil, 'broadcast')
print "Tx " , tx.to_payload.bth , "\n"
dd = bitcoinRPC('decoderawtransaction', tx.to_payload.bth)
print "Decode ", dd, "\n"

# api.send_asset(<from open asset address>,
#                <asset ID>,
#                <asset quantity>,
#                <to open asset address>,
#                <fees (The fess in satoshis for the transaction. use 10000 satoshi if specified nil)>,
#                <mode=('broadcast', 'signed', 'unsigned')>,
#                <output_qty default value is 1.>)

print "Balance " , api.get_balance(alice_oa_addr), "\n"

# example
api.send_asset(alice_oa_addr, 'AWo3R89p5REmoSyMWB8AeUmud8456bRxZL', 10, bob_oa_addr, nil, 'broadcast')
