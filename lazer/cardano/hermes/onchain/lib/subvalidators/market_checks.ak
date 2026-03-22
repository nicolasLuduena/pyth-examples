use aiken/collection/dict.{to_pairs}
use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{
  PolicyId, Value, from_asset, from_lovelace, match, merge, negate, tokens,
}
use cardano/transaction.{InlineDatum, Output, Transaction}
use contants.{control_token_tn, down_tn, five_minutes, up_tn}
use hermes_types.{MarketDatum, PosixTime, Price}
use subvalidators/common_checks.{read_btc_usd_price}

pub fn validate_init_market(
  pyth_policy: PolicyId,
  start_time: PosixTime,
  own_policy: PolicyId,
  tx: Transaction,
) -> Bool {
  let Transaction { outputs, mint, .. } = tx

  // Only one output at the script address
  expect [own_output] =
    list.filter(
      outputs,
      fn(o) { o.address.payment_credential == Script(own_policy) },
    )

  // Extract value and datum
  expect Output {
    value: o_value,
    datum: InlineDatum(o_datum),
    reference_script: None,
    ..
  } = own_output

  // Datum has
  //    End value is None
  //    Ramaining shares is 0
  expect MarketDatum {
    start_price: o_d_price,
    end_price: None,
    remaining_shares: 0,
  }: MarketDatum = o_datum

  let price = read_btc_usd_price(pyth_policy, start_time, tx)

  // Minting only 1 control token in this policy
  expect [Pair(minted_tn, 1)] = tokens(mint, own_policy) |> to_pairs()

  and {
    //    Start value extracted from oracle
    o_d_price == price,
    // Value has control token
    match(o_value, from_asset(own_policy, control_token_tn, 1), >=),
    minted_tn == control_token_tn,
  }
}

pub fn validate_record_final_price(
  pyth_policy: PolicyId,
  start_time: PosixTime,
  own_policy: PolicyId,
  own_datum: MarketDatum,
  own_value: Value,
  tx: Transaction,
) -> Bool {
  // Datum only adds the end price
  let Transaction { outputs, .. } = tx

  // Only one output at the script address
  expect [own_output] =
    list.filter(
      outputs,
      fn(o) { o.address.payment_credential == Script(own_policy) },
    )

  expect Output {
    value: o_value,
    datum: InlineDatum(o_datum),
    reference_script: None,
    ..
  } = own_output

  let new_price = read_btc_usd_price(pyth_policy, start_time + five_minutes, tx)

  let expected_datum =
    MarketDatum {
      start_price: own_datum.start_price,
      remaining_shares: own_datum.remaining_shares,
      end_price: Some(new_price),
    }
  let expected_datum_data: Data = expected_datum
  and {
    // Output datum matched expected
    o_datum == expected_datum_data,
    // Value has not decreased
    match(o_value, own_value, >=),
  }
}

pub fn validate_claim_winnings(
  own_value: Value,
  claimed_tokens: Int,
  own_datum: MarketDatum,
  own_policy: PolicyId,
  tx: Transaction,
) -> Bool {
  let Transaction { outputs, mint, .. } = tx

  // Only one output at the script address
  expect [own_output] =
    list.filter(
      outputs,
      fn(o) { o.address.payment_credential == Script(own_policy) },
    )

  expect Output {
    value: o_value,
    datum: InlineDatum(o_datum),
    reference_script: None,
    ..
  } = own_output

  let paid_value = from_lovelace(claimed_tokens * 1_000_000)

  let remaining_value = merge(own_value, negate(paid_value))

  expect MarketDatum {
    start_price: i_d_start_price,
    end_price: Some(i_d_end_price),
    remaining_shares: i_d_remaining_shares,
  } = own_datum

  let expected_datum =
    MarketDatum {
      start_price: i_d_start_price,
      remaining_shares: i_d_remaining_shares - claimed_tokens,
      end_price: Some(i_d_end_price),
    }
  let expected_datum_data: Data = expected_datum

  let claiming_token_name =
    if compare_prices(i_d_end_price, i_d_start_price) == Less {
      down_tn
    } else {
      up_tn
    }

  expect [Pair(minted_tn, qty)] = tokens(mint, own_policy) |> to_pairs()

  and {
    minted_tn == claiming_token_name,
    qty == -claimed_tokens,
    // Output datum matched expected
    o_datum == expected_datum_data,
    // Value has not decreased
    match(o_value, remaining_value, >=),
  }
}

pub fn validate_claim_losings(
  own_value: Value,
  claimed_tokens: Int,
  own_datum: MarketDatum,
  own_policy: PolicyId,
  tx: Transaction,
) -> Bool {
  let Transaction { outputs, mint, .. } = tx

  // Only one output at the script address
  expect [own_output] =
    list.filter(
      outputs,
      fn(o) { o.address.payment_credential == Script(own_policy) },
    )

  expect Output {
    value: o_value,
    datum: InlineDatum(o_datum),
    reference_script: None,
    ..
  } = own_output

  expect MarketDatum {
    start_price: i_d_start_price,
    end_price: Some(i_d_end_price),
    remaining_shares: i_d_remaining_shares,
  } = own_datum

  let expected_datum =
    MarketDatum {
      start_price: i_d_start_price,
      remaining_shares: i_d_remaining_shares - claimed_tokens,
      end_price: Some(i_d_end_price),
    }
  let expected_datum_data: Data = expected_datum

  let claiming_token_name =
    if compare_prices(i_d_end_price, i_d_start_price) == Less {
      up_tn
    } else {
      down_tn
    }

  expect [Pair(minted_tn, qty)] = tokens(mint, own_policy) |> to_pairs()

  and {
    minted_tn == claiming_token_name,
    qty == -claimed_tokens,
    // Output datum matched expected
    o_datum == expected_datum_data,
    // Value has not decreased
    match(o_value, own_value, >=),
  }
}

pub fn validate_close_market(
  own_policy: PolicyId,
  own_datum: MarketDatum,
  tx: Transaction,
) -> Bool {
  let Transaction { mint, .. } = tx
  // Burning the control token in this policy
  expect [Pair(minted_tn, -1)] = tokens(mint, own_policy) |> to_pairs()

  and {
    minted_tn == control_token_tn,
    own_datum.remaining_shares == 0,
  }
  // Burned control token
}

pub fn validate_process_match() -> Bool {
  todo
}

pub fn compare_prices(price1: Price, price2: Price) -> Ordering {
  let l = price1.numerator * price2.denominator
  let r = price2.numerator * price1.denominator

  if l > r {
    Greater
  } else if l < r {
    Less
  } else {
    Equal
  }
}
