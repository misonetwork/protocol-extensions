// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The evolvable cover art value used by the recording/release cover art extensions.
///
/// CoverArt format changes over time (static-only → +animated → future formats).
/// Keeping it in an extension rather than immutable core means a new format is a
/// republish of this small package (or a brand-new cover art standard), not of the
/// frozen protocol. `CoverArt` references external storage via `ori::WalrusData`.
module cover_art::cover_art;

use ori::walrus_data::WalrusData;

// === Structs ===

/// CoverArt with a required still image and optional animation.
public struct CoverArt has copy, drop, store {
    still: WalrusData,
    animated: Option<WalrusData>,
}

// === Public Functions ===

/// Creates cover art with a still image and optional animated version. Both
/// references must be Walrus blobs.
public fun new(still: WalrusData, animated: Option<WalrusData>): CoverArt {
    still.assert_is_blob();
    if (animated.is_some()) {
        animated.borrow().assert_is_blob();
    };
    CoverArt { still, animated }
}

// === Public View Functions ===

/// Returns a reference to the still image data.
public fun still(self: &CoverArt): &WalrusData {
    &self.still
}

/// Returns a reference to the optional animated cover art data.
public fun animated(self: &CoverArt): &Option<WalrusData> {
    &self.animated
}

// === Test Only ===

#[test_only]
public fun new_for_testing(): CoverArt {
    use ori::walrus_data;
    CoverArt { still: walrus_data::new_blob(0), animated: option::none() }
}
