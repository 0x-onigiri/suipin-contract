module suipin::raffle_ticket;

// === Imports ===

use sui::{
    derived_object::{Self},
};

// === Structs ===

public struct RaffleTicket has key, store {
  id: UID,
  raffle_id: ID,
}

public(package) fun new<K: copy + drop + store>(
  raffle_uid_mut: &mut UID,
  claim_key: K,
): RaffleTicket {
  RaffleTicket {
    id: derived_object::claim(raffle_uid_mut, claim_key),
    raffle_id: raffle_uid_mut.to_inner(),
  }
}

public fun destroy(self: RaffleTicket) {
    let RaffleTicket { id, raffle_id: _ } = self;
    id.delete();
}

public fun id(self: &RaffleTicket): ID {
  self.id.to_inner()
}
