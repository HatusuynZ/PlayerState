# 🌺 PlayerState

A lightweight and reactive **player state manager** for Roblox.

PlayerState helps you organize runtime player data in one place, with support for:

- automatic player state creation
- state synchronization
- key change listeners
- server/client access
- built-in cleanup system
- scalable runtime architecture

Instead of using scattered `Attributes`, `ValueObjects`, or random tables, PlayerState gives you a clean and centralized solution for handling player data.

---

# 🌻 Why Use PlayerState?

Perfect for storing:

- Coins
- XP
- Combat State
- Cooldowns
- Emotes
- Current Room
- Temporary Buffs
- UI Data
- Anti Cheat Flags
- Runtime Systems

---

# 🌹 Features

## 🌸 Automatic State Creation

States are automatically created when players join.

## 🌷 Automatic Cleanup

When a player leaves, all state data and tracked objects are removed safely.

## 🌼 Server + Client Support

Use PlayerState on both server and client.

## 🌺 Reactive State Listeners

Listen to changes for any key of any player.

## 🏵️ Built-in Cleaner

Includes a cleanup object (`Soap`) for:

- Connections
- Threads
- Instances
- Tweens
- Functions

## 💮 Lightweight Replication

State updates can be synchronized to clients.

## 🌻 Async Safe Loading

If a state isn't ready yet, the module waits briefly.

---

# 📦 Installation

Place the module in your game:

```txt
ReplicatedStorage
└── PlayerState

ServerScriptService
└── PlayerState
