require 'bitcoin'
require 'openassets'
require 'net/http'
require 'json'

include ::OpenAssets::Util

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
         user:                 'alice',
         password:             'alice',
         schema:               'http',
         port:                  18443,
         host:            'localhost',
         timeout:                  60,
         open_timeout:             60 }
   })

#api.provider.list_unspent
#api.get_balance

alice_key = Bitcoin::Key.generate
bob_key = Bitcoin::Key.generate
alice_key_priv = alice_key.to_base58
bob_key_priv = bob_key.to_base58
print "alice key " , alice_key_priv, "\n"
bitcoinRPC('importprivkey',[alice_key_priv])
bitcoinRPC('importprivkey',[bob_key_priv])
#api.provider.importprivkey(alice_key_priv, "alice", false)

aa = bitcoinRPC('generatetoaddress',[200, alice_key.addr] )
bb = bitcoinRPC('generatetoaddress',[10, bob_key.addr] )
cc = bitcoinRPC('sendtoaddress',[alice_key.addr, 80] )

alice_addr = bitcoinRPC('getaddressesbyaccount',["alice"])
alice_oa_addr = address_to_oa_address(alice_key.addr)
bob_oa_addr = address_to_oa_address(bob_key.addr)

# aa = bitcoinRPC('generatetoaddress',[80, alice_oa_addr] )

asset_id = generate_asset_id(alice_key.pub)
print "Asset id  ", asset_id , "\n"

# api.issue_asset(<issuer open asset address>,
#                 <issuing asset quantity>,
#                 <metadata>,
#                 <to open asset address>,
#                 <fees (The fess in satoshis for the transaction. use 10000 satoshi if specified nil)>,
#                 <mode=('broadcast', 'signed', 'unsigned')>,
#                 <output_qty default value is 1.>)

address = 'akEJwzkzEFau4t2wjbXoMs7MwtZkB8xixmH'
#tx = api.issue_asset(address, 125, 'u=https://goo.gl/bmVEuw', address, nil, 'broadcast', 1)

tx = api.issue_asset(alice_oa_addr, 125, 'u=https://goo.gl/bmVEuw', alice_oa_addr, 5000, 'broadcast', 1)
# print "Tx " , tx.to_payload.bth , "\n"
dd = bitcoinRPC('decoderawtransaction', [tx.to_payload.bth])
#print "Decode ", dd, "\n"
# sig = Bitcoin::Builder::TxBuilder.get_script_sig(alice_key)
redeem_script = 0
#sig_hash = tx.signature_hash_for_input(0, redeem_script)
#script_sig = Bitcoin::Script.to_p2sh_multisig_script_sig(redeem_script)
#script_sig_a = Bitcoin::Script.add_sig_to_multisig_script_sig(alice_key.sign(sig_hash), script_sig)

print "Unspent  " , api.list_unspent([alice_oa_addr]) , "\n"

aa = bitcoinRPC('generatetoaddress',[200, alice_key.addr] )

# api.send_asset(<from open asset address>,
#                <asset ID>,
#                <asset quantity>,
#                <to open asset address>,
#                <fees (The fess in satoshis for the transaction. use 10000 satoshi if specified nil)>,
#                <mode=('broadcast', 'signed', 'unsigned')>,
#                <output_qty default value is 1.>)

print "Address " , alice_oa_addr, "  " , alice_key.addr, "\n"
print "Addressss " , address_to_oa_address(alice_key.addr), "\n"
print "Balance " , api.get_balance(alice_oa_addr), "\n"
print "Balance " , api.provider.getbalance(alice_oa_addr), "\n"

# example
api.send_asset(alice_oa_addr, asset_id, 10, bob_oa_addr, nil, 'broadcast')
