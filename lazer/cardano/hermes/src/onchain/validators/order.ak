use aiken/crypto.{ScriptHash}
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use types.{OrderDatum, OrderMintRedeemer, OrderRedeemer}

validator order(market_script_hash: ScriptHash) {
  mint(_redeemer: OrderMintRedeemer, _policy_id: PolicyId, _self: Transaction) {
    True
  }

  spend(
    _datum: Option<OrderDatum>,
    _redeemer: OrderRedeemer,
    _utxo: OutputReference,
    _self: Transaction,
  ) {
    True
  }

  else(_) {
    fail
  }
}
