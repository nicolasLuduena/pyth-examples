use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use types.{MarketDatum, MarketMintRedeemer, MarketRedeemer, PosixTime}

validator market(start_time: PosixTime) {
  mint(_redeemer: MarketMintRedeemer, _policy_id: PolicyId, _self: Transaction) {
    True
  }

  spend(
    _datum: Option<MarketDatum>,
    _redeemer: MarketRedeemer,
    _utxo: OutputReference,
    _self: Transaction,
  ) {
    True
  }

  else(_) {
    fail
  }
}
