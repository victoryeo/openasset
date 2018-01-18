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

#1 オープニングトランザクションの作成
tx_fee          = 800
deposit_amount  = 400000

# bitcoinRPC('getbalance',[])
# alice_key = Bitcoin::generate_key
# alice_addr = Bitcoin::pubkey_to_address(alice_key[1])

alice_key = Bitcoin::Key.generate
bob_key = Bitcoin::Key.generate

print "alice key" , alice_key.to_base58, "\n"

alice_key_priv = alice_key.to_base58
bob_key_priv = bob_key.to_base58
bitcoinRPC('importprivkey',[alice_key_priv])
bitcoinRPC('importprivkey',[bob_key_priv])
#api.provider.import_privkey(alice_key_priv)

aa = bitcoinRPC('generatetoaddress',[80, alice_key.addr] )
bb = bitcoinRPC('generatetoaddress',[40, bob_key.addr] )
cc = bitcoinRPC('sendtoaddress',[alice_key.addr, 10] )

#puts "aliceblock",  aa
#puts "bobblock", bb
#puts "send", cc

alice_addr = bitcoinRPC('getaddressesbyaccount',["alice"])
#alice_privKey = bitcoinRPC('dumpprivkey',[alice_addr[0]])
#alice_key = Bitcoin::Key.new(alice_privKey)
alice_pubKey = alice_key.pub

bob_addr = bitcoinRPC('getaddressesbyaccount',["bob"])
#bob_privKey = bitcoinRPC('dumpprivkey',[bob_addr[0]])
#bob_key = Bitcoin::Key.new(bob_privKey)
bob_pubKey = bob_key.pub

print "alice key addr" , alice_key , alice_key.addr, "\n"
print "bob key addr" , bob_key , bob_key.addr, "\n"

p2sh_script, redeem_script =  Bitcoin::Script.to_p2sh_multisig_script(2, alice_pubKey, bob_pubKey)
multisig_addr = Bitcoin::Script.new(p2sh_script).get_p2sh_address
opening_tx = api.send_bitcoin(alice_key.addr, deposit_amount, multisig_addr, tx_fee, 'signed')	#ブロードキャストは払い戻し用トランザクションの作成後に行う

#print "DEBUG OUT: " + opening_tx.out[1].value.to_s + "\n"

#txout = opening_tx.out[1]
#opening_tx.out[1] = opening_tx.out[0]
#opening_tx.out[0] = txout
print "DEBUG OUT: " + opening_tx.out[0].value.to_s + "\n"
print "DEBUG OUT: " + opening_tx.out[1].value.to_s + "\n"
#print "DEBUG IN: " + opening_tx.in[0].prev_out_hash + "\n"
#refund = opening_tx.out[0].value

#2 アリスが払い戻しトランザクションを作成
refund_tx = Bitcoin::Protocol::Tx.new

opening_tx_vout  = 1
block_height  = api.provider.getblockcount.to_i	#現在のブロック高を取得

print "Block height: " , block_height, "\n"

locktime      = block_height + 100

refund_tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(opening_tx.hash, opening_tx_vout)
refund_tx.add_in(refund_tx_in)

refund_tx_out = Bitcoin::Protocol::TxOut.value_to_address(deposit_amount, alice_key.addr)
refund_tx.add_out(refund_tx_out)

print "Array ", [0].pack("V") , "\n"

refund_tx.in[0].sequence = [0].pack("V")
refund_tx.lock_time = locktime

print "Array ", refund_tx.in[0].sequence , "\n"

#3 ボブが払い戻し用トランザクションに署名
sig_hash = refund_tx.signature_hash_for_input(0, redeem_script)
script_sig = Bitcoin::Script.to_p2sh_multisig_script_sig(redeem_script)

script_sig_1 = Bitcoin::Script.add_sig_to_multisig_script_sig(alice_key.sign(sig_hash), script_sig)
refund_tx.in[0].script_sig = script_sig_1

#4 アリスがボブから払い戻し用トランザクションを受け取り、ボブの署名が正しくされているか検証
refund_tx_copy = refund_tx

script_sig_2 = Bitcoin::Script.add_sig_to_multisig_script_sig(bob_key.sign(sig_hash), script_sig_1)	#アリスの署名を追加
script_sig_3 = Bitcoin::Script.sort_p2sh_multisig_signatures(script_sig_2, sig_hash)	#署名の順番を並び替え
refund_tx_copy.in[0].script_sig = script_sig_3
#refund_tx.in[0].script_sig = script_sig_3

#print "script ", script_sig_3.raw.to_str, "\n"

if refund_tx_copy.verify_input_signature(0, opening_tx)
print "success","\n"
     refund_tx = refund_tx_copy	#署名の検証が正しい場合は、署名を確定する
else
print "fail","\n"
end

print "Refund ", refund_tx.to_payload.bth , "\n"

# puts "Debug : " + opening_tx.to_payload.bth
# puts "Debug : " + opening_tx.payload.bth

#5 オープニングトランザクションのブロードキャスト
api.provider.send_transaction(opening_tx.to_payload.bth)

#6 コミットメントトランザクションの作成
commitment_tx = Bitcoin::Protocol::Tx.new

amount_to_bob	   = 1500
amount_to_alice    = deposit_amount - amount_to_bob - tx_fee

commitment_tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(opening_tx.hash, opening_tx_vout)
commitment_tx.add_in(refund_tx_in)

commitment_tx_out_1 = Bitcoin::Protocol::TxOut.value_to_address(amount_to_bob, bob_key.addr)	#ボブへの支払い
commitment_tx_out_2 = Bitcoin::Protocol::TxOut.value_to_address(amount_to_alice, alice_key.addr)	#アリスへのお釣り
commitment_tx.add_out(commitment_tx_out_1)
commitment_tx.add_out(commitment_tx_out_2)

print "DEBUG bob : " , bob_key.addr , "  " , bob_addr , "\n"
print "DEBUG alice : " , alice_key.addr , "  " , alice_addr , "\n"
print "DEBUG OUT: " + commitment_tx.out[0].value.to_s + "\n"
print "DEBUG OUT: " + commitment_tx.out[1].value.to_s + "\n"

#7 アリスがコミットメントトランザクションに署名
commitment_sig_hash = commitment_tx.signature_hash_for_input(0, redeem_script)
commitment_script_sig = Bitcoin::Script.to_p2sh_multisig_script_sig(redeem_script)

script_sig_a = Bitcoin::Script.add_sig_to_multisig_script_sig(alice_key.sign(commitment_sig_hash), commitment_script_sig)
commitment_tx.in[0].script_sig = script_sig_a

#8 ボブがアリスからコミットメントトランザクションを受け取り、アリスの署名が正しくされているか検証
commitment_tx_copy = commitment_tx

script_sig_b = Bitcoin::Script.add_sig_to_multisig_script_sig(bob_key.sign(commitment_sig_hash), script_sig_a)	#ボブの署名を追加
script_sig_c = Bitcoin::Script.sort_p2sh_multisig_signatures(script_sig_b, commitment_sig_hash)	#署名の順番を並び替え
commitment_tx_copy.in[0].script_sig = script_sig_c
#commitment_tx.in[0].script_sig = script_sig_c

#print "script ", script_sig_c.raw.to_str, "\n"

if commitment_tx_copy.verify_input_signature(0, opening_tx)
print "success","\n"
     commitment_tx = commitment_tx_copy	
     #署名の検証が正しい場合は、署名を確定する
else
print "fail","\n"
end

#9 コミットメントトランザクションのブロードキャスト
api.provider.send_transaction(commitment_tx.to_payload.bth)
