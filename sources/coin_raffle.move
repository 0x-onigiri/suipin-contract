module suipin::coin_raffle;

// === Imports ===

use std::{
    string::{Self, String},
    type_name::{Self, TypeName},
};
use sui::{
    event,
    balance::{Balance},
    coin::{Self, Coin},
    random::Random,
    vec_set::{Self, VecSet},
    vec_map::{Self, VecMap},
};

// === Errors ===

const EAlreadyJoined: u64 = 0;
const ENameAlreadyTaken: u64 = 1;
const EAlreadyDid: u64 = 2;
const ENotOwner: u64 = 3;
const ENotEnoughParticipants: u64 = 4;
const EWrongRewardVault: u64 = 5;
const EWrongRewardType: u64 = 6;

// === Structs ===

public struct Raffle has key {
    id: UID,
    title: String,
    image_blob_id: String,
    participants: VecMap<address, String>,
    name_registry: VecSet<String>,
    winner_selected: bool,
    winner: Option<RaffleWinnerSnapshot>,
    reward_info: RewardInfo,
}

public struct RaffleAdminCap has key, store {
    id: UID,
    raffle_id: ID
}

public enum RewardInfo has store, drop, copy {
    Coin { vault_id: ID, coin_type: TypeName },
    Claimed,
}

public struct RaffleRewardVault<phantom T> has key {
    id: UID,
    reward: Balance<T>,
}

public struct RaffleWinnerSnapshot has drop, store {
    tx_digest: vector<u8>,
    winner_addr: address,
    winner_name: String,
}

public struct RaffleClaimTicket has key {
    id: UID,
    raffle_id: ID,
}

// === Events ===

public struct RaffleWinnerSelected has copy, drop {
    raffle_id: ID,
    raffle_title: String,
    tx_digest: vector<u8>,
    winner_addr: address,
    winner_name: String,
}

// === Public Functions ===

entry fun create_raffle<T>(
    title: String,
    image_blob_id: String,
    reward_coin: Coin<T>,
    ctx: &mut TxContext
) {
    let coin_reward_vault = RaffleRewardVault {
        id: object::new(ctx),
        reward: reward_coin.into_balance(),
    };

    let reward_info = RewardInfo::Coin {
        vault_id: coin_reward_vault.id.to_inner(),
        coin_type: type_name::with_defining_ids<T>(),
    };

    let (raffle, admin_cap) = create_raffle_internal(title, image_blob_id, reward_info, ctx);

    transfer::public_transfer(admin_cap, ctx.sender());
    transfer::share_object(coin_reward_vault);
    transfer::share_object<Raffle>(raffle);
}

entry fun claim_reward<T>(
    raffle: &mut Raffle,
    reward_vault: RaffleRewardVault<T>,
    claim_ticket: RaffleClaimTicket,
    ctx: &mut TxContext
) {
    assert!(claim_ticket.raffle_id == raffle.id.to_inner(), EWrongRewardVault);

    match (raffle.reward_info) {
        RewardInfo::Coin { vault_id, coin_type } => {
            assert!(reward_vault.id.to_inner() == vault_id, EWrongRewardVault);
            assert!(type_name::with_defining_ids<T>() == coin_type, EWrongRewardType);
        },
        _ => abort(EWrongRewardType),
    };

    let RaffleRewardVault { id, reward } = reward_vault;
    id.delete();
    transfer::public_transfer(coin::from_balance(reward, ctx), ctx.sender());


    let RaffleClaimTicket { id: ticket_id, raffle_id: _ } = claim_ticket;
    ticket_id.delete();

    raffle.reward_info = RewardInfo::Claimed
}

entry fun join_raffle(
    raffle: &mut Raffle,
    name: vector<u8>,
    ctx: &TxContext,
) {
    join_raffle_internal(raffle, name, ctx.sender())
}

entry fun draw_raffle_winner(
    cap: &RaffleAdminCap,
    raffle: &mut Raffle,
    random: &Random,
    ctx: &mut TxContext
) {
    assert!(!raffle.winner_selected, EAlreadyDid);
    assert!(raffle.id.to_inner() == cap.raffle_id, ENotOwner);

    let participant_count = raffle.participants.length();
    assert!(participant_count >= 2, ENotEnoughParticipants);
    let mut rg = random.new_generator(ctx);
    let idx = rg.generate_u64_in_range(0, participant_count - 1);
    let (addr, name) = raffle.participants.get_entry_by_idx(idx);

    raffle.winner_selected = true;
    raffle.winner = option::some(RaffleWinnerSnapshot {
        tx_digest: *ctx.digest(),
        winner_addr: *addr,
        winner_name: *name
    });

    let ticket = RaffleClaimTicket {
        id: object::new(ctx),
        raffle_id: raffle.id.to_inner(),
    };

    transfer::transfer(ticket, *addr);

    event::emit(RaffleWinnerSelected {
        raffle_id: raffle.id.to_inner(),
        raffle_title: *&raffle.title,
        tx_digest: *ctx.digest(),
        winner_addr: *addr,
        winner_name: *name
    });

}

// === Admin Functions ===

public fun admin_join_raffle(
    cap: &RaffleAdminCap,
    raffle: &mut Raffle,
    name: vector<u8>,
    participant: address,
) {
    assert!(raffle.id.to_inner() == cap.raffle_id, ENotOwner);
    join_raffle_internal(raffle, name, participant);
}

// === Private Functions ===

fun create_raffle_internal(
    title: String,
    image_blob_id: String,
    reward_info: RewardInfo,
    ctx: &mut TxContext
): (Raffle, RaffleAdminCap) {
    let raffle = Raffle {
        id: object::new(ctx),
        title,
        image_blob_id,
        participants: vec_map::empty(),
        name_registry: vec_set::empty(),
        winner_selected: false,
        winner: option::none(),
        reward_info,
    };
    let raffle_admin_cap = RaffleAdminCap {
        id: object::new(ctx),
        raffle_id: raffle.id.to_inner()
    };

    (raffle, raffle_admin_cap)
}

fun join_raffle_internal(
    raffle: &mut Raffle,
    name: vector<u8>,
    participant: address,
) {
    assert!(!raffle.winner_selected, EAlreadyDid);
    assert!(!raffle.participants.contains(&participant), EAlreadyJoined);

    let name_str = string::utf8(name);
    assert!(!raffle.name_registry.contains(&name_str), ENameAlreadyTaken);

    raffle.name_registry.insert(name_str);
    raffle.participants.insert(participant, name_str);
}
