# coin_raffle.move Overview

## English
- `suipin::coin_raffle` defines an on-chain raffle that distributes a single SUI coin reward stored in a shared `RaffleRewardVault<T>`.
- Creating a raffle (`create_raffle`) mints a shared `Raffle` object, a shared vault backed by the submitted `Coin<T>`, and hands the creator a `RaffleAdminCap` that authorizes future admin actions.
- Participants join via `join_raffle`, supplying a unique UTF-8 display name; the module prevents duplicate addresses (`EAlreadyJoined`) and duplicate names (`ENameAlreadyTaken`), and blocks joins once a winner has been picked (`EAlreadyDid`).
- The admin draws the winner with `draw_raffle_winner`, which leverages the `Random` object to pick an address from the stored `VecMap`. The function snapshots the winning data, issues a `RaffleClaimTicket`, and emits a `RaffleWinnerSelected` event for off-chain tracking.
- The winner redeems the reward by presenting the `Raffle` object, the shared `RaffleRewardVault<T>`, and their `RaffleClaimTicket` to `claim_reward`. The function verifies the vault and coin type before releasing the balance and marking the reward as `Claimed`.
- Helper functions encapsulate raffle creation and participant registration, while admin-only helpers (e.g., `admin_join_raffle`) reuse the same validation logic. Error codes cover ownership, reward mismatches, and insufficient participation (`ENotEnoughParticipants`).

## 日本語
- `suipin::coin_raffle` モジュールは、共有オブジェクト上で管理される SUI コイン報酬の抽選を実装しています。報酬コインは `RaffleRewardVault<T>` に保管されます。
- `create_raffle` は共有 `Raffle` オブジェクトと報酬用の共有ボールトを生成し、管理者権限を示す `RaffleAdminCap` を作成者へ譲渡します。
- 参加者は `join_raffle` で抽選に参加し、UTF-8 の表示名を登録します。アドレスの重複 (`EAlreadyJoined`) や名前の重複 (`ENameAlreadyTaken`)、抽選済み後の参加 (`EAlreadyDid`) は拒否されます。
- 管理者は `draw_raffle_winner` を使って `Random` からインデックスを生成し、`VecMap` に保持されたアドレス群から当選者を決定します。当選者情報は `RaffleWinnerSnapshot` に保存され、`RaffleClaimTicket` が発行され、`RaffleWinnerSelected` イベントが発火します。
- 当選者は `claim_reward` に `Raffle`、共有 `RaffleRewardVault<T>`、および `RaffleClaimTicket` を渡すことで報酬を請求します。ボールト ID とコイン型を検証したうえでバランスが払い出され、報酬状態は `Claimed` に更新されます。
- 内部関数は抽選作成や参加登録のロジックを共通化しており、`admin_join_raffle` などの管理者向け API は同じ検証を再利用します。エラーコードは所有権違反や報酬不整合、参加者不足 (`ENotEnoughParticipants`) などをカバーしています。
